import SwiftUI

/// 代币详情页 - 解锁时间线 + 价格信息
struct TokenDetailView: View {
    let token: Token
    @ObservedObject private var watchlist = WatchlistService.shared
    @State private var showNotificationSettings = false
    @State private var selectedUnlock: UnlockEvent?
    
    private var upcomingUnlocks: [UnlockEvent] {
        token.unlocks
            .filter { $0.date > Date() }
            .sorted { $0.date < $1.date }
    }
    
    private var pastUnlocks: [UnlockEvent] {
        token.unlocks
            .filter { $0.date <= Date() }
            .sorted { $0.date > $1.date }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero Card
                heroCard
                
                // 代币概览
                overviewCards
                
                // 解锁时间线
                if !upcomingUnlocks.isEmpty {
                    upcomingSection
                }
                
                // 已发生的解锁
                if !pastUnlocks.isEmpty {
                    pastSection
                }
                
                // 免责声明
                disclaimer
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(token.symbol)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    watchlist.toggleFollow(token: token)
                } label: {
                    Image(systemName: watchlist.isFollowed(tokenId: token.id ?? "") ? "bell.fill" : "bell")
                }
            }
        }
    }
    
    // MARK: - Hero Card
    private var heroCard: some View {
        VStack(spacing: 16) {
            // 图标 + 价格
            HStack(spacing: 16) {
                AsyncImage(url: URL(string: token.imageUrl ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    case .failure:
                        Circle().fill(Color.gray.opacity(0.2))
                    case .empty:
                        Circle().fill(Color.gray.opacity(0.1))
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(token.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("$\(String(format: "%.2f", token.currentPrice))")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("市值 \(formatUSD(token.marketCap))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // 下次解锁倒计时
            if let next = token.nextUnlock {
                VStack(spacing: 8) {
                    CountdownView(targetDate: next.date)
                        .frame(height: 60)
                    
                    HStack {
                        Text("解锁量:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(token.nextUnlockValueUsd)
                            .font(.headline)
                            .foregroundColor(.red)
                        Text("(\(token.nextUnlockPercentage))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 12) {
                        Label(next.type == "cliff" ? "一次性解锁" : "线性解锁", systemImage: next.type == "cliff" ? "bolt.fill" : "chart.line.uptrend.xyaxis")
                        Text("·")
                        Text(categoryLabel(next.category))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.08))
                .cornerRadius(14)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(18)
    }
    
    // MARK: - 概览卡片
    private var overviewCards: some View {
        HStack(spacing: 12) {
            MetricCard(title: "流通量", value: formatNumber(token.circulatingSupply), subtitle: "\(String(format: "%.1f", token.circulatingSupply/token.totalSupply*100))% 已解锁")
            MetricCard(title: "总供应量", value: formatNumber(token.totalSupply), subtitle: "全量")
            MetricCard(title: "30天解锁", value: formatUSD(token.unlockValueNext30Days), subtitle: token.unlocksComingSoon, valueColor: token.unlockValueNext30Days > 10_000_000 ? .red : .primary)
        }
    }
    
    // MARK: - 即将解锁
    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundColor(.orange)
                Text("即将解锁")
                    .font(.headline)
                Spacer()
                Text("共 \(upcomingUnlocks.count) 次")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ForEach(upcomingUnlocks) { unlock in
                UnlockRow(unlock: unlock, currentPrice: token.currentPrice)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(18)
    }
    
    // MARK: - 已解锁
    private var pastSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.green)
                Text("已完成解锁")
                    .font(.headline)
                Spacer()
                Text("共 \(pastUnlocks.count) 次")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ForEach(pastUnlocks.prefix(10)) { unlock in
                UnlockRow(unlock: unlock, currentPrice: token.currentPrice, isPast: true)
            }
            
            if pastUnlocks.count > 10 {
                Text("及更多 \(pastUnlocks.count - 10) 次...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(18)
    }
    
    // MARK: - 免责声明
    private var disclaimer: some View {
        VStack(spacing: 4) {
            Text("⚠️ 免责声明")
                .font(.caption)
                .fontWeight(.semibold)
            Text("本应用展示的数据来源于公开的链上信息和项目方披露，仅供参考，不构成任何投资建议。代币解锁事件可能因项目方调整而发生变化，请以官方公告为准。投资有风险，决策需谨慎。")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(14)
    }
    
    // MARK: - Helpers
    private func categoryLabel(_ category: String) -> String {
        switch category {
        case "team": return "团队"
        case "vc": return "机构投资者"
        case "advisor": return "顾问"
        case "community": return "社区"
        case "foundation": return "基金会"
        case "treasury": return "国库"
        default: return category
        }
    }
}

// MARK: - 指标卡片
struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    var valueColor: Color = .primary
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(valueColor)
                .minimumScaleFactor(0.7)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - 解锁单行
struct UnlockRow: View {
    let unlock: UnlockEvent
    let currentPrice: Double
    var isPast = false
    
    var body: some View {
        HStack {
            // 日期
            VStack(alignment: .leading, spacing: 2) {
                Text(unlock.date, style: .date)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if isPast {
                    Text("已解锁")
                        .font(.caption2)
                        .foregroundColor(.green)
                } else {
                    Text(unlock.date, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            // 金额
            VStack(alignment: .trailing, spacing: 2) {
                let value = unlock.amount * currentPrice
                Text(formatUSD(value))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(isPast ? .secondary : .red)
                Text("\(formatNumber(unlock.amount)) 枚")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .opacity(isPast ? 0.6 : 1)
        
        if unlock != upcomingUnlocks.last, unlock != pastUnlocks.last {
            Divider()
        }
    }
    
    private var upcomingUnlocks: [UnlockEvent] { [] }
    private var pastUnlocks: [UnlockEvent] { [] }
}

// MARK: - 倒计时视图
struct CountdownView: View {
    let targetDate: Date
    @State private var now = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var components: DateComponents {
        Calendar.current.dateComponents([.day, .hour, .minute, .second], from: now, to: targetDate)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            countdownUnit(value: components.day ?? 0, label: "天")
            countdownUnit(value: components.hour ?? 0, label: "时")
            countdownUnit(value: components.minute ?? 0, label: "分")
            countdownUnit(value: components.second ?? 0, label: "秒")
        }
        .onReceive(timer) { time in
            now = time
        }
    }
    
    private func countdownUnit(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text(String(format: "%02d", max(0, value)))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(value <= 0 && label == "秒" ? .red : .primary)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 40)
    }
}

// MARK: - Number formatting
func formatNumber(_ value: Double) -> String {
    let absValue = abs(value)
    if absValue >= 1_000_000_000 {
        return String(format: "%.2fB", value / 1_000_000_000)
    } else if absValue >= 1_000_000 {
        return String(format: "%.2fM", value / 1_000_000)
    } else if absValue >= 1_000 {
        return String(format: "%.2fK", value / 1_000)
    } else {
        return String(format: "%.0f", value)
    }
}
