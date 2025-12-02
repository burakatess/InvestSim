import Foundation
import OSLog

extension Logger {
    static let network = Logger(subsystem: "com.investsimulator", category: "network")
    static let app = Logger(subsystem: "com.investsimulator", category: "app")
}

// Fallback for older iOS versions
@available(iOS 14.0, *)
extension Logger {
    static let networkFallback = Logger(subsystem: "com.investsimulator", category: "network")
}
