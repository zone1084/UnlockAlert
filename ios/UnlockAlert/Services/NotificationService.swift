import Foundation
import UserNotifications
import FirebaseMessaging

/// 推送通知服务
class NotificationService: NSObject, UNUserNotificationCenterDelegate, MessagingDelegate {
    static let shared = NotificationService()
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
    }
    
    // MARK: - 请求权限
    func requestPermission() async -> Bool {
        let options: UNAuthorizationOptions = [.alert, .badge, .sound]
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options)
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            print("❌ 通知权限请求失败: \(error)")
            return false
        }
    }
    
    // MARK: - 检查权限状态
    var isAuthorized: Bool {
        get async {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            return settings.authorizationStatus == .authorized
        }
    }
    
    // MARK: - 注册本地通知（备选方案 - 如果远程推送不可用）
    func scheduleLocalUnlockReminder(tokenName: String, symbol: String, unlockDate: Date, daysBefore: Int) {
        let content = UNMutableNotificationContent()
        content.title = "🔓 \(symbol) 即将解锁"
        content.body = "\(tokenName) (\(symbol)) 将在 \(daysBefore) 天后解锁\n点击查看详情"
        content.sound = .default
        content.userInfo = ["tokenSymbol": symbol, "unlockDate": unlockDate.timeIntervalSince1970]
        
        let triggerDate = Calendar.current.date(byAdding: .day, value: -daysBefore, to: unlockDate) ?? unlockDate
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let identifier = "unlock-\(symbol)-\(daysBefore)d-\(unlockDate.timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 本地通知注册失败: \(error)")
            }
        }
    }
    
    /// 移除所有当前通知（关注取消时调用）
    func removeAllScheduledNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }
    
    // MARK: - MessagingDelegate
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("📱 FCM Token: \(fcmToken ?? "none")")
        // 可将FCM Token上传到Firestore，用于定向推送
    }
}
