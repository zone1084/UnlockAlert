import SwiftUI
import Firebase

/// 设置页
struct SettingsView: View {
    @State private var notificationsEnabled = false
    @State private var showNotificationSettings = false
    @State private var appVersion = "1.0.0"
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: 通知设置
                Section("通知设置") {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("推送通知", systemImage: "bell.badge.fill")
                    }
                    .onChange(of: notificationsEnabled) { _, newValue in
                        Task {
                            if newValue {
                                _ = await NotificationService.shared.requestPermission()
                            }
                        }
                    }
                    
                    Button {
                        showNotificationSettings = true
                    } label: {
                        Label("通知偏好说明", systemImage: "info.circle")
                    }
                    .foregroundColor(.blue)
                }
                
                // MARK: 数据来源
                Section("数据来源") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("CoinGecko API", systemImage: "1.circle")
                        Label("链上合约数据（Etherscan/BSCScan）", systemImage: "2.circle")
                        Label("项目方公开披露信息", systemImage: "3.circle")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                // MARK: 关于
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://github.com/YOUR_USERNAME/UnlockAlert")!) {
                        HStack {
                            Label("开源代码", systemImage: "chevron.left.forwardslash.chevron.right")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }
                }
                
                // MARK: 免责声明
                Section {
                    VStack(spacing: 12) {
                        Text("⚠️ 重要免责声明")
                            .font(.headline)
                        
                        Text("""
                        Unlock Alert 展示的所有数据来源于公开的区块链信息和第三方API。代币解锁事件、时间表和金额可能因项目方调整、链上数据差异或API更新不及时而产生偏差。
                        
                        本应用不提供任何投资建议、买卖建议或价格预测。代币解锁事件不必然导致价格下跌，市场受多种因素影响。在做出任何投资决策前，请自行研究（DYOR）并咨询专业财务顾问。
                        
                        加密货币投资风险极高，您可能会损失全部本金。
                        """)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("⚙️ 设置")
            .task {
                notificationsEnabled = await NotificationService.shared.isAuthorized
            }
            .sheet(isPresented: $showNotificationSettings) {
                notificationGuide
            }
        }
    }
    
    // MARK: - 通知指南
    private var notificationGuide: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("当你关注一个代币，系统会自动：")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 12) {
                    Label("解锁前 7 天 → 推送提醒", systemImage: "1.circle.fill")
                    Label("解锁前 3 天 → 推送提醒", systemImage: "2.circle.fill")
                    Label("解锁前 1 天 → 推送提醒", systemImage: "3.circle.fill")
                    Label("解锁当日 → 推送提醒", systemImage: "4.circle.fill")
                }
                .font(.subheadline)
                
                Text("你可以在 iOS 设置中管理每个代币的通知偏好。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(24)
            .navigationTitle("通知说明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showNotificationSettings = false }
                }
            }
        }
    }
}
