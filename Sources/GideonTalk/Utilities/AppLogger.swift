import Foundation

final class AppLogger {
    static let shared = AppLogger()

    private let queue = DispatchQueue(label: "com.gideontalk.logger", qos: .utility)
    private let formatter = ISO8601DateFormatter()
    private let logURL: URL

    private init() {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/GideonTalk", isDirectory: true)
        self.logURL = base.appendingPathComponent("latest.log")
    }

    var logPath: String { logURL.path }

    func startNewLaunchLog() {
        queue.sync {
            let directory = logURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? Data().write(to: logURL, options: .atomic)
            writeLine("[LAUNCH] GideonTalk started")
        }
    }

    func info(_ message: String) { log(level: "INFO", message) }
    func warn(_ message: String) { log(level: "WARN", message) }
    func error(_ message: String) { log(level: "ERROR", message) }

    private func log(level: String, _ message: String) {
        queue.async {
            self.writeLine("[\(level)] \(message)")
        }
    }

    private func writeLine(_ message: String) {
        let timestamp = formatter.string(from: Date())
        let line = "\(timestamp) \(message)\n"
        let data = Data(line.utf8)

        if let handle = try? FileHandle(forWritingTo: logURL) {
            defer { try? handle.close() }
            do {
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } catch {
                // no-op; logging should never crash app flow
            }
        } else {
            try? data.write(to: logURL, options: .atomic)
        }
    }
}
