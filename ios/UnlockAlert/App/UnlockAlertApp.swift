import SwiftUI

/// App 入口 - 零后端版本
/// 数据从 GitHub raw JSON 读取，无需 Firebase
@main
struct UnlockAlertApp: App {
    @State private var selectedTab = 0
    @StateObject private var dataService = TokenDataService.shared
    
    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                TokenListView()
                    .tabItem {
                        Label("解锁预警", systemImage: "bell.badge")
                    }
                    .tag(0)
                
                WatchlistView()
                    .tabItem {
                        Label("关注", systemImage: "star")
                    }
                    .tag(1)
                
                SettingsView()
                    .tabItem {
                        Label("设置", systemImage: "gear")
                    }
                    .tag(2)
            }
            .tint(.blue)
            .task {
                // 启动时加载数据
                await dataService.loadTokens()
                // 请求通知权限
                _ = await NotificationService.shared.requestPermission()
            }
        }
    }
}
