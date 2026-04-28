import SwiftUI
import FirebaseCore

/// App 入口
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        // 注册远程推送
        UNUserNotificationCenter.current().delegate = NotificationService.shared
        
        return true
    }
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Firebase 会自动注册 FCM Token
        print("📱 已获取推送Token")
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ 推送注册失败: \(error.localizedDescription)")
    }
}

@main
struct UnlockAlertApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var selectedTab = 0
    
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
            .onAppear {
                // 启动时请求通知权限
                Task {
                    _ = await NotificationService.shared.requestPermission()
                }
            }
        }
    }
}
