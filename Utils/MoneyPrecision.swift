import Foundation

enum MoneyPrecision: Int, CaseIterable {
    case two = 2
    case three = 3
    case four = 4
}

struct MoneyPrecisionHelper {
    static func add(_ lhs: Decimal, _ rhs: Decimal) -> Decimal {
        return lhs + rhs
    }
    
    static func subtract(_ lhs: Decimal, _ rhs: Decimal) -> Decimal {
        return lhs - rhs
    }
    
    static func multiply(_ lhs: Decimal, _ rhs: Decimal) -> Decimal {
        return lhs * rhs
    }
    
    static func divide(_ lhs: Decimal, _ rhs: Decimal) -> Decimal {
        guard rhs != 0 else { return 0 }
        return lhs / rhs
    }
    
    static func round(_ value: Decimal) -> Decimal {
        var result = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &result, 4, .bankers)
        return rounded
    }
}
