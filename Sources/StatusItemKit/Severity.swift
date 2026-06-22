import AppKit

/// Three-level severity derived from a percentage against a warn threshold.
/// The `level` function is pure (Int -> case); `color` is the AppKit mapping.
public enum Severity: Equatable {
    case normal, elevated, high

    /// green below 50%, orange from 50% up to the warn threshold, red at/above it.
    public static func level(pct: Int, warnPct: Int) -> Severity {
        if pct >= warnPct { return .high }
        if pct >= 50 { return .elevated }
        return .normal
    }

    public var color: NSColor {
        switch self {
        case .normal: return .systemGreen
        case .elevated: return .systemOrange
        case .high: return .systemRed
        }
    }
}
