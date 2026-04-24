import AppKit
import SwiftUI

class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var eventMonitor: Any?
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        super.init()

        // Configure popover
        popover.contentSize = NSSize(width: 360, height: 480)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView().environmentObject(appState)
        )

        // Configure status bar button
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "message.badge", accessibilityDescription: "iMessage Assistant")
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Listen for notification taps
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openThreadFromNotification(_:)),
            name: .openThreadFromNotification,
            object: nil
        )

        // Watch badge count
        NotificationCenter.default.addObserver(
            forName: .pendingCountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateBadge()
        }
    }

    @objc func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            openPopover()
        }
    }

    private func openPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // Close when clicking outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    @objc private func openThreadFromNotification(_ note: Notification) {
        openPopover()
        if let guid = note.userInfo?["chat_guid"] as? String,
           let thread = appState.pendingThreads.first(where: { $0.chat_guid == guid }) {
            appState.loadDrafts(for: thread)
        }
    }

    func updateBadge() {
        let count = appState.pendingThreads.count
        if let button = statusItem.button {
            if count > 0 {
                button.image = NSImage(systemSymbolName: "message.badge.filled.bubble.left", accessibilityDescription: "iMessage Assistant (\(count))")
            } else {
                button.image = NSImage(systemSymbolName: "message", accessibilityDescription: "iMessage Assistant")
            }
        }
    }
}

extension Notification.Name {
    static let pendingCountChanged = Notification.Name("pendingCountChanged")
}
