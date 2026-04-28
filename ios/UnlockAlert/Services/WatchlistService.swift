import Foundation
import Combine

/// 关注列表管理器 - 使用 UserDefaults 本地存储
class WatchlistService: ObservableObject {
    static let shared = WatchlistService()
    
    @Published var followedTokens: Set<String> = []
    @Published var followedDetails: [String: FollowedTokenInfo] = [:]
    
    private let defaults = UserDefaults.standard
    private let followKey = "followed_tokens"
    private let detailKey = "followed_token_details"
    
    private init() {
        load()
    }
    
    // MARK: - 关注/取关
    func toggleFollow(token: Token) {
        guard let id = token.id else { return }
        if followedTokens.contains(id) {
            followedTokens.remove(id)
            followedDetails.removeValue(forKey: id)
        } else {
            followedTokens.insert(id)
            followedDetails[id] = FollowedTokenInfo(
                notify7Days: true,
                notify3Days: true,
                notify1Day: true,
                notifyOnDay: true
            )
            // 注册本地通知
            for unlock in token.unlocks where unlock.date > Date() {
                if followedDetails[id]?.notify7Days ?? true && unlock.date.timeIntervalSinceNow > 7*24*3600 {
                    NotificationService.shared.scheduleLocalUnlockReminder(
                        tokenName: token.name, symbol: token.symbol,
                        unlockDate: unlock.date, daysBefore: 7
                    )
                }
                if followedDetails[id]?.notify3Days ?? true && unlock.date.timeIntervalSinceNow > 3*24*3600 {
                    NotificationService.shared.scheduleLocalUnlockReminder(
                        tokenName: token.name, symbol: token.symbol,
                        unlockDate: unlock.date, daysBefore: 3
                    )
                }
                if followedDetails[id]?.notify1Day ?? true {
                    NotificationService.shared.scheduleLocalUnlockReminder(
                        tokenName: token.name, symbol: token.symbol,
                        unlockDate: unlock.date, daysBefore: 1
                    )
                }
            }
        }
        save()
    }
    
    func isFollowed(tokenId: String) -> Bool {
        followedTokens.contains(tokenId)
    }
    
    func updateNotificationPrefs(tokenId: String, prefs: FollowedTokenInfo) {
        followedDetails[tokenId] = prefs
        save()
    }
    
    // MARK: - Persistence
    private func save() {
        defaults.register(defaults: [followKey: []])
        defaults.set(Array(followedTokens), forKey: followKey)
        if let encoded = try? JSONEncoder().encode(followedDetails) {
            defaults.set(encoded, forKey: detailKey)
        }
    }
    
    private func load() {
        if let saved = defaults.array(forKey: followKey) as? [String] {
            followedTokens = Set(saved)
        }
        if let data = defaults.data(forKey: detailKey),
           let decoded = try? JSONDecoder().decode([String: FollowedTokenInfo].self, from: data) {
            followedDetails = decoded
        }
    }
}

struct FollowedTokenInfo: Codable {
    var notify7Days: Bool
    var notify3Days: Bool
    var notify1Day: Bool
    var notifyOnDay: Bool
}
