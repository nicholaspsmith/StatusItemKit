import Foundation

/// Minimal synchronous command runner. Returns stdout as UTF-8 text on a
/// clean (exit 0) run, or nil if the process can't launch, exits non-zero,
/// or its output isn't UTF-8. stderr is discarded.
public enum Shell {
    public static func run(_ path: String, _ args: [String]) -> String? {
        let task = Process()
        task.launchPath = path
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do { try task.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard task.terminationStatus == 0,
              let text = String(data: data, encoding: .utf8) else { return nil }
        return text
    }
}
