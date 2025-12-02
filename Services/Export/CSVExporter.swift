import Combine
import Foundation

final class CSVExporter {
    func export(summary: AssetSummary, assets: [AssetSnapshotDTO]) -> Data {
        var csv = "Asset,Units,Avg Cost,Current Value,P/L,ROI\n"

        for asset in assets {
            csv +=
                "\(asset.asset.rawValue),\(asset.units),\(asset.avgCost),\(asset.currentValue),\(asset.pnl),0\n"
        }

        return csv.data(using: .utf8) ?? Data()
    }

    func exportPortfolio(_ assets: [AssetSnapshotDTO]) -> Data? {
        var csv = "Asset,Units,Avg Cost,Current Value,P/L,ROI\n"

        for asset in assets {
            csv +=
                "\(asset.asset.rawValue),\(asset.units),\(asset.avgCost),\(asset.currentValue),\(asset.pnl),0\n"
        }

        return csv.data(using: .utf8)
    }
}
