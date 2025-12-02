import Foundation

/// DCA Engine için Date extension'ları
/// Tarih manipülasyonu ve hesaplamaları için gerekli utility fonksiyonları
public extension Date {
    /// Tarihi belirtilen güne kaydırır (ayı taşmayan en yakın geçerli güne)
    /// - Parameter day: Hedef gün (1-31 arası)
    /// - Returns: Kaydırılmış tarih
    func shiftToDay(_ day: Int) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        
        // Ayın son gününü bul
        let range = calendar.range(of: .day, in: .month, for: self)
        let lastDayOfMonth = range?.upperBound ?? 31
        
        // Hedef günü ayın son günü ile sınırla
        let targetDay = min(day, lastDayOfMonth - 1)
        
        var newComponents = components
        newComponents.day = targetDay
        
        return calendar.date(from: newComponents) ?? self
    }
    
    /// Tarihe belirtilen ay sayısını ekler
    /// - Parameter months: Eklenecek ay sayısı
    /// - Returns: Yeni tarih
    func addMonths(_ months: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .month, value: months, to: self) ?? self
    }
    
    /// Tarihe belirtilen gün sayısını ekler
    /// - Parameter days: Eklenecek gün sayısı
    /// - Returns: Yeni tarih
    func addDays(_ days: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: days, to: self) ?? self
    }
    
    /// Belirtilen yıl, ay ve günden tarih oluşturur
    /// - Parameters:
    ///   - year: Yıl
    ///   - month: Ay (1-12)
    ///   - day: Gün (1-31)
    /// - Returns: Oluşturulan tarih
    static func ymd(_ year: Int, _ month: Int, _ day: Int) -> Date? {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        
        return calendar.date(from: components)
    }
    
    /// Tarihin ayın kaçıncı günü olduğunu döndürür
    var dayOfMonth: Int {
        let calendar = Calendar.current
        return calendar.component(.day, from: self)
    }
    
    /// Tarihin hangi ay olduğunu döndürür (1-12)
    var month: Int {
        let calendar = Calendar.current
        return calendar.component(.month, from: self)
    }
    
    /// Tarihin hangi yıl olduğunu döndürür
    var year: Int {
        let calendar = Calendar.current
        return calendar.component(.year, from: self)
    }
    
    /// Tarihin haftanın hangi günü olduğunu döndürür (1=Pazar, 7=Cumartesi)
    var weekday: Int {
        let calendar = Calendar.current
        return calendar.component(.weekday, from: self)
    }
    
    /// Tarihin hafta sonu olup olmadığını kontrol eder
    var isWeekend: Bool {
        return weekday == 1 || weekday == 7 // Pazar veya Cumartesi
    }
    
    /// Tarihin hafta içi olup olmadığını kontrol eder
    var isWeekday: Bool {
        return !isWeekend
    }
    
    /// İki tarih arasındaki ay farkını döndürür
    /// - Parameter date: Karşılaştırılacak tarih
    /// - Returns: Ay farkı
    func monthsDifference(from date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month], from: date, to: self)
        return components.month ?? 0
    }
    
    /// İki tarih arasındaki gün farkını döndürür
    /// - Parameter date: Karşılaştırılacak tarih
    /// - Returns: Gün farkı
    func daysDifference(from date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: date, to: self)
        return components.day ?? 0
    }
    
    /// Tarihi "yyyy-MM-dd" formatında string olarak döndürür
    var yyyyMMddString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Europe/Istanbul")
        return formatter.string(from: self)
    }
    
    /// Tarihi "dd.MM.yyyy" formatında string olarak döndürür
    var ddMMyyyyString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.timeZone = TimeZone(identifier: "Europe/Istanbul")
        return formatter.string(from: self)
    }
    
    /// Tarihi "dd MMMM yyyy" formatında string olarak döndürür (Türkçe)
    var ddMMMMyyyyString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMMM yyyy"
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = TimeZone(identifier: "Europe/Istanbul")
        return formatter.string(from: self)
    }
    
    /// Tarihin geçmişte olup olmadığını kontrol eder
    var isInPast: Bool {
        return self < Date()
    }
    
    /// Tarihin gelecekte olup olmadığını kontrol eder
    var isInFuture: Bool {
        return self > Date()
    }
    
    /// Tarihin bugün olup olmadığını kontrol eder
    var isToday: Bool {
        let calendar = Calendar.current
        return calendar.isDateInToday(self)
    }
    
    /// Tarihin dün olup olmadığını kontrol eder
    var isYesterday: Bool {
        let calendar = Calendar.current
        return calendar.isDateInYesterday(self)
    }
    
    /// Tarihin yarın olup olmadığını kontrol eder
    var isTomorrow: Bool {
        let calendar = Calendar.current
        return calendar.isDateInTomorrow(self)
    }
}

// MARK: - Istanbul Timezone Helper
public extension Date {
    /// Tarihi Istanbul timezone'unda döndürür
    var istanbulDate: Date {
        let timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let seconds = TimeInterval(timeZone.secondsFromGMT(for: self))
        return Date(timeInterval: seconds, since: self)
    }
    
    /// Tarihi Istanbul timezone'unda oluşturur
    /// - Parameters:
    ///   - year: Yıl
    ///   - month: Ay
    ///   - day: Gün
    ///   - hour: Saat (varsayılan: 0)
    ///   - minute: Dakika (varsayılan: 0)
    ///   - second: Saniye (varsayılan: 0)
    /// - Returns: Istanbul timezone'unda tarih
    static func istanbul(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0,
        second: Int = 0
    ) -> Date? {
        let timeZone = TimeZone(identifier: "Europe/Istanbul")!
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        components.timeZone = timeZone
        
        return Calendar.current.date(from: components)
    }
}
