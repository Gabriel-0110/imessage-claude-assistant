import UserNotifications

class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func fireNotification(for thread: PendingThread) {
        let content = UNMutableNotificationContent()
        content.title = thread.displayName
        content.body = thread.preview ?? "New message"
        content.sound = .default
        content.userInfo = ["chat_guid": thread.chat_guid]

        let request = UNNotificationRequest(
            identifier: "imessage-\(thread.chat_guid)",
            content: content,
            trigger: nil // deliver immediately
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // Tapping notification opens the popover (handled by StatusBarController)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let guid = response.notification.request.content.userInfo["chat_guid"] as? String
        NotificationCenter.default.post(
            name: .openThreadFromNotification,
            object: nil,
            userInfo: guid.map { ["chat_guid": $0] }
        )
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

extension Notification.Name {
    static let openThreadFromNotification = Notification.Name("openThreadFromNotification")
}
