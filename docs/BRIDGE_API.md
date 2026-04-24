# iMessage Bridge HTTP API

The bun/TypeScript MCP server (`plugins/imessage/server.ts`) optionally exposes a local HTTP bridge used by the native menubar app (`iMessageAssistant.app`). All endpoints are served on `localhost:7842` by default.

---

## Enabling the bridge

The bridge is **off by default**. Enable it one of two ways:

| Method | How |
|---|---|
| Environment variable | `IMESSAGE_BRIDGE_ENABLED=1` (set in the LaunchAgent plist) |
| Preferences file | Set `"bridgeEnabled": true` in `~/.claude/channels/imessage/style/preferences.json` |

The LaunchAgent installed by `scripts/install-imessage-launch-agent.sh` sets the env var automatically.

---

## Host and port

| Setting | Default | Override |
|---|---|---|
| Host | `localhost` | `0.0.0.0` for LAN access (set `"bridgeHost": "0.0.0.0"` in preferences) |
| Port | `7842` | Set `"bridgePort": <n>` in preferences |

> **Warning**: Exposing `0.0.0.0` on an untrusted network allows anyone on that network to read your messages. The bridge has no TLS. Use only on trusted LANs (e.g., behind a VPN).

---

## Authentication

All endpoints require a **Bearer token** in the `Authorization` header.

```
Authorization: Bearer <token>
```

The token is stored at:

```
~/.claude/channels/imessage/style/preferences.json  →  "bridgeToken"
```

If `bridgeToken` is absent the server generates and saves one on first start.

### Reading the token (shell)

```bash
TOKEN=$(python3 -c "
import json, os
d = json.load(open(os.path.expanduser('~/.claude/channels/imessage/style/preferences.json')))
print(d['bridgeToken'])
")
```

Token comparison uses a constant-time `safeEq()` function to prevent timing attacks.

---

## Endpoints

### `GET /v1/health`

Returns server status.

**Response** `200 OK`

```json
{
  "ok": true,
  "uptime": 4823,
  "port": 7842
}
```

---

### `GET /v1/pending`

Returns threads that have unreplied inbound messages within the look-back window.

**Query parameters**

| Name | Default | Description |
|---|---|---|
| `lookback_hours` | `2` | How many hours back to scan |
| `max` | `20` | Maximum threads returned |

**Response** `200 OK`

```json
{
  "threads": [
    {
      "chat_guid": "iMessage;-;+11234567890",
      "kind": "dm",
      "display_name": null,
      "participants": ["+11234567890"],
      "last_ts": "2026-04-24T15:32:00.000Z",
      "last_preview": "Hey, are you coming tonight?",
      "unreplied": true
    }
  ]
}
```

Only contacts on the **allowlist** (configured in `~/.claude/channels/imessage/style/preferences.json`) are returned.

---

### `GET /v1/draft`

Returns the thread context needed to generate reply drafts.

**Query parameters**

| Name | Required | Description |
|---|---|---|
| `chat_guid` | ✅ | The exact `chat_guid` from `/v1/pending` |

**Response** `200 OK`

```json
{
  "chat_guid": "iMessage;-;+11234567890",
  "kind": "dm",
  "participants": ["+11234567890"],
  "primary_contact": "+11234567890",
  "recent_thread": "Apr 24 3:30pm  +11234567890: Hey, are you coming tonight?\nApr 24 3:29pm  Me: Not sure yet\n...",
  "drafting_context": {
    "tone": "casual",
    "contact_style_notes": "Responds well to humor",
    "custom_instructions": null,
    "contact_custom_instructions": null,
    "global_style_profile": "concise, warm, not overly formal"
  }
}
```

> `recent_thread` is a pre-formatted multi-line string produced by the server's `renderConversation()`. It includes timestamps and speaker labels ready for inclusion in a Claude prompt.

The allowlist is enforced — requesting a `chat_guid` for a contact not on the allowlist returns `403`.

---

### `POST /v1/reply`

Sends a reply to a chat thread.

**Request body** (JSON)

```json
{
  "chat_guid": "iMessage;-;+11234567890",
  "text": "Yeah, I'll be there around 8!",
  "signature": "default"
}
```

| Field | Required | Description |
|---|---|---|
| `chat_guid` | ✅ | Target thread |
| `text` | ✅ | Message text to send |
| `signature` | ❌ | `"default"` (append configured signature), `"none"` (no signature), or a custom string to append |

**Response** `200 OK`

```json
{ "ok": true }
```

**Restrictions**:
- File attachments are blocked at the bridge layer
- Only allowlisted chat GUIDs are accepted (returns `403` otherwise)
- The send is routed through `performSend()` which enforces all existing MCP allowlist rules

---

## Security model

| Property | Details |
|---|---|
| Transport | HTTP only (no TLS in v1) |
| Authentication | Bearer token (constant-time comparison) |
| Scope | Localhost by default; configurable to LAN |
| Allowlist | Enforced on both `/v1/draft` and `/v1/reply` |
| Attachments | Blocked — text only |
| Prompt injection | Inbound message text is treated as untrusted; the menubar app surfaces it for review before drafting |

---

## curl examples

```bash
# --- Read token ---
TOKEN=$(python3 -c "import json,os; print(json.load(open(os.path.expanduser('~/.claude/channels/imessage/style/preferences.json')))['bridgeToken'])")

# --- Health ---
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:7842/v1/health | python3 -m json.tool

# --- Pending threads ---
curl -s -H "Authorization: Bearer $TOKEN" \
  "http://localhost:7842/v1/pending?lookback_hours=2" | python3 -m json.tool

# --- Draft context ---
GUID="iMessage;-;+11234567890"
curl -s -H "Authorization: Bearer $TOKEN" \
  "http://localhost:7842/v1/draft?chat_guid=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$GUID'))")" \
  | python3 -m json.tool

# --- Send reply ---
curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"chat_guid\":\"$GUID\",\"text\":\"Sounds good!\",\"signature\":\"default\"}" \
  http://localhost:7842/v1/reply | python3 -m json.tool
```
