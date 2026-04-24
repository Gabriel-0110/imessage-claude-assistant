# Changelog

## Unreleased

### Added

- **LAN bridge for the ReplyPilot iOS companion (Phase 6)** — when
  `preferences.bridgeEnabled` is `true`, the server spins up an HTTP
  listener on `0.0.0.0:7842` (override with `IMESSAGE_BRIDGE_PORT`)
  alongside the stdio MCP transport. Every request is gated by
  `Authorization: Bearer <bridgeToken>`; tokens auto-generate as
  32-byte hex and persist to `preferences.json` on first start. The
  service is advertised on the local network via Bonjour/mDNS using
  macOS `dns-sd` (`_replypilot._tcp.`). Endpoints: `GET /v1/health`,
  `GET /v1/pending`, `GET /v1/draft?chat_guid=…`, `POST /v1/reply`.
  Sends route through the same `performSend` path as the `reply` MCP
  tool (allowlist, chunking, signature resolution identical).
  Attachments are explicitly rejected in v1. The bridge does NOT
  auto-send drafts — an iOS client tapping "send" IS the operator
  approval event for that exact text. No TLS in v1 (LAN + token
  threat model); `bridgeToken` still lives in `preferences.json`
  with Keychain migration as a follow-up.
- `bridge_status` MCP tool — read-only report of the bridge state:
  `enabled_preference`, `running`, bound `port`, Bonjour subprocess
  liveness, `uptime_ms`, and the last 8 chars of the bearer token
  for out-of-band pairing verification.
- `schedule_reply` MCP tool — queue a drafted reply for re-presentation
  at a chosen ISO-8601 timestamp. Entries persist to
  `$STATE_DIR/scheduled.json`. The queue ONLY delays presentation; it
  does NOT pre-authorize sending. When an entry comes due the operator
  must still explicitly approve the exact text before `reply` is
  called. Gated by `preferences.schedulerEnabled` (default `false`).
- `list_scheduled` MCP tool — list queue entries. Filters: `status`
  (`pending`|`cancelled`|`presented`|`all`, default `pending`),
  `due_only` (only past-due pending entries), `chat_guid`. Each entry
  is annotated with a derived `due` flag and a reminder that
  scheduling does not pre-authorize sending.
- `cancel_scheduled` MCP tool — flip a queued entry to
  `status: cancelled`. The entry is retained for audit and no longer
  surfaces under the default `pending` filter.
- `memory_editor` MCP tool — read, append to, or replace the
  operator's style-memory files. `target: "global"` addresses the
  global iMessage style profile (honours `preferences.memoryPath`
  when set); `target: "contact"` addresses `style/contacts/<handle>.md`.
  Writes are gated by `preferences.styleLearningEnabled` (default
  on); reads always work.

### Changed

- `preferences.bridgeEnabled` / `preferences.bridgeToken` are now
  wired to the runtime. `bridgeEnabled` toggles the Phase 6 LAN
  server + Bonjour advertisement; `bridgeToken` is the shared secret.
  If the operator flips `bridgeEnabled` to `true` without setting a
  token, one is auto-generated and written back. Disabling requires
  a server restart to tear down the listener.
- Extracted `performSend` from the `reply` tool so the LAN bridge and
  MCP surface share one code path for allowlist, attachment, chunking,
  and signature resolution. No behaviour change for existing callers.
- Extracted `buildDraftReplyContext` from the `draft_reply` tool for
  the same reason. No behaviour change for existing callers.
- `preferences.memoryPath` is now wired: when set, it overrides the
  default `~/.claude/imessage-style-profile.md` path for both
  `style_profile` / `draft_reply` reads and `memory_editor`
  global-target writes. Validation (must live under `$HOME`)
  unchanged.
- `preferences.schedulerEnabled` is now wired to gate
  `schedule_reply`. Other scheduling tools (`list_scheduled`,
  `cancel_scheduled`) remain callable regardless, so operators can
  inspect or cancel queued entries even after disabling scheduling.
- `list_contacts` now calls `loadAccess()` (was `readAccess()`, which
  did not exist — runtime crash on first call, missed by smoke import
  since the reference lived inside a tool-case closure).

### Previously (v0.7.0)

#### Changed (v0.7.0)

- SMS/RCS inbound gate now consults `preferences.allowSms` before
  falling back to the `IMESSAGE_ALLOW_SMS` env default. Explicit
  `allowSms: true` or `false` overrides the env value, so operators
  can flip SMS acceptance without restarting the server. Default
  remains iMessage-only (spoofable sender IDs).
