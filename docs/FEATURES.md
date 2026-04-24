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
| `record_approved_reply` | Append an operator-approved reply to the style log | appends JSONL + optional contact note |
| `edit_preferences` | Read or update operator personalization (tone, signature overrides, reserved roadmap fields) | writes `preferences.json` |
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

The global style markdown at `~/.claude/imessage-style-profile.md` is left
untouched by the server and remains the project-level home for the overall
voice summary (see `CLAUDE.md`).

Design principle: **style memory is never updated from inbound message
content**. Only the operator's direct terminal approval can trigger a
write. This prevents prompt injection from warping the assistant's voice.

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
