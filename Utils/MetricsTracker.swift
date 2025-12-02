import Foundation

final class MetricsTracker {
    static let shared = MetricsTracker()
    
    private init() {}
    
    func recordPlanExecution(duration: TimeInterval, tradeCount: Int, planCount: Int) {
        // Mock implementation - in real app, this would send metrics to analytics service
        print("Plan execution: \(duration)s, \(tradeCount) trades, \(planCount) plans")
    }
}
