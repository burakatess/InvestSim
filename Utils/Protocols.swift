import Foundation

protocol CorporateActionsAdjusting {
    func adjust(positionQty: Decimal, avgCost: Decimal, actions: [CorporateAction]) -> (qty: Decimal, avgCost: Decimal)
}

protocol CorporateActionsProviding {
    func actions(for asset: AssetCode) -> [CorporateAction]
}

struct CorporateAction {
    let date: Date
    let type: ActionType
    let ratio: Decimal
}

enum ActionType {
    case split
    case reverseSplit
    case dividend
}
