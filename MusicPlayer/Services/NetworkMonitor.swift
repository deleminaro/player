import Network
import Foundation

final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isConnected = true

    private let monitor = NWPathMonitor()
    private let queue   = DispatchQueue(label: "postor.network", qos: .utility)

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            DispatchQueue.main.async {
                self?.isConnected = connected
                AppLogger.shared.log(connected ? "Connected (\(path.availableInterfaces.map(\.name).joined(separator: ", ")))" : "Disconnected — no network", category: "Network")
            }
        }
        monitor.start(queue: queue)
    }
}
