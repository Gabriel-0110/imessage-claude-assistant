import SwiftUI
import ServiceManagement

@main
struct iMessageAssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // No windows — menubar-only app
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock
        NSApp.setActivationPolicy(.accessory)

        // Register as Login Item on first run
        if !UserDefaults.standard.bool(forKey: "loginItemRegistered") {
            try? SMAppService.mainApp.register()
            UserDefaults.standard.set(true, forKey: "loginItemRegistered")
        }

        NotificationService.shared.requestPermission()

        // Start status bar and polling
        statusBarController = StatusBarController(appState: appState)
        appState.startPolling()

        // Update badge when pending count changes
        NotificationCenter.default.addObserver(
            forName: .pendingCountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.statusBarController?.updateBadge()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.stopPolling()
    }
}
