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
    
    private let dataService = TokenDataService.shared
    private var cancellables = Set<AnyCancellable>()
    
    enum UnlockFilter: String, CaseIterable {
        case all = "全部"
        case thisWeek = "本周"
        case nextWeek = "下周"
        case thisMonth = "本月"
        case large = "大额 >$10M"
    }
    
    var filteredTokens: [Token] {
        let now = Date()
        let weekLater = now.addingTimeInterval(7*24*3600)
        let twoWeeks = now.addingTimeInterval(14*24*3600)
        let monthLater = now.addingTimeInterval(30*24*3600)
        
        let result: [Token]
        
        switch selectedFilter {
        case .all:
            result = dataService.tokens
        case .thisWeek:
            result = dataService.tokens.filter { t in
                t.unlocks.contains { $0.date > now && $0.date < weekLater }
            }
        case .nextWeek:
            result = dataService.tokens.filter { t in
                t.unlocks.contains { $0.date > weekLater && $0.date < twoWeeks }
            }
        case .thisMonth:
            result = dataService.tokens.filter { t in
                t.unlocks.contains { $0.date > now && $0.date < monthLater }
            }
        case .large:
            result = dataService.tokens.filter { t in
                t.unlocks.contains { u in u.date > now && u.amount * t.currentPrice > 10_000_000 }
            }
        }
        
        // 搜索过滤
        let searched = searchText.isEmpty ? result : result.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.symbol.localizedCaseInsensitiveContains(searchText)
        }
        
        // 按下次解锁日期排序
        return searched.sorted { t1, t2 in
            guard let d1 = t1.nextUnlock?.date, let d2 = t2.nextUnlock?.date else {
                return t1.nextUnlock != nil
            }
            return d1 < d2
        }
    }
    
    func loadTokens() async {
        isLoading = true
        errorMessage = nil
        
        await dataService.loadTokens()
        
        isLoading = dataService.isLoading
        errorMessage = dataService.errorMessage
    }
    
    func refresh() async {
        await loadTokens()
    }
}
