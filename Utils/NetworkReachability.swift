import Foundation
import Network
import Combine

final class NetworkReachability: ObservableObject {
    static let shared = NetworkReachability()
    static let statusChangedNotification = Notification.Name("NetworkStatusChanged")
    
    @Published var isReachable = true
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isReachable = path.status == .satisfied
                NotificationCenter.default.post(
                    name: .statusChangedNotification,
                    object: path.status == .satisfied
                )
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}

extension Notification.Name {
    static let statusChangedNotification = Notification.Name("NetworkStatusChanged")
}
