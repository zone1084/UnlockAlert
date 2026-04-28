import Foundation
import FirebaseFirestore
import Combine

/// Firestore 数据服务 - 负责从 Firebase 读取代币解锁数据
class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()
    private let cache = NSCache<NSString, NSArray>()
    
    private init() {
        cache.countLimit = 50
    }
    
    // MARK: - 获取所有代币
    func fetchAllTokens() async throws -> [Token] {
        let snapshot = try await db.collection("tokens")
            .order(by: "nextUnlockDate")
            .limit(to: 100)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            do {
                return try doc.data(as: Token.self)
            } catch {
                print("⚠️ Failed to decode token \(doc.documentID): \(error)")
                return nil
            }
        }
    }
    
    // MARK: - 获取单个代币
    func fetchToken(id: String) async throws -> Token? {
        let doc = try await db.collection("tokens").document(id).getDocument()
        return try doc.data(as: Token.self)
    }
    
    // MARK: - 搜索代币
    func searchTokens(query: String) async throws -> [Token] {
        let snapshot = try await db.collection("tokens")
            .order(by: "name")
            .start(at: [query])
            .end(at: [query + "\u{f8ff}"])
            .limit(to: 20)
            .getDocuments()
        
        return snapshot.documents.compactMap { try? $0.data(as: Token.self) }
    }
    
    // MARK: - 获取即将解锁的代币
    func fetchUpcomingUnlocks(days: Int = 30) async throws -> [Token] {
        let thirtyDaysLater = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        
        let snapshot = try await db.collection("tokens")
            .whereField("nextUnlockDate", isLessThan: thirtyDaysLater)
            .whereField("nextUnlockDate", isGreaterThan: Date())
            .order(by: "nextUnlockDate")
            .limit(to: 50)
            .getDocuments()
        
        return snapshot.documents.compactMap { try? $0.data(as: Token.self) }
    }
    
    // MARK: - 获取大额解锁（>$10M）
    func fetchLargeUnlocks(minUsd: Double = 10_000_000) async throws -> [Token] {
        let snapshot = try await db.collection("tokens")
            .whereField("nextUnlockValueUsd", isGreaterThan: minUsd)
            .order(by: "nextUnlockValueUsd", descending: true)
            .limit(to: 50)
            .getDocuments()
        
        return snapshot.documents.compactMap { try? $0.data(as: Token.self) }
    }
}
