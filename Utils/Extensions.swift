import Foundation

extension DateRange {
    func startDate(endingAt endDate: Date, calendar: Calendar) -> Date {
        guard let days = self.days else {
            return calendar.date(byAdding: .year, value: -10, to: endDate) ?? endDate
        }
        return calendar.date(byAdding: .day, value: -days, to: endDate) ?? endDate
    }
}

extension Calendar {
    func startOfDay(for date: Date) -> Date {
        return self.dateInterval(of: .day, for: date)?.start ?? date
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
