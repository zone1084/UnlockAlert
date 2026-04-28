import Foundation
import Combine

/// 数据服务 — 从 GitHub Raw 读取 JSON 数据
/// 不需要 Firebase，不需要任何账号
class TokenDataService: ObservableObject {
    static let shared = TokenDataService()
    
    @Published var tokens: [Token] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // GitHub raw 数据地址（由 GitHub Actions 每天自动更新）
    private let dataURL = "https://raw.githubusercontent.com/zone1084/UnlockAlert/master/data/tokens.json"
    
    private init() {}
    
    /// 加载代币数据
    func loadTokens() async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        
        do {
            guard let url = URL(string: dataURL) else {
                throw ServiceError.invalidURL
            }
            
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw ServiceError.httpError
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let decoded = try decoder.decode([Token].self, from: data)
            
            await MainActor.run {
                tokens = decoded
                isLoading = false
            }
        } catch {
            print("⚠️ GitHub 数据加载失败: \(error.localizedDescription)")
            
            // 降级方案：本地缓存/示例数据
            if tokens.isEmpty {
                await MainActor.run {
                    tokens = Token.samples
                    errorMessage = "联网失败，显示示例数据"
                    isLoading = false
                }
            } else {
                await MainActor.run { isLoading = false }
            }
        }
    }
    
    /// 刷新数据
    func refresh() async {
        await loadTokens()
    }
    
    /// 搜索代币
    func searchTokens(query: String) -> [Token] {
        if query.isEmpty { return tokens }
        return tokens.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.symbol.localizedCaseInsensitiveContains(query)
        }
    }
    
    enum ServiceError: Error, LocalizedError {
        case invalidURL
        case httpError
        case decodeError
        
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "无效的数据地址"
            case .httpError: return "数据加载失败"
            case .decodeError: return "数据格式错误"
            }
        }
    }
}
