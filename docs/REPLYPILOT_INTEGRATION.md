# ReplyPilot Integration

This document explains how the iMessage Claude Assistant relates to the broader ReplyPilot architecture — and how an iOS companion could integrate in the future.

---

## What this repo is

`imessage-claude-assistant` is the **Mac Bridge** layer. It runs entirely on macOS and has two components:

1. **MCP server** (`plugins/imessage/server.ts`) — a bun/TypeScript process that:
   - Reads `~/Library/Messages/chat.db` via SQLite
   - Enforces an allowlist of contacts
   - Exposes a local HTTP bridge on port 7842

2. **Menubar app** (`macos/iMessageAssistant/`) — a SwiftUI/macOS app that:
   - Polls the bridge for pending threads
   - Calls `claude -p` to generate 3 draft replies
   - Lets the user approve and send from a popover

---

## Why macOS only (for now)

iMessage access requires:

- **Full Disk Access (FDA)** to read `chat.db` — a macOS TCC permission that apps must be granted by the user
- **AppleScript / Messages.app control** to send — macOS only
- **Direct SQLite reads** — iOS sandboxes prevent any app from reading another app's database

An iOS companion app **cannot read or send iMessages directly**. It must communicate with the Mac Bridge over the local network.

---

## Bonjour advertisement (planned)

The Mac Bridge is designed to advertise itself on the local network using Bonjour so an iOS companion can discover it automatically:

```
Service type: _replypilot._tcp
```

This is not yet implemented in `server.ts` — it is reserved for when an iOS companion app is built.

---

## Current architecture

```
macOS only
──────────────────────────────────────────────────────
chat.db  ←── bun MCP server (server.ts)
                    │  IMESSAGE_BRIDGE_ENABLED=1
                    ▼
             HTTP bridge :7842  ←── Bearer token auth
                    │
             iMessageAssistant.app
                    │
              claude -p (Claude Pro)
                    │
             User approves → POST /v1/reply → Messages.app
```

---

## Future iOS companion

An iOS app in a separate repo would:

1. Discover the Mac Bridge via Bonjour (`_replypilot._tcp`)
2. Authenticate using the same Bearer token (scanned via QR code on first pair)
3. Poll `GET /v1/pending` to show a list of threads needing replies
4. Call `GET /v1/draft` to get the pre-formatted thread context
5. Display and optionally edit the 3 Claude-generated drafts
6. Call `POST /v1/reply` to send the approved text through the Mac

**The approval model remains the same**: no message is ever sent without explicit user action. `POST /v1/reply` is only called after the user taps Send in the iOS UI.

---

## Security considerations for LAN access

If `bridgeHost` is set to `0.0.0.0`:

- Use only on trusted home/office networks or behind a VPN
- The Bearer token is the sole authentication mechanism (no TLS in v1)
- The allowlist (configured in `preferences.json`) is enforced server-side regardless of which client calls the API
- File attachments are blocked at the bridge layer
- All inbound message text is treated as untrusted (potential prompt injection)

See [BRIDGE_API.md](BRIDGE_API.md) for full security model details.

---

## Repository layout

```
imessage-claude-assistant/  ← this repo (Mac Bridge)
├── plugins/imessage/        ← bun MCP + HTTP bridge server
├── macos/iMessageAssistant/ ← SwiftUI menubar app (v1 client)
├── docs/BRIDGE_API.md       ← HTTP API reference
└── docs/ARCHITECTURE.md     ← overall system design

replypilot-ios/              ← future repo (iOS companion)
```
