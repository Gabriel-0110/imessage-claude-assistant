# Features

This document lists every capability the local iMessage Claude assistant
exposes, grouped by surface area. For the reasoning behind each design
choice, see [ARCHITECTURE.md](ARCHITECTURE.md).

## Tools exposed over MCP

| Tool | Purpose | Writes state? |
| --- | --- | --- |
| `reply` | Send text (and optional file attachments) to an allowlisted chat | sends via Messages.app |
| `chat_messages` | Read full recent history for allowlisted chats | no |
| `recent_chats` | Per-thread activity overview within a lookback window | no |
| `pending_replies` | Threads whose last message is inbound and unanswered | no |
| `thread_summary` | Single-thread stats + rendered messages + contact style notes | no |
| `style_profile` | Global + per-contact style, preferences, approved examples | no |
| `draft_reply` | One-call drafting context for a chat: thread + tone + custom instructions + examples + signature default | no |
| `pause` | Suppress inbound drafting notifications globally or for a single chat for N minutes (default 60) | writes `preferences.json` (`pauseUntil` or `pausedChats`) |
| `resume` | Clear a global or per-chat pause set by `pause` | writes `preferences.json` |
| `list_contacts` | Read-only audit of DM policy, allowlist, self handles, and group policies | no |
| `record_approved_reply` | Append an operator-approved reply to the style log (respects `styleLearningEnabled`) | appends JSONL + optional contact note |
| `edit_preferences` | Read or update operator personalization (tone, signature overrides, denylist, roadmap fields) | writes `preferences.json` |
| `schedule_reply` | Queue a drafted reply for later re-presentation. Only delays presentation — does not pre-authorize sending. Gated by `schedulerEnabled`. | writes `scheduled.json` |
| `list_scheduled` | List queue entries (`status`, `due_only`, `chat_guid` filters). Annotates entries with a derived `due` flag. | no |
| `cancel_scheduled` | Flip a queued entry to `status: cancelled` (retained for audit) | writes `scheduled.json` |
| `memory_editor` | Read / append / replace global style profile or per-contact style notes. Writes gated by `styleLearningEnabled`; global target honours `memoryPath`. | writes style markdown files |
| `bridge_status` | Read-only report of the Phase 6 LAN bridge (`enabled_preference`, `running`, bound `port`, Bonjour liveness, `uptime_ms`, token fingerprint) | no |
| `health_check` | Self-diagnostic: DB, state dir, policy, watermark, etc. | no |

All read tools are scoped to **allowlisted chats only** — messages from
non-allowlisted senders still reach `chat.db`, but tool outputs never
include them. `record_approved_reply` is the only tool that writes
personalization state, and it is intended to be called **only after** the
operator has explicitly approved the exact final text in a terminal
session.

## Skills

| Skill | Invocation | What it does |
| --- | --- | --- |
| `access` | `/imessage:access …` | Pair, allow, remove, set policy, configure groups |
| `configure` | `/imessage:configure` | Print FDA / access-policy status and orient the user |
| `review` (new) | `/imessage:review …` | On-demand review of existing threads with draft-3-options workflow |
| `settings` | `/imessage:settings …` | Inspect and update operator personalization (tone, custom instructions, deny list, roadmap toggles) |

`/imessage:review` is the primary entry point for catching up: `review`
(overview), `review pending` (only unanswered), `review <contact>`,
`review <chat_id>`, and `review recent 24` all work.

## Operator scripts

| Script | Purpose |
| --- | --- |
| `scripts/preflight.sh` | Fast fail-check: bun present, chat.db readable, JSON valid |
| `scripts/doctor.sh` | Full diagnostic report (environment, files, FDA, launchd, access state) |
| `scripts/run-imessage-claude.sh` | Preflight + launch Claude Code with the plugin |
| `scripts/start-imessage-claude-service.sh` | Launchd wrapper |
| `scripts/install-imessage-launch-agent.sh` | Install/replace the LaunchAgent plist |

## Personalization / style learning

Local-only state under `~/.claude/channels/imessage/style/`:

