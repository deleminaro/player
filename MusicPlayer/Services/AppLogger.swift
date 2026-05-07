import Foundation

// MARK: - Log entry

struct LogEntry: Identifiable {
    let id   = UUID()
    let date = Date()
    let category: String
    let message:  String

    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var timestamp: String { Self.fmt.string(from: date) }

    var line: String { "[\(timestamp)] [\(category)] \(message)" }
}

// MARK: - Logger

final class AppLogger: ObservableObject {
    static let shared = AppLogger()

    @Published private(set) var entries: [LogEntry] = []
    private let maxEntries = 600
    private let queue = DispatchQueue(label: "postor.logger", qos: .utility)

    private init() {}

    func log(_ message: String, category: String = "App") {
        let entry = LogEntry(category: category, message: message)
        print(entry.line)
        queue.async { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async {
                self.entries.append(entry)
                if self.entries.count > self.maxEntries {
                    self.entries.removeFirst(self.entries.count - self.maxEntries)
                }
            }
        }
    }

    func clear() {
        DispatchQueue.main.async { self.entries.removeAll() }
    }

    // Full text snapshot for sharing
    func export(snapshot: String) -> String {
        let header = """
        ============================
        POSTOR Debug Log
        Exported: \(Date())
        ============================

        \(snapshot)

        ============================
        Event Log (\(entries.count) entries)
        ============================
        """
        let body = entries.map(\.line).joined(separator: "\n")
        return header + "\n" + body
    }
}
