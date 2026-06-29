#!/bin/bash
# Create a stable, self-signed code-signing identity in the login keychain.
#
# Why: make-app.sh otherwise ad-hoc-signs the bundle, and ad-hoc signatures have
# no stable identity — every rebuild produces a new CDHash. macOS keys TCC
# permissions (Accessibility, Screen Recording, …) on that CDHash, so an ad-hoc
# app loses its grant on every rebuild and the user must re-approve it.
#
# A self-signed identity gives the bundle a stable Designated Requirement
# (the certificate's leaf hash, not the binary's CDHash). TCC honors that across
# rebuilds: grant once, and it survives every future `make-app.sh`.
#
# Idempotent — re-running is a no-op once the identity exists.
set -euo pipefail

CERT_CN="StatusItemKit Local Signing"
LOGIN_KC="$(security login-keychain | tr -d ' "')"

if security find-identity -p codesigning 2>/dev/null | grep -qF "$CERT_CN"; then
    echo "✓ Signing identity already present:"
    security find-identity -p codesigning | grep -F "$CERT_CN"
    exit 0
fi

echo "==> Creating self-signed code-signing identity \"$CERT_CN\""
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
P12PW="statusitemkit"   # transit password for the temporary PKCS#12 only

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
    -subj "/CN=$CERT_CN" \
    -addext "basicConstraints=critical,CA:false" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" 2>/dev/null

# OpenSSL 3 defaults to a SHA-256 PKCS#12 MAC that Apple's `security` cannot
# import ("MAC verification failed"); force the legacy SHA-1 MAC + algorithms.
openssl pkcs12 -export -legacy -macalg sha1 \
    -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -name "$CERT_CN" -out "$TMP/id.p12" -passout "pass:$P12PW" 2>/dev/null

security import "$TMP/id.p12" -k "$LOGIN_KC" -P "$P12PW" -T /usr/bin/codesign >/dev/null
echo "✓ Identity imported into login keychain"

# Authorize codesign to use the private key without a GUI prompt on every build.
# This needs the login-keychain (your Mac login) password. If we can't get it,
# codesign still works — it just prompts once and you click "Always Allow".
get_pw() {
    if [ -t 0 ]; then
        read -r -s -p "macOS login password (lets codesign sign silently; blank to skip): " pw
        echo >&2
    else
        pw="$(osascript -e 'try
  text returned of (display dialog "Enter your macOS login password so codesign can sign without prompting on every build (Cancel to skip — codesign will then ask once):" default answer "" with hidden answer with title "StatusItemKit signing")
on error
  return ""
end try' 2>/dev/null || true)"
    fi
    printf '%s' "$pw"
}

PW="$(get_pw)"
if [ -n "$PW" ] && security set-key-partition-list \
        -S apple-tool:,apple: -s -k "$PW" "$LOGIN_KC" >/dev/null 2>&1; then
    echo "✓ codesign authorized — no per-build prompts"
else
    echo "⚠ Partition list not set; codesign will prompt once on first build — click \"Always Allow\"."
fi
unset PW

echo
echo "Done. Now rebuild the app (it will sign with this identity) and grant"
echo "Accessibility ONE more time. Every rebuild after that keeps the grant."
security find-identity -p codesigning | grep -F "$CERT_CN"
