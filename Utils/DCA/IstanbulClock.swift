import Foundation

/// Istanbul timezone ve tarih işlemleri için utility sınıfı
/// DCA Engine'de tutarlı timezone kullanımı sağlar
public struct IstanbulClock {
    /// Europe/Istanbul timezone sabiti
    public static let timeZone = TimeZone(identifier: "Europe/Istanbul")!
    
    /// Istanbul timezone'unda calendar
    public static var calendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        return calendar
    }
    
    /// Istanbul timezone'unda şu anki tarih ve saat
    public static var now: Date {
        return Date()
    }
    
    /// Istanbul timezone'unda bugünün başlangıcı (00:00:00)
    public static var today: Date {
        return calendar.startOfDay(for: now)
    }
    
    /// Istanbul timezone'unda dünün başlangıcı
    public static var yesterday: Date {
        return calendar.date(byAdding: .day, value: -1, to: today) ?? today
    }
    
    /// Istanbul timezone'unda yarının başlangıcı
    public static var tomorrow: Date {
        return calendar.date(byAdding: .day, value: 1, to: today) ?? today
    }
    
    /// Belirtilen tarihi Istanbul timezone'unda oluşturur
    /// - Parameters:
    ///   - year: Yıl
    ///   - month: Ay (1-12)
    ///   - day: Gün (1-31)
    ///   - hour: Saat (0-23, varsayılan: 0)
    ///   - minute: Dakika (0-59, varsayılan: 0)
    ///   - second: Saniye (0-59, varsayılan: 0)
    /// - Returns: Istanbul timezone'unda tarih
    public static func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0,
        second: Int = 0
    ) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        components.timeZone = timeZone
        
        return calendar.date(from: components)
    }
    
    /// Tarihi Istanbul timezone'unda formatlar
    /// - Parameters:
    ///   - date: Formatlanacak tarih
    ///   - format: Tarih formatı (varsayılan: "yyyy-MM-dd")
    /// - Returns: Formatlanmış string
    public static func format(_ date: Date, format: String = "yyyy-MM-dd") -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }
    
    /// Tarihi "yyyy-MM-dd" formatında string olarak döndürür
    /// - Parameter date: Formatlanacak tarih
    /// - Returns: "yyyy-MM-dd" formatında string
    public static func yyyyMMddString(for date: Date) -> String {
        return format(date, format: "yyyy-MM-dd")
    }
    
    /// Tarihi "dd.MM.yyyy" formatında string olarak döndürür
    /// - Parameter date: Formatlanacak tarih
    /// - Returns: "dd.MM.yyyy" formatında string
    public static func ddMMyyyyString(for date: Date) -> String {
        return format(date, format: "dd.MM.yyyy")
    }
    
    /// Tarihi "dd MMMM yyyy" formatında string olarak döndürür (Türkçe)
    /// - Parameter date: Formatlanacak tarih
    /// - Returns: "dd MMMM yyyy" formatında string
    public static func ddMMMMyyyyString(for date: Date) -> String {
        return format(date, format: "dd MMMM yyyy")
    }
    
    /// String'den Istanbul timezone'unda tarih oluşturur
    /// - Parameters:
    ///   - string: Tarih string'i
    ///   - format: Tarih formatı (varsayılan: "yyyy-MM-dd")
    /// - Returns: Oluşturulan tarih
    public static func date(from string: String, format: String = "yyyy-MM-dd") -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US")
        return formatter.date(from: string)
    }
    
    /// "yyyy-MM-dd" formatındaki string'den tarih oluşturur
    /// - Parameter string: "yyyy-MM-dd" formatında tarih string'i
    /// - Returns: Oluşturulan tarih
    public static func date(fromYyyyMMdd string: String) -> Date? {
        return date(from: string, format: "yyyy-MM-dd")
    }
    
    /// İki tarih arasındaki gün farkını hesaplar
    /// - Parameters:
    ///   - from: Başlangıç tarihi
    ///   - to: Bitiş tarihi
    /// - Returns: Gün farkı
    public static func daysBetween(_ from: Date, and to: Date) -> Int {
        let components = calendar.dateComponents([.day], from: from, to: to)
        return components.day ?? 0
    }
    
    /// İki tarih arasındaki ay farkını hesaplar
    /// - Parameters:
    ///   - from: Başlangıç tarihi
    ///   - to: Bitiş tarihi
    /// - Returns: Ay farkı
    public static func monthsBetween(_ from: Date, and to: Date) -> Int {
        let components = calendar.dateComponents([.month], from: from, to: to)
        return components.month ?? 0
    }
    
    /// Tarihin hafta sonu olup olmadığını kontrol eder
    /// - Parameter date: Kontrol edilecek tarih
    /// - Returns: Hafta sonu durumu
    public static func isWeekend(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7 // Pazar veya Cumartesi
    }
    
    /// Tarihin hafta içi olup olmadığını kontrol eder
    /// - Parameter date: Kontrol edilecek tarih
    /// - Returns: Hafta içi durumu
    public static func isWeekday(_ date: Date) -> Bool {
        return !isWeekend(date)
    }
    
    /// Tarihin bugün olup olmadığını kontrol eder
    /// - Parameter date: Kontrol edilecek tarih
    /// - Returns: Bugün durumu
    public static func isToday(_ date: Date) -> Bool {
        return calendar.isDateInToday(date)
    }
    
    /// Tarihin dün olup olmadığını kontrol eder
    /// - Parameter date: Kontrol edilecek tarih
    /// - Returns: Dün durumu
    public static func isYesterday(_ date: Date) -> Bool {
        return calendar.isDateInYesterday(date)
    }
    
    /// Tarihin yarın olup olmadığını kontrol eder
    /// - Parameter date: Kontrol edilecek tarih
    /// - Returns: Yarın durumu
    public static func isTomorrow(_ date: Date) -> Bool {
        return calendar.isDateInTomorrow(date)
    }
}
