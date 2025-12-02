import Foundation

final class PortfolioCalculator {
    private let corporateActionsAdjuster: CorporateActionsAdjusting?
    private let actionsProvider: CorporateActionsProviding?

    init(
        corporateActionsAdjuster: CorporateActionsAdjusting? = nil,
        corporateActionsProvider: CorporateActionsProviding? = nil
    ) {
        self.corporateActionsAdjuster = corporateActionsAdjuster
        self.actionsProvider = corporateActionsProvider
    }

    func summarize(
        trades: [DCATrade],
        lots: [HoldingLot],
        latestPrices: [AssetCode: Decimal]
    ) -> (perAsset: [AssetSummary], totals: AssetSummary) {
        var perAssetDict: [AssetCode: AssetSummary] = [:]

        let groupedTrades = Dictionary(
            grouping: trades,
            by: { trade in
                AssetCode(rawValue: trade.asset ?? "USD") ?? .USD
            })
        let groupedLots = Dictionary(
            grouping: lots,
            by: { lot in
                AssetCode(rawValue: lot.asset ?? "USD") ?? .USD
            })

        for code in AssetCode.allCases {
            let t = groupedTrades[code] ?? []
            let l = groupedLots[code] ?? []
            let tradeUnits = t.reduce(Decimal.zero) {
                MoneyPrecisionHelper.add($0, $1.quantity?.decimalValue ?? 0)
            }
            let lotUnits = l.reduce(Decimal.zero) {
                MoneyPrecisionHelper.add($0, $1.quantity?.decimalValue ?? 0)
            }
            var units = MoneyPrecisionHelper.add(tradeUnits, lotUnits)

            let tradeCost = t.reduce(Decimal.zero) {
                MoneyPrecisionHelper.add($0, $1.totalCostTRY?.decimalValue ?? 0)
            }
            let lotCost = l.reduce(Decimal.zero) {
                MoneyPrecisionHelper.add($0, $1.totalCostTRY?.decimalValue ?? 0)
            }
            var cost = MoneyPrecisionHelper.add(tradeCost, lotCost)

            if let adjuster = corporateActionsAdjuster,
                let provider = actionsProvider,
                !provider.actions(for: code).isEmpty
            {
                let assetActions = provider.actions(for: code)
                let adjusted = adjuster.adjust(
                    positionQty: units,
                    avgCost: units == 0 ? 0 : MoneyPrecisionHelper.divide(cost, units),
                    actions: assetActions)
                units = MoneyPrecisionHelper.round(adjusted.qty)
                cost = MoneyPrecisionHelper.multiply(units, adjusted.avgCost)
            }

            let avg = units == 0 ? Decimal.zero : MoneyPrecisionHelper.divide(cost, units)
            let price = latestPrices[code] ?? Decimal.zero
            let value = MoneyPrecisionHelper.multiply(units, price)
            let pnl = MoneyPrecisionHelper.subtract(value, cost)
            let roi = cost == 0 ? Decimal.zero : MoneyPrecisionHelper.divide(pnl, cost)

            let summary = AssetSummary(
                asset: code,
                quantity: units,
                averageCost: avg,
                currentPrice: price,
                currentValue: value,
                profitLoss: pnl,
                profitLossPercentage: roi,
                allocation: 0,
                roi: roi,
                totalCost: cost,
                totalUnits: units,
                avgCost: avg,
                pnl: pnl
            )
            if units > 0 || cost > 0 {
                if let existing = perAssetDict[code] {
                    perAssetDict[code] = merge(existing: existing, with: summary)
                } else {
                    perAssetDict[code] = summary
                }
            }
        }

        let perAsset = Array(perAssetDict.values)
        let totalCost = perAsset.reduce(Decimal.zero) { MoneyPrecisionHelper.add($0, $1.totalCost) }
        let totalValue = perAsset.reduce(Decimal.zero) {
            MoneyPrecisionHelper.add($0, $1.currentValue)
        }
        let totalUnits = perAsset.reduce(Decimal.zero) {
            MoneyPrecisionHelper.add($0, $1.totalUnits)
        }
        let totalPnl = MoneyPrecisionHelper.subtract(totalValue, totalCost)
        let totalRoi =
            totalCost == 0 ? Decimal.zero : MoneyPrecisionHelper.divide(totalPnl, totalCost)
        let totals = AssetSummary(
            asset: .USD,
            quantity: totalUnits,
            averageCost: totalCost,
            currentPrice: totalValue,
            currentValue: totalValue,
            profitLoss: totalPnl,
            profitLossPercentage: totalRoi,
            allocation: 100,
            roi: totalRoi,
            totalCost: totalCost,
            totalUnits: totalUnits,
            avgCost: totalCost,
            pnl: totalPnl
        )
        return (perAsset, totals)
    }

    private func merge(existing: AssetSummary, with newSummary: AssetSummary) -> AssetSummary {
        let totalUnits = MoneyPrecisionHelper.add(existing.totalUnits, newSummary.totalUnits)
        let totalCost = MoneyPrecisionHelper.add(existing.totalCost, newSummary.totalCost)
        let currentValue = MoneyPrecisionHelper.add(existing.currentValue, newSummary.currentValue)
        let pnl = MoneyPrecisionHelper.subtract(currentValue, totalCost)
        let avgCost =
            totalUnits == 0 ? Decimal.zero : MoneyPrecisionHelper.divide(totalCost, totalUnits)
        let roi = totalCost == 0 ? Decimal.zero : MoneyPrecisionHelper.divide(pnl, totalCost)
        return AssetSummary(
            asset: existing.asset,
            quantity: totalUnits,
            averageCost: avgCost,
            currentPrice: newSummary.currentPrice,
            currentValue: currentValue,
            profitLoss: pnl,
            profitLossPercentage: roi,
            allocation: 0,
            roi: roi,
            totalCost: totalCost,
            totalUnits: totalUnits,
            avgCost: avgCost,
            pnl: pnl
        )
    }
}
