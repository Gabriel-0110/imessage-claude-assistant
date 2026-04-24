# iMessageAssistant — macOS Menubar App

A native SwiftUI menubar app that sits in your Mac's status bar, polls the local iMessage bridge server for pending threads, generates three Claude reply drafts, and lets you approve and send — all without touching a terminal.

---

## Prerequisites

- macOS 14 (Sonoma) or later
- Xcode 15+
- The bun LaunchAgent running with `IMESSAGE_BRIDGE_ENABLED=1`  
  (installed via `scripts/install-imessage-launch-agent.sh`)

---

## Xcode project setup (one-time)

The Swift source files are committed to the repo. You need to create the Xcode project wrapper once:

### 1. Create the project

1. Open Xcode → **File → New → Project**
2. Choose **macOS → App**
3. Set:
   - **Product Name**: `iMessageAssistant`
   - **Bundle Identifier**: `com.gabriel.iMessageAssistant`
   - **Interface**: SwiftUI
   - **Language**: Swift
4. Save to `macos/iMessageAssistant/` inside this repo

### 2. Remove the generated ContentView

Delete `ContentView.swift` (the template file Xcode creates). The repo provides its own entry point.

### 3. Add the existing source files

Right-click the `iMessageAssistant` group in the Project Navigator → **Add Files to "iMessageAssistant"**, then select all `.swift` files from:

```
macos/iMessageAssistant/iMessageAssistant/
macos/iMessageAssistant/iMessageAssistant/Views/
```

Make sure **"Copy items if needed"** is **unchecked** (the files are already in the right place).

### 4. Configure Info.plist

Add the following keys to your target's `Info.plist`:

| Key | Type | Value |
|---|---|---|
| `LSUIElement` | Boolean | `YES` — hides the app from the Dock |
| `NSUserNotificationsUsageDescription` | String | `Show reply notifications for incoming iMessages` |

### 5. Add the User Notifications capability

In your target: **Signing & Capabilities → + Capability → User Notifications**

### 6. Set the deployment target

In the target's **General** tab, set **Minimum Deployments** to **macOS 14.0**.

---

## Build and run

Press **⌘R** in Xcode. The app will appear as a message-bubble icon in your menu bar (no Dock icon).

Make sure the bun LaunchAgent is running before you open the menubar:

```bash
launchctl kickstart -k gui/$(id -u)/com.gabriel.imessage-claude
sleep 3
curl -s -H "Authorization: Bearer $(python3 -c "import json,os; print(json.load(open(os.path.expanduser('~/.claude/channels/imessage/style/preferences.json')))['bridgeToken'])")" \
  http://localhost:7842/v1/health
```

Expected output: `{"ok":true,"uptime":...}`

---

## Source file overview

```
iMessageAssistant/
├── iMessageAssistantApp.swift   — @main, AppDelegate, SMAppService Login Item
├── AppState.swift               — ObservableObject: polling loop, drafts, send
├── BridgeClient.swift           — HTTP calls to the bridge + all model types
├── DraftService.swift           — Spawns `claude -p`, parses JSON drafts
├── NotificationService.swift    — UNUserNotificationCenter banners
├── PreferencesReader.swift      — Reads bridgeToken + port from preferences.json
├── StatusBarController.swift    — NSStatusItem + NSPopover management
└── Views/
    ├── PopoverView.swift         — Root view: thread list or empty state
    ├── ThreadRowView.swift       — Single row: name + preview + time
    ├── ThreadDetailView.swift    — Conversation history (formatted by server)
    └── ReplyOptionsView.swift    — 3 draft cards + signature picker + Send
```

---

## How it works

```
LaunchAgent (bun)  →  polls chat.db  →  bridge HTTP on :7842
        ↑
iMessageAssistant.app
  └── polls GET /v1/pending every 3 s
  └── on new thread → UNNotification banner
  └── user clicks menubar icon → Popover
  └── select thread → GET /v1/draft → spawn claude -p → 3 options
  └── user picks option → POST /v1/reply → message sent
```

No message is ever sent without explicit user approval (tap Send button).

---

## Launch at Login

On first run `AppDelegate` registers the app as a Login Item via `SMAppService.mainApp.register()`. You can also manage it in **System Settings → General → Login Items**.

---

## Troubleshooting

| Symptom | Check |
|---|---|
| Menubar icon shows red dot | Bridge not reachable — confirm LaunchAgent is running |
| No threads appearing | Check `IMESSAGE_BRIDGE_ENABLED=1` is in the plist; check the allowlist in preferences.json |
| Claude not found | Confirm `~/.local/bin/claude`, `/opt/homebrew/bin/claude`, or `/usr/local/bin/claude` exists and is executable |
| Drafts fail with JSON error | Run `claude -p "say hi" 2>&1` in Terminal to verify claude is authenticated |

Logs from the bun server: `state/launchd.out.log` and `state/launchd.err.log`