- `approved-examples.jsonl` — append-only log of replies the operator
  approved, with the proposed options, which one (if any) they picked, and
  a short reason note. Written by `record_approved_reply`.
- `contacts/<handle>.md` — free-form per-contact style notes. Appended by
  `record_approved_reply` when a note is supplied.
- `preferences.json` — explicit operator preferences (default tone, signature
  overrides per contact, arbitrary notes, plus reserved fields for upcoming
  phases). Manage via `/imessage:settings` / the `edit_preferences` MCP tool,
  or hand-edit — the server re-reads the file on every tool call.
  - `denyFrom` is active: listed handles are silently dropped on inbound
    before the allowlist gate runs.
  - `styleLearningEnabled: false` disables `record_approved_reply` writes
    (JSONL + contact notes). Default is learn-on.
  - `defaultTone` and `customInstructions` (global + per-contact) are
    surfaced by `style_profile` and `draft_reply` so Claude can respect
    them when composing options.
  - `visionEnabled` (default `false`) controls whether inbound image
    attachments are exposed to Claude. When `true`, `handleInbound`
    attaches an `image_path` to the channel notification so the model
    can `Read` the file. When `false`, the path is withheld and the
    content body carries a neutral marker. `IMESSAGE_MAX_VISION_BYTES`
    (env var, default 10 MiB) caps the file size allowed through the
    gate; larger files fall into the withheld path.
  - `allowSms` (optional boolean) overrides the `IMESSAGE_ALLOW_SMS`
    env default at runtime. Set to `true` to accept SMS/RCS inbound
    without restarting, or `false` to harden back to iMessage-only.
    Unset falls back to the env var (default `false`).
  - `pauseUntil` (ISO-8601 timestamp) silently drops all inbound
    drafting notifications until the timestamp passes. Messages still
    land in `chat.db` and are reachable through the read tools. Set
    via the `pause` tool; clear via `resume`.
  - `pausedChats` (`{chat_guid: iso_timestamp}`) same pause semantics,
    scoped to a single thread. Managed by `pause` / `resume`.
  - `nsfwFilter: 'tag'` prefixes inbound content with a `[nsfw]`
    banner when a conservative keyword heuristic matches. Message is
    still delivered; the tag is a warning for the drafting surface.
  - `memoryPath` (optional absolute path under `$HOME`) overrides the
    default `~/.claude/imessage-style-profile.md` location used by
    `style_profile`, `draft_reply`, and `memory_editor` for the global
    style file. Contact notes are unaffected and remain under the
    channel state dir.
  - `schedulerEnabled` (default `false`) gates the `schedule_reply`
    tool. `list_scheduled` / `cancel_scheduled` remain callable when
    scheduling is disabled so operators can inspect or drop any
    previously queued entries. Queued entries still require explicit
    operator approval of the exact text at re-presentation time — the
    scheduler only delays presentation, it does not pre-authorize
    sending.
  - `bridgeEnabled` (default `false`) gates the Phase 6 LAN bridge for
    the ReplyPilot iOS companion. Requires a restart to take effect —
    the listener and Bonjour advertisement are brought up at startup
    only.
  - `bridgeToken` (optional string, ≥32 chars) is the Bearer secret
    for bridge requests. When `bridgeEnabled` becomes `true` and this
    field is unset, the server generates a 32-byte hex token and
    writes it back to `preferences.json` (follow-up: migrate to
    Keychain). Rotating the token requires a restart.

In addition, `~/.claude/channels/imessage/scheduled.json` stores queued
`schedule_reply` entries. Each entry carries `id`, `chat_guid`, `text`,
optional `files` / `signature` / `note`, `scheduled_for`, `created_at`,
and `status` (`pending` | `cancelled` | `presented`).

The global style markdown at `~/.claude/imessage-style-profile.md` is left
untouched by the server and remains the project-level home for the overall
voice summary (see `CLAUDE.md`).

Design principle: **style memory is never updated from inbound message
content**. Only the operator's direct terminal approval can trigger a
write. This prevents prompt injection from warping the assistant's voice.

## LAN bridge (ReplyPilot iOS companion, Phase 6)

