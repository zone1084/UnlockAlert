import SwiftUI

/// 关注列表页
struct WatchlistView: View {
    @ObservedObject private var watchlist = WatchlistService.shared
    @StateObject private var listVM = TokenListViewModel()
    @State private var followedTokens: [Token] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            Group {
                if watchlist.followedTokens.isEmpty {
                    emptyState
                } else {
                    listContent
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("⭐ 关注列表")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await loadFollowedTokens()
            }
            .refreshable {
                await loadFollowedTokens()
            }
        }
    }
    
    private var emptyState: some View {
        Spacer()
            .overlay {
                VStack(spacing: 16) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("还没有关注任何代币")
                        .font(.headline)
                    Text("在「解锁预警」页面关注代币后\n会在解锁前推送通知提醒你")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
            }
    }
    
    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(followedTokens) { token in
                    NavigationLink(destination: TokenDetailView(token: token)) {
                        TokenRow(token: token)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            withAnimation {
                                watchlist.toggleFollow(token: token)
                                followedTokens.removeAll { $0.id == token.id }
                            }
                        } label: {
                            Label("取消关注", systemImage: "bell.slash")
                        }
                    }
                }
            }
            .padding(16)
        }
    }
    
    private func loadFollowedTokens() async {
        isLoading = true
        await listVM.loadTokens()
        followedTokens = listVM.tokens.filter { watchlist.isFollowed(tokenId: $0.id ?? "") }
        isLoading = false
    }
}
