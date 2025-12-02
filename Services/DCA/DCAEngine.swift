import Foundation

/// DCA (Dollar Cost Averaging) simülasyon motoru
/// Kullanıcının belirlediği parametrelere göre yatırım simülasyonu yapar
internal class DCAEngine {
    
    /// Maksimum geriye gitme günü (varsayılan: 7)
    internal let maxBackDays: Int
    
    internal init(maxBackDays: Int = 7) {
        self.maxBackDays = maxBackDays
    }
    
    /// DCA simülasyonu çalıştırır
    /// - Parameters:
    ///   - config: Simülasyon konfigürasyonu
    ///   - provider: Fiyat sağlayıcısı
    /// - Returns: Simülasyon sonucu
    /// - Throws: DCAError
    internal func simulate(config: ScenarioConfig, provider: DCAProvider) throws -> SimulationResult {
        print("🔍 DCAEngine: Simülasyon başlatılıyor...")
        print("📋 Config validasyonu yapılıyor...")
        
        // Validasyonları yap
        try validateConfig(config)
        print("✅ Config validasyonu başarılı")
        
        // Simülasyon verilerini hazırla
        var totalInvested: Decimal = 0
        var assetBreakdowns: [String: AssetBreakdown] = [:]
        var dealLogs: [DealLog] = []
        var portfolioTimeline: [(date: Date, value: Decimal)] = []
        
        // Yatırım tarihlerini belirle (çoklu gün desteği)
        var investmentDates: [Date] = []
        let calendar = Calendar.current
        if config.interval == .month, config.frequency >= 2, let days = config.customDaysOfMonth, !days.isEmpty {
            var iter = calendar.date(from: calendar.dateComponents([.year, .month], from: config.startDate)) ?? config.startDate
            while iter <= config.endDate {
                for day in Array(Set(days)).sorted().prefix(config.frequency) {
                    var comps = calendar.dateComponents([.year, .month], from: iter)
                    
                    // Ayın kaç çektiğini bul ve günü ona göre ayarla
                    // Örn: Şubat ayında 30. gün seçildiyse 28 veya 29. günü al
                    if let dateForMonth = calendar.date(from: comps),
                       let range = calendar.range(of: .day, in: .month, for: dateForMonth) {
                        let lastDay = range.count
                        comps.day = min(day, lastDay)
                        
                        if let finalDate = calendar.date(from: comps), 
                           finalDate >= config.startDate, 
                           finalDate <= config.endDate {
                            investmentDates.append(finalDate)
                            print("📅 Yatırım tarihi belirlendi: \(finalDate) (Hedef gün: \(day))")
                        }
                    } else {
                        // Fallback (teorik olarak buraya düşmemeli)
                        comps.day = min(max(1, day), 28)
                        if let date = calendar.date(from: comps), 
                           date >= config.startDate, 
                           date <= config.endDate {
                            investmentDates.append(date)
                        }
                    }
                }
                iter = calendar.date(byAdding: .month, value: 1, to: iter) ?? iter
            }
        } else if config.interval == .weekOfMonth, let weekdays = config.customDaysOfMonth, !weekdays.isEmpty {
            let targetWeekdays = Array(Set(weekdays)).sorted().prefix(config.frequency)
            var currentWeekStart = startOfWeek(for: config.startDate, calendar: calendar)

            while currentWeekStart <= config.endDate {
                for customDay in targetWeekdays {
                    let weekday = calendarWeekday(from: customDay)
                    var components = DateComponents()
                    components.weekday = weekday
                    if let candidate = calendar.nextDate(after: currentWeekStart.addingTimeInterval(-1), matching: components, matchingPolicy: .nextTime, direction: .forward) {
                        if candidate >= config.startDate && candidate <= config.endDate {
                            investmentDates.append(candidate)
                        }
                    }
                }
                guard let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) else { break }
                currentWeekStart = nextWeek
            }
        } else {
            var currentDate = config.startDate
            while currentDate <= config.endDate {
                investmentDates.append(currentDate)
                guard let nextDate = calendar.date(byAdding: config.interval, value: config.frequency, to: currentDate) else { break }
                currentDate = nextDate
            }
        }
        
        guard !investmentDates.isEmpty else {
            throw DCAError.noInvestmentDates
        }

        investmentDates.sort()
        