When `preferences.bridgeEnabled` is `true`, the server runs a small HTTP
listener alongside the stdio MCP transport so a paired client (planned:
an iOS app on the same Wi-Fi) can surface pending threads and send
approved replies.

- **Bind**: `0.0.0.0:7842`. Override the port with `IMESSAGE_BRIDGE_PORT`.
- **Auth**: `Authorization: Bearer <bridgeToken>` on every request;
  constant-time compared. Auto-generated on first start if unset.
- **Discovery**: Bonjour/mDNS `_replypilot._tcp.` advertised via macOS
  `dns-sd` (spawned as a child process so there is no new runtime
  dependency).
- **Endpoints**:
  - `GET /v1/health` — service liveness, bound port, uptime.
  - `GET /v1/pending?lookback_hours=48&max=20` — overview of unanswered
    allowlisted threads (same shape as `pending_replies`). Caps:
    `lookback_hours ≤ 720`, `max ≤ 100`.
  - `GET /v1/draft?chat_guid=…` — same drafting context as the
    `draft_reply` MCP tool (recent thread, tone, custom instructions,
    approved examples, signature defaults). Chat must be allowlisted.
  - `POST /v1/reply` — JSON body `{chat_guid, text, signature?}`.
    Goes through the shared `performSend` path (same allowlist,
    chunking, signature resolution as the MCP `reply` tool).
    Attachments are rejected in v1.
- **Invariant**: the bridge does **not** auto-send drafts. The client
  tapping "send" is the operator's approval event for the exact text
  being posted. Scheduling, auto-reply, and draft-return-without-send
  are all still enforced server-side the same way.
- **Threat model (v1)**: LAN-scoped + bearer token. No TLS, no mTLS.
  Tokens live in `preferences.json` for now; Keychain migration is a
  planned follow-up. Rotate the token by editing `preferences.json`
  and restarting.
- **Inspection**: call the `bridge_status` MCP tool for runtime state
  (enabled preference, whether the listener is up, bound port,
  Bonjour subprocess liveness, uptime, and the last 8 chars of the
  token for out-of-band pairing verification).

## Observability

- `IMESSAGE_LOG_JSON=true` switches stderr to machine-parseable JSON lines.
- `IMESSAGE_LOG_LEVEL=debug|info|warn|error` (default `info`).
- Startup logs include `self_handles`, `static`, `allow_sms`,
  `append_signature`, watermark, chat.db path, state dir.
- `health_check` tool produces the same status any time while running.

## Environment variables

| Var | Default | Effect |
| --- | --- | --- |
| `IMESSAGE_DB_PATH` | `~/Library/Messages/chat.db` | Override DB path (for testing) |
| `IMESSAGE_STATE_DIR` | `~/.claude/channels/imessage` | Where access.json + style/ live |
| `IMESSAGE_ACCESS_MODE` | unset | Set to `static` to freeze access.json at boot |
| `IMESSAGE_APPEND_SIGNATURE` | `true` | Append `Sent by Claude` signature (set `false` to disable) |
| `IMESSAGE_ALLOW_SMS` | `false` | Accept SMS/RCS inbound (default iMessage-only; SMS sender IDs are spoofable) |
| `IMESSAGE_MAX_VISION_BYTES` | `10485760` | Max inbound image size (bytes) that can pass the `visionEnabled` gate |
| `IMESSAGE_LOG_JSON` | `false` | JSON-structured stderr |
| `IMESSAGE_LOG_LEVEL` | `info` | Minimum level to emit |

## Safety guarantees

- **Allowlisted-only read scope.** Tools never surface non-allowlisted
  chats.
- **Explicit send path.** `reply` will not accept a path under the server's
  own state dir as an attachment (guards against channel-state exfil).
- **Permission relay is owner-only.** Permission prompts only go to
  self-chat; replies accepting them are only honoured from self-chat.
- **Policy `disabled`** is the one footgun: delivers every DM without
  approval. `health_check` warns and `/imessage:configure` requires
  explicit acknowledgement before recommending it.
- **Style memory writes are operator-gated.** `record_approved_reply` is
  documented as only callable after in-session user approval of the exact
  final text.
