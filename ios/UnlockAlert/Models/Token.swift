import Foundation
import FirebaseFirestore

/// 代币模型 - 从Firestore读取
struct Token: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var name: String
    var symbol: String
    var currentPrice: Double
    var marketCap: Double
    var circulatingSupply: Double
    var totalSupply: Double
    var imageUrl: String?
    var unlocks: [UnlockEvent]
    var lastUpdated: Date
    
    /// 下一次解锁事件
    var nextUnlock: UnlockEvent? {
        unlocks
            .filter { $0.date > Date() }
            .sorted { $0.date < $1.date }
            .first
    }
    
    /// 距下次解锁天数
    var daysUntilNextUnlock: Int? {
        guard let next = nextUnlock else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: next.date).day
    }
    
    /// 下次解锁占总流通百分比
    var nextUnlockPercentage: String {
        guard let next = nextUnlock, circulatingSupply > 0 else { return "—" }
        let pct = (next.amount / circulatingSupply) * 100
        return String(format: "%.1f%%", pct)
    }
    
    /// 下次解锁金额 (USD)
    var nextUnlockValueUsd: String {
        guard let next = nextUnlock else { return "—" }
        let value = next.amount * currentPrice
        return formatUSD(value)
    }
    
    /// 30天内解锁总额
    var unlockValueNext30Days: Double {
        let thirtyDaysLater = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        return unlocks
            .filter { $0.date > Date() && $0.date < thirtyDaysLater }
            .reduce(0) { $0 + $1.amount * currentPrice }
    }
    
    /// 最近30天解锁的描述
    var unlocksComingSoon: String {
        let thirtyDaysLater = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        let upcoming = unlocks.filter { $0.date > Date() && $0.date < thirtyDaysLater }
        if upcoming.isEmpty { return "本月无解锁" }
        let total = upcoming.reduce(0) { $0 + $1.amount }
        let pct = circulatingSupply > 0 ? (total / circulatingSupply) * 100 : 0
        return "\(upcoming.count)次解锁 · \(formatUSD(total * currentPrice)) (\(String(format: "%.1f", pct))%)"
    }
    
    static func == (lhs: Token, rhs: Token) -> Bool {
        lhs.id == rhs.id
    }
}

/// 解锁事件模型
struct UnlockEvent: Codable, Identifiable {
    var id: String { "\(date.timeIntervalSince1970)-\(type)" }
    var date: Date
    var amount: Double           // 解锁数量（代币数量）
    var percentageOfSupply: Double  // 解锁量占总流通%
    var type: String             // cliff / linear / monthly
    var category: String         // team / vc / treasury / advisor / community / foundation
    var description: String?     // 可选描述
    
    var valueUsd: String {
        "—"
    }
}

// MARK: - Helper
func formatUSD(_ value: Double) -> String {
    let absValue = abs(value)
    if absValue >= 1_000_000_000 {
        return String(format: "$%.2fB", value / 1_000_000_000)
    } else if absValue >= 1_000_000 {
        return String(format: "$%.2fM", value / 1_000_000)
    } else if absValue >= 1_000 {
        return String(format: "$%.2fK", value / 1_000)
    } else {
        return String(format: "$%.2f", value)
    }
}

// MARK: - 示例数据
extension Token {
    static var samples: [Token] {
        [
            Token(
                name: "Arbitrum", symbol: "ARB",
                currentPrice: 0.85, marketCap: 2_200_000_000,
                circulatingSupply: 2_800_000_000, totalSupply: 10_000_000_000,
                imageUrl: "https://assets.coingecko.com/coins/images/16547/small/arb.jpg",
                unlocks: [
                    UnlockEvent(date: Date().addingTimeInterval(7*24*3600), amount: 92_650_000, percentageOfSupply: 3.3, type: "cliff", category: "team", description: "团队解锁"),
                    UnlockEvent(date: Date().addingTimeInterval(30*24*3600), amount: 85_000_000, percentageOfSupply: 3.0, type: "cliff", category: "advisor"),
                    UnlockEvent(date: Date().addingTimeInterval(90*24*3600), amount: 100_000_000, percentageOfSupply: 3.6, type: "cliff", category: "vc"),
                ],
                lastUpdated: Date()),
            Token(
                name: "Aptos", symbol: "APT",
                currentPrice: 12.50, marketCap: 5_800_000_000,
                circulatingSupply: 490_000_000, totalSupply: 1_100_000_000,
                imageUrl: "https://assets.coingecko.com/coins/images/26455/small/aptos.png",
                unlocks: [
                    UnlockEvent(date: Date().addingTimeInterval(14*24*3600), amount: 23_100_000, percentageOfSupply: 4.7, type: "cliff", category: "foundation"),
                    UnlockEvent(date: Date().addingTimeInterval(60*24*3600), amount: 20_000_000, percentageOfSupply: 4.1, type: "cliff", category: "community"),
                ],
                lastUpdated: Date()),
            Token(
                name: "Sui", symbol: "SUI",
                currentPrice: 3.80, marketCap: 9_500_000_000,
                circulatingSupply: 2_500_000_000, totalSupply: 10_000_000_000,
                imageUrl: "https://assets.coingecko.com/coins/images/26375/small/sui.png",
                unlocks: [
                    UnlockEvent(date: Date().addingTimeInterval(3*24*3600), amount: 56_000_000, percentageOfSupply: 2.2, type: "linear", category: "vc"),
                    UnlockEvent(date: Date().addingTimeInterval(45*24*3600), amount: 50_000_000, percentageOfSupply: 2.0, type: "cliff", category: "team"),
                ],
                lastUpdated: Date()),
            Token(
                name: "Worldcoin", symbol: "WLD",
                currentPrice: 2.10, marketCap: 1_800_000_000,
                circulatingSupply: 850_000_000, totalSupply: 10_000_000_000,
                imageUrl: "https://assets.coingecko.com/coins/images/31069/small/worldcoin.jpg",
                unlocks: [
                    UnlockEvent(date: Date().addingTimeInterval(1*24*3600), amount: 3_420_000, percentageOfSupply: 0.4, type: "linear", category: "community"),
                    UnlockEvent(date: Date().addingTimeInterval(21*24*3600), amount: 6_620_000, percentageOfSupply: 0.8, type: "cliff", category: "team", description: "团队解锁"),
                ],
                lastUpdated: Date()),
            Token(
                name: "Ethena", symbol: "ENA",
                currentPrice: 0.55, marketCap: 1_500_000_000,
                circulatingSupply: 2_800_000_000, totalSupply: 15_000_000_000,
                imageUrl: "https://assets.coingecko.com/coins/images/36530/small/ethena.png",
                unlocks: [
                    UnlockEvent(date: Date().addingTimeInterval(5*24*3600), amount: 14_100_000, percentageOfSupply: 0.5, type: "cliff", category: "vc"),
                    UnlockEvent(date: Date().addingTimeInterval(35*24*3600), amount: 36_500_000, percentageOfSupply: 1.3, type: "cliff", category: "foundation"),
                ],
                lastUpdated: Date()),
        ]
    }
}