        // İlk yatırım (initial investment)
        for (index, date) in investmentDates.enumerated() {
            if index == 0 && config.initialInvestment > 0 {
                try processInvestment(
                    amount: config.initialInvestment,
                    date: date,
                    config: config,
                    provider: provider,
                    totalInvested: &totalInvested,
                    assetBreakdowns: &assetBreakdowns,
                    dealLogs: &dealLogs
                )
            }

            let shouldSkipMonthlyAtStart = config.initialInvestment > 0 && index == 0
            if !shouldSkipMonthlyAtStart {
                try processInvestment(
                    amount: config.monthlyInvestment,
                    date: date,
                    config: config,
                    provider: provider,
                    totalInvested: &totalInvested,
                    assetBreakdowns: &assetBreakdowns,
                    dealLogs: &dealLogs
                )
            }

            let snapshotValue = try computePortfolioValue(
                on: date,
                config: config,
                provider: provider,
                assetBreakdowns: assetBreakdowns
            )
            portfolioTimeline.append((date: date, value: snapshotValue))
        }
        
        // Son fiyatları al ve toplam değeri hesapla
        var totalCurrentValue: Decimal = 0
        var breakdownRows: [BreakdownRow] = []
        
        for allocation in config.assetAllocations {
            guard let finalPrice = provider.historicalPrice(on: config.endDate, symbol: allocation.assetCode.symbol) else {
                throw DCAError.priceNotFound(symbol: allocation.assetCode.symbol, date: config.endDate)
            }
            
            let breakdown = assetBreakdowns[allocation.assetCode.symbol] ?? AssetBreakdown(symbol: allocation.assetCode.symbol)
            let currentValue = breakdown.totalUnits * finalPrice
            totalCurrentValue += currentValue
            
            let breakdownRow = BreakdownRow(
                symbol: allocation.assetCode.symbol,
                totalUnits: breakdown.totalUnits,
                avgCostTRY: breakdown.totalUnits > 0 ? breakdown.totalInvested / breakdown.totalUnits : 0,
                currentPrice: finalPrice,
                currentValueTRY: currentValue,
                pnlTRY: currentValue - breakdown.totalInvested,
                pnlPct: breakdown.totalInvested > 0 ? ((currentValue - breakdown.totalInvested) / breakdown.totalInvested) * 100 : 0
            )
            breakdownRows.append(breakdownRow)
        }
        
        // Bitiş tarihinde portföy değerini kaydet (daha önce aynı gün işlense bile)
        let finalSnapshotValue = try computePortfolioValue(
            on: config.endDate,
            config: config,
            provider: provider,
            assetBreakdowns: assetBreakdowns
        )
        if let lastIndex = portfolioTimeline.lastIndex(where: { calendar.isDate($0.date, inSameDayAs: config.endDate) }) {
            portfolioTimeline[lastIndex].value = finalSnapshotValue
        } else {
            portfolioTimeline.append((date: config.endDate, value: finalSnapshotValue))
        }

        let totalProfit = totalCurrentValue - totalInvested
        let totalProfitPercentage = totalInvested > 0 ? (totalProfit / totalInvested) * 100 : 0
        let maxDrawdown = calculateMaxDrawdown(from: portfolioTimeline)

