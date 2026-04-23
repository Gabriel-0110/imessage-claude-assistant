# Changelog

## Unreleased

### Changed

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

### Added

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
