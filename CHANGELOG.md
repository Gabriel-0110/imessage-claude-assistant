# Changelog

## Unreleased

### Changed

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

### Added

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
