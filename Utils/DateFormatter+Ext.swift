import Foundation

extension DateFormatter {
    static let yMd: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    static let evds: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US")
        df.dateFormat = "dd-MM-yyyy"
        return df
    }()

    static let turkishMonthFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US")
        df.dateFormat = "LLLL yyyy"
        return df
    }()

    static let turkishShortWeekdaySymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.calendar = Calendar(identifier: .gregorian)
        var symbols = formatter.shortWeekdaySymbols.map { $0.replacingOccurrences(of: ".", with: "") }
        if let first = symbols.first { // move Sunday to end so Monday is first
            symbols.removeFirst()
            symbols.append(first)
        }
        return symbols
    }()
}
