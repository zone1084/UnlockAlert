import Foundation
import SwiftUI
import Combine

/// 主列表 ViewModel
@MainActor
class TokenListViewModel: ObservableObject {
    @Published var tokens: [Token] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedFilter: UnlockFilter = .all
    @Published var searchText = ""
    
    private let firestore = FirestoreService.shared
    private var cancellables = Set<AnyCancellable>()
    
    enum UnlockFilter: String, CaseIterable {
        case all = "全部"
        case thisWeek = "本周"
        case nextWeek = "下周"
        case thisMonth = "本月"
        case large = "大额 >$10M"
    }
    
    var filteredTokens: [Token] {
        let result: [Token]
        
        switch selectedFilter {
        case .all:
            result = tokens
        case .thisWeek:
            let weekLater = Date().addingTimeInterval(7*24*3600)
            result = tokens.filter { t in
                t.unlocks.contains { $0.date > Date() && $0.date < weekLater }
            }
        case .nextWeek:
            let weekLater = Date().addingTimeInterval(7*24*3600)
            let twoWeeks = Date().addingTimeInterval(14*24*3600)
            result = tokens.filter { t in
                t.unlocks.contains { $0.date > weekLater && $0.date < twoWeeks }
            }
        case .thisMonth:
            let monthLater = Date().addingTimeInterval(30*24*3600)
            result = tokens.filter { t in
                t.unlocks.contains { $0.date > Date() && $0.date < monthLater }
            }
        case .large:
            result = tokens.filter { t in
                t.unlocks.contains { u in u.date > Date() && u.amount * t.currentPrice > 10_000_000 }
            }
        }
        
        if searchText.isEmpty {
            return result.sorted { t1, t2 in
                guard let d1 = t1.nextUnlock?.date, let d2 = t2.nextUnlock?.date else {
                    return t1.nextUnlock != nil
                }
                return d1 < d2
            }
        } else {
            return result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.symbol.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    func loadTokens() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 从Firestore加载
            let fetched = try await firestore.fetchAllTokens()
            if !fetched.isEmpty {
                tokens = fetched
            } else {
                // Fallback: 使用示例数据（当Firestore还没数据时）
                tokens = Token.samples
            }
        } catch {
            // Firestore不可用时使用示例数据
            tokens = Token.samples
            errorMessage = "离线模式 - 显示示例数据"
        }
        
        isLoading = false
    }
    
    func refresh() async {
        await loadTokens()
    }
}