        return SimulationResult(
            investedTotalTRY: totalInvested,
            currentValueTRY: totalCurrentValue,
            profitTRY: totalProfit,
            profitPct: totalProfitPercentage,
            maxDrawdownPct: maxDrawdown,
            deals: dealLogs,
            breakdown: breakdownRows,
            simulationDate: Date()
        )
    }
    
    /// Yatırım işlemini işler
    private func processInvestment(
        amount: Decimal,
        date: Date,
        config: ScenarioConfig,
        provider: DCAProvider,
        totalInvested: inout Decimal,
        assetBreakdowns: inout [String: AssetBreakdown],
        dealLogs: inout [DealLog]
    ) throws {
        guard amount > 0 else { return }
        
        // Her varlık için yatırım yap
        for allocation in config.assetAllocations {
            guard allocation.isEnabled && allocation.weight > 0 else { continue }
            
            let investmentAmount = amount * allocation.weight
            
            guard let price = provider.historicalPrice(on: date, symbol: allocation.assetCode.symbol) else {
                throw DCAError.priceNotFound(symbol: allocation.assetCode.symbol, date: date)
            }
            
            let priceWithSlippage = price * (1 + config.slippage)
            let feeAmount = investmentAmount * config.transactionFee
            let netInvestment = investmentAmount - feeAmount
            
            guard netInvestment > 0 else { continue }
            
            let boughtAmount = netInvestment / priceWithSlippage
            let actualCost = boughtAmount * priceWithSlippage + feeAmount
            
            totalInvested += actualCost
            
            // Asset breakdown'ı güncelle
            if assetBreakdowns[allocation.assetCode.symbol] == nil {
                assetBreakdowns[allocation.assetCode.symbol] = AssetBreakdown(symbol: allocation.assetCode.symbol)
            }
            
            assetBreakdowns[allocation.assetCode.symbol]?.totalUnits += boughtAmount
            assetBreakdowns[allocation.assetCode.symbol]?.totalInvested += actualCost
            
            let deal = DealLog(
                date: date,
                targetDate: date,
                symbol: allocation.assetCode.symbol,
                price: priceWithSlippage,
                units: boughtAmount,
                spentTRY: actualCost,
                skipped: false
            )
            dealLogs.append(deal)
        }
    }
    
    /// Konfigürasyonu doğrular
    private func validateConfig(_ config: ScenarioConfig) throws {
        guard config.initialInvestment >= 0 && config.monthlyInvestment >= 0 else {
            throw DCAError.invalidConfiguration("Yatırım miktarları negatif olamaz.")
        }
        guard config.startDate < config.endDate else {
            throw DCAError.invalidConfiguration("Başlangıç tarihi bitiş tarihinden önce olmalı.")
        }
        guard config.slippage >= 0 && config.slippage < 1 else {
            throw DCAError.invalidConfiguration("Slipaj 0 ile 1 arasında olmalı (örn: 0.001).")
        }
        guard config.transactionFee >= 0 && config.transactionFee < 1 else {
            throw DCAError.invalidConfiguration("İşlem ücreti 0 ile 1 arasında olmalı (örn: 0.0005).")
        }
        guard config.frequency > 0 else {
            throw DCAError.invalidConfiguration("Yatırım sıklığı 0'dan büyük olmalı.")
        }
        if (config.interval == .weekOfMonth || config.interval == .month) {
            let selectedDays = config.customDaysOfMonth?.count ?? 0
            guard selectedDays == config.frequency else {
                throw DCAError.invalidConfiguration("Seçili gün sayısı yatırım sıklığı ile eşleşmeli.")
            }
        }
        guard !config.assetAllocations.isEmpty else {
            throw DCAError.emptyAllocations
        }
        guard config.isValidWeightDistribution else {
            throw DCAError.invalidWeightsSum(actual: config.totalWeightPercentage, expected: 100)
        }
    }

    private func computePortfolioValue(
        on date: Date,
        config: ScenarioConfig,
        provider: DCAProvider,
        assetBreakdowns: [String: AssetBreakdown]
    ) throws -> Decimal {
        var total: Decimal = 0

        for allocation in config.assetAllocations {
            guard let breakdown = assetBreakdowns[allocation.assetCode.symbol], breakdown.totalUnits > 0 else { continue }

            guard let price = provider.historicalPrice(on: date, symbol: allocation.assetCode.symbol) else {
                throw DCAError.priceNotFound(symbol: allocation.assetCode.symbol, date: date)
            }

            total += breakdown.totalUnits * price
        }

        return total
    }

    private func calculateMaxDrawdown(from timeline: [(date: Date, value: Decimal)]) -> Decimal {
        guard !timeline.isEmpty else { return 0 }

        var peak: Decimal = 0
        var maxDrawdown: Decimal = 0

        for snapshot in timeline {
            let value = snapshot.value
            if value > peak {
                peak = value
            }

            guard peak > 0 else { continue }

            let drawdown = (peak - value) / peak * 100
            if drawdown > maxDrawdown {
                maxDrawdown = drawdown
            }
        }

        return maxDrawdown
    }
}

// MARK: - Asset Breakdown Helper
private struct AssetBreakdown {
    let symbol: String
    var totalUnits: Decimal = 0
    var totalInvested: Decimal = 0

    init(symbol: String) {
        self.symbol = symbol
    }
}

// MARK: - Calendar Helpers
private extension DCAEngine {
    func startOfWeek(for date: Date, calendar: Calendar) -> Date {
        if let interval = calendar.dateInterval(of: .weekOfYear, for: date) {
            return interval.start
        }
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }

    func calendarWeekday(from customDay: Int) -> Int {
        switch customDay {
        case 1: return 2 // Pazartesi
        case 2: return 3 // Salı
        case 3: return 4 // Çarşamba
        case 4: return 5 // Perşembe
        case 5: return 6 // Cuma
        case 6: return 7 // Cumartesi
        case 7: return 1 // Pazar
        default:
            let normalized = ((customDay % 7) + 7) % 7
            return calendarWeekday(from: normalized == 0 ? 7 : normalized)
        }
    }
}
