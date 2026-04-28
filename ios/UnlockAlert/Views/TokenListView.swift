import SwiftUI

/// 主列表页 - 按即将解锁排序
struct TokenListView: View {
    @StateObject private var viewModel = TokenListViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 筛选器
                filterBar
                
                // 列表
                if viewModel.isLoading && viewModel.tokens.isEmpty {
                    loadingState
                } else if viewModel.tokens.isEmpty {
                    emptyState
                } else {
                    tokenList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("🔓 解锁预警")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $viewModel.searchText, prompt: "搜索代币名称或符号")
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.loadTokens()
            }
        }
    }
    
    // MARK: - 筛选栏
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TokenListViewModel.UnlockFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        isSelected: viewModel.selectedFilter == filter
                    ) {
                        withAnimation {
                            viewModel.selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - 加载中
    private var loadingState: some View {
        Spacer()
            .overlay {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("正在加载代币数据...")
                        .foregroundColor(.secondary)
                }
            }
    }
    
    // MARK: - 空状态
    private var emptyState: some View {
        Spacer()
            .overlay {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("没有找到匹配的代币")
                        .foregroundColor(.secondary)
                }
            }
    }
    
    // MARK: - 代币列表
    private var tokenList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredTokens) { token in
                    NavigationLink(destination: TokenDetailView(token: token)) {
                        TokenRow(token: token)
                    }
                    .buttonStyle(.plain)
                }
                
                if viewModel.errorMessage != nil {
                    Text(viewModel.errorMessage!)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, 8)
                }
            }
            .padding(16)
        }
    }
}

// MARK: - 单行代币
struct TokenRow: View {
    let token: Token
    @ObservedObject private var watchlist = WatchlistService.shared
    
    var body: some View {
        HStack(spacing: 14) {
            // 代币图标
            AsyncImage(url: URL(string: token.imageUrl ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                case .failure:
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay(Text(token.symbol.prefix(1)).font(.caption))
                case .empty:
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 44, height: 44)
                        .overlay(ProgressView().scaleEffect(0.6))
                @unknown default:
                    EmptyView()
                }
            }
            
            // 代币信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(token.symbol)
                        .font(.headline)
                        .fontWeight(.bold)
                    Text(token.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if let days = token.daysUntilNextUnlock {
                    HStack(spacing: 6) {
                        // 倒计时标签
                        if days <= 0 {
                            Label("今日解锁", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.red)
                                .cornerRadius(6)
                        } else if days <= 7 {
                            Label("\(days)天后", systemImage: "clock.fill")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.orange)
                                .cornerRadius(6)
                        } else {
                            Label("\(days)天后", systemImage: "calendar")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(token.nextUnlockValueUsd)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // 解锁百分比
            VStack(alignment: .trailing, spacing: 4) {
                Text(token.nextUnlockPercentage)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(token.nextUnlockPercentage.contains("0.0") || token.nextUnlockPercentage == "—" ? .secondary : .red)
                
                Text("占流通")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // 关注按钮
            Button {
                watchlist.toggleFollow(token: token)
            } label: {
                Image(systemName: watchlist.isFollowed(tokenId: token.id ?? "") ? "bell.fill" : "bell")
                    .foregroundColor(watchlist.isFollowed(tokenId: token.id ?? "") ? .blue : .gray)
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }
}

// MARK: - 筛选标签
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}
