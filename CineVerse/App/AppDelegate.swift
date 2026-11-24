import UIKit
import UserNotifications

public extension Notification.Name {
    static let cineVerseDeepLink = Notification.Name("com.cineverse.deepLink")
}

public final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    public static var backgroundRefreshAction: (@Sendable () async -> Void)?
    private let backgroundRefreshService = BackgroundRefreshService()

    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        backgroundRefreshService.register {
            let action = await MainActor.run { AppDelegate.backgroundRefreshAction }
            if let action {
                await action()
            }
        }
        backgroundRefreshService.scheduleNextRefresh()
        return true
    }

    public func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        MainActor.assumeIsolated {
            OrientationController.shared.mask
        }
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let deepLink = response.notification.request.content.userInfo["deepLink"] as? String
        if let deepLink, let url = URL(string: deepLink) {
            await MainActor.run {
                NotificationCenter.default.post(name: .cineVerseDeepLink, object: url)
            }
        }
    }
}