- Inbound notifications now honour `preferences.pauseUntil` (global)
  and `preferences.pausedChats[chat_guid]` (per-thread). When either
  timestamp is in the future, `handleInbound` silently drops the
  notification — the message is still persisted by Messages.app and
  available via `chat_messages` / `recent_chats`.
- Inbound content is tagged with a `[nsfw]` prefix when
  `preferences.nsfwFilter === 'tag'` and the text matches a
  conservative keyword heuristic. Message is still delivered; the tag
  is purely a warning banner for the drafting surface.
- `handleInbound` now gates inbound-image exposure behind
  `preferences.visionEnabled`. When the operator has not opted in
  (default), the `image_path` attribute is stripped from the
  notification meta and the content body carries a short marker
  (`"(image attached — vision disabled in preferences)"`) instead of
  the raw path. With `visionEnabled: true`, behaviour matches prior
  releases: the first image attachment's absolute path is surfaced so
  Claude can `Read` it. A size cap (`IMESSAGE_MAX_VISION_BYTES`,
  default 10 MiB) drops oversized files into the same "withheld"
  code path rather than handing multi-megabyte reads to the model.
- Server instructions now tell Claude that `image_path` is only
  present when `visionEnabled` is true, and that its absence is
  intentional.
- Plugin renamed from `imessage-local` to `imessage`. Slash commands
  are now namespaced as `/imessage:access`, `/imessage:configure`,
  `/imessage:review` (the previous `imessage-local` name had produced
  `/imessage-local:access`, which did not match the documentation).
  Directory moved from `plugins/imessage-local/` to `plugins/imessage/`;
  `name` fields in `plugin.json`, `package.json`, and
  `.claude-plugin/marketplace.json` updated accordingly.
- `settings.json` consumers must update
  `enabledPlugins["imessage-local@…"]` → `enabledPlugins["imessage@…"]`
  and `allowedChannelPlugins[].plugin` → `"imessage"`.
- `record_approved_reply` now honours
  `preferences.styleLearningEnabled`. When set to `false`, approved
  replies are not appended to the JSONL log and contact notes are not
  written; the tool returns a short "learning disabled" message.
  Default (unset) remains learn-on.
- `style_profile` output now leads with a dedicated "drafting context"
  block that names the effective tone, the global custom
  instructions, and any contact-specific custom instructions, so
  drafting calls don't need a separate `edit_preferences get`.

#### Added (v0.7.0)

- `pause` MCP tool — suppress inbound channel notifications globally or
  for a single `chat_guid` for a chosen number of minutes (default 60).
  Messages still land in `chat.db` and are reachable through the read
  tools; only the drafting surface is quieted. Auto-resumes at the
  computed timestamp.
- `resume` MCP tool — clear a `pause`, either globally (clears
  `pauseUntil`) or for a specific `chat_guid` (clears that entry from
  `pausedChats`).
- `list_contacts` MCP tool — read-only audit of the access-control
  state: DM policy, allowlisted handles, self-chat handles, and
  configured groups with their `requireMention` / `allowFrom`
  policies. Supports `format: "json"`.
- Inbound vision gate controlled by `preferences.visionEnabled`
  (default `false`). When enabled, inbound image attachments are
  surfaced to Claude via `image_path` just as before; when disabled,
  the path is withheld and only the existence of the image is
  announced in the content body. New env var
  `IMESSAGE_MAX_VISION_BYTES` (default 10 MiB) caps the file size
  allowed through the gate; oversized images fall into the same
  "withheld" path with a distinct marker.
- `draft_reply(chat_guid)` MCP tool — single call that assembles all
  drafting context for a chat: recent rendered thread, tone, custom
  instructions (global + per-contact), contact style notes, global
  style profile, a handful of recent approved examples, participants,
  unread state, activity counts, and the resolved signature default
  (per-contact override honoured). Read-only; does not send.
- Inbound denylist gate: `preferences.denyFrom` (populated via
  `/imessage:settings deny add|remove` or `edit_preferences`) now
  silently drops messages from listed handles before the access-control
  policy runs. Self-chat still bypasses. Denied senders never see a
  pairing code or any reply.

- `edit_preferences` MCP tool and `/imessage:settings` skill for
  managing operator personalization in
  `~/.claude/channels/imessage/style/preferences.json` without
  hand-editing JSON. The `Preferences` schema gained reserved
  storage-only fields for upcoming phases (`customInstructions`,
  `customInstructionsPerContact`, `styleLearningEnabled`,
  `visionEnabled`, `nsfwFilter`, `focusMode`, `denyFrom`,
  `memoryPath`, `schedulerEnabled`, `bridgeEnabled`) — these are
  validated and persisted today but have no runtime effect until the
  matching phase lands. Unknown keys and invalid enum values are
  rejected with a readable error. `memoryPath` is required to live
  under `$HOME`.
- `reply` MCP tool accepts an optional `signature` argument for
  per-send control of the trailing `Sent by Claude` (or custom)
  suffix: omit or `"default"` uses the server default; `"none"`
  strips it; any other string replaces it for that send only.
  `IMESSAGE_APPEND_SIGNATURE` remains the default.
- Reply workflow (`CLAUDE.md` + `skills/review`) now asks the operator
  to pick `signature keep | signature: <text> | signature remove`
  alongside the three reply options, and Claude passes the chosen
  value through to `reply`.

## 0.3.0

Publication-readiness pass. No runtime behavior changes — all edits
target portability, metadata, and documentation. The channel contract
implementation in `server.ts` is unchanged.

### Added

- `docs/PUBLICATION.md` covering channel-contract coverage, the
  publication-readiness checklist, the portable-vs-personal config
  split, recommended test commands (including
  `--dangerously-load-development-channels`), and remaining pre-release
  tasks.
- Placeholder-templated LaunchAgent plist; `install-imessage-launch-agent.sh`
  now substitutes `__REPO_ROOT__`, `__HOME__`, and `__LABEL__` at
  install time.
- `package.json` `setup` script for explicit `bun install` separate
  from the start path.
- `plugin.json` now declares author, license, homepage, and repository.
- `node_modules/` and `*.log` entries in `.gitignore`.

### Changed

- `plugins/imessage-local/.mcp.json` now uses a PATH-resolved `bun`
  command and `${CLAUDE_PLUGIN_ROOT}` for the plugin directory; no more
  hardcoded personal paths.
- `plugins/imessage-local/package.json` renamed from
  `claude-channel-imessage` to `imessage-local` (matches the plugin
  name) and carries author + repository metadata. The `start` script
  falls back gracefully when `bun install --frozen-lockfile` cannot be
  satisfied, then `exec`s the server.
- Top-level `start-imessage-claude.sh`,
  `scripts/start-imessage-claude-service.sh`, and
  `scripts/install-imessage-launch-agent.sh` derive `$REPO_ROOT` from
  their own location and honor `$CLAUDE_BIN` /
  `$IMESSAGE_LAUNCH_LABEL` overrides.
- `.claude-plugin/marketplace.json` replaced the personal `file://`
  homepage with a real repository URL and added keywords.
- `plugins/imessage-local/ACCESS.md` skill-reference table is no
  longer split across intervening sections.
- README sections 7.2 / 8.1 / 9.1 reflect the portable launcher and
  drop the "hardcoded personal path" caveat.

### Preserved

- Entire channel contract: stdio transport, both `claude/channel`
  experimental capabilities, notification shape, every tool contract,
  sender gating, self-chat bypass, permission relay, echo filtering,
  static-mode, attachment-path guard.
- Access state file format and location.
- Style-learning files and format.

## 0.2.0

### Added

- MCP tools: `recent_chats`, `pending_replies`, `thread_summary`,
  `style_profile`, `record_approved_reply`, `health_check`.
- Skill `/imessage:review` for on-demand conversation review with the
  three-option drafting workflow.
- Per-contact style notes under
  `~/.claude/channels/imessage/style/contacts/<handle>.md`.
- Append-only approved-reply log at
  `~/.claude/channels/imessage/style/approved-examples.jsonl`.
- Optional explicit preferences at
  `~/.claude/channels/imessage/style/preferences.json`.
- Structured logging: `IMESSAGE_LOG_JSON`, `IMESSAGE_LOG_LEVEL`.
- Startup diagnostic event with DB path, self handle count, policy flags.
- `scripts/doctor.sh` full diagnostic.
- `scripts/preflight.sh` fast fail-check, invoked by the run script.
- `docs/FEATURES.md` and `docs/ARCHITECTURE.md` (with Mermaid diagrams).

### Changed

- `run-imessage-claude.sh` now runs preflight before launching Claude Code
  and uses `$REPO_ROOT` rather than a hard-coded path.
- Server instructions updated to point Claude at the new overview/summary
  tools and the style-profile workflow.

### Preserved

- Existing tool contracts (`reply`, `chat_messages`) unchanged.
- Access gate behavior (allowlist / pairing / disabled) unchanged.
- Self-chat bypass, echo filtering, permission relay unchanged.
- `.mcp.json` / marketplace / plugin metadata structure unchanged (only
  version bumps).
