# Publication Readiness

This document captures the state of the `imessage` plugin with
respect to public distribution (e.g., a Claude Code marketplace). It is
the single source of truth for:

- what the channel contract looks like, and how it maps to the [Claude
  Code channel protocol](https://docs.anthropic.com/claude/docs/claude-code);
- what has been made portable so the repo can be cloned and used
  anywhere;
- what remains personal/local and must be configured or swapped before
  a third party publishes their own variant; and
- how to exercise the plugin under
  `--dangerously-load-development-channels` before cutting a release.

## Publication-readiness checklist

- [x] `.mcp.json` uses `${CLAUDE_PLUGIN_ROOT}` and PATH-resolved `bun`
  (no hardcoded Bun binary or repo path).
- [x] `package.json` name matches the plugin name (`imessage`)
  and declares author, repository, and license.
- [x] `plugin.json` carries author, homepage, repository, and license.
- [x] `marketplace.json` uses a real homepage URL (no `file://`
  absolute paths).
- [x] Wrapper scripts (`start-imessage-claude.sh`,
  `scripts/start-imessage-claude-service.sh`,
  `scripts/install-imessage-launch-agent.sh`) resolve `$REPO_ROOT`
  from their own location and accept `$CLAUDE_BIN` overrides.
- [x] LaunchAgent plist is a template with `__REPO_ROOT__`, `__HOME__`,
  `__LABEL__` placeholders; the installer substitutes them.
- [x] `.gitignore` excludes `node_modules/`, `state/`, `*.log`.
- [x] `ACCESS.md` skill-reference table is no longer split by
  intervening sections.
- [ ] Third-party publishers must still rename the marketplace
  (`gabriel-local-plugins`), plist label (`com.gabriel.imessage-claude`),
  and author/homepage fields.
- [ ] `claude` CLI currently rejects local-source channels without the
  `--dangerously-load-development-channels` flag. Shipping to a real
  marketplace will also require signing/registration that is outside
  this repository's scope.

## Channel contract verification

Claude Code expects channel plugins to speak MCP over stdio and declare
specific experimental capabilities. The server in
[`plugins/imessage/server.ts`](../plugins/imessage/server.ts)
satisfies all of them:

| Contract requirement | Implementation |
| --- | --- |
| `StdioServerTransport` | `await mcp.connect(new StdioServerTransport())` at boot |
| `capabilities.experimental["claude/channel"]` | declared in the `Server` constructor |
| `capabilities.experimental["claude/channel/permission"]` | declared alongside `claude/channel` |
| `capabilities.tools` | declared; eight tools registered |
| `notifications/claude/channel` | emitted per inbound message with `{content, meta:{chat_id, message_id, user, ts, image_path?}}` |
| `reply` tool | `{chat_id, text, files?}`, chunked, with attachment-path guard |
| Sender gating | self-handles bypass; otherwise `allowlist`/`pairing`/`disabled` + per-group rules |
| Permission relay | self-chat only; strict `(y\|yes\|n\|no) <5-char id>` regex |
| Instructions string | includes prompt-injection refusal guidance |

No changes to `server.ts` are required to publish; all publication work
is in metadata, wrappers, and docs.

## Local-vs-public configuration split

Everything shipped in the repository tree is intended to be portable.
Personal deployment knobs live outside the tree:

| Concern | Portable (committed) | Personal (not committed) |
| --- | --- | --- |
| Plugin code | `plugins/imessage/server.ts` and siblings | — |
| MCP launcher | `.mcp.json` with `${CLAUDE_PLUGIN_ROOT}` | — |
| Marketplace | `.claude-plugin/marketplace.json` (local dev name `gabriel-local-plugins`) | A third-party marketplace entry must supply its own name + owner |
| LaunchAgent | Template plist with placeholders | Substituted copy under `~/Library/LaunchAgents/` |
| Wrapper scripts | Derive paths from the script location | Honor `$CLAUDE_BIN`, `$IMESSAGE_LAUNCH_LABEL` overrides |
| Access state | — | `~/.claude/channels/imessage/access.json` |
| Style memory | — | `~/.claude/channels/imessage/style/` |
| Logs | — | `state/*.log` (gitignored) |

## Recommended test commands

Run these in order from a fresh checkout:

```sh
# 1. Static fail-check.
./scripts/preflight.sh

# 2. Full diagnostic (FDA, LaunchAgent, policy, watermark).
./scripts/doctor.sh

# 3. Interactive run, loads the development channel and prompts for
#    confirmation on first launch.
./scripts/run-imessage-claude.sh

# Equivalent manual form:
claude --dangerously-load-development-channels plugin:imessage@gabriel-local-plugins

# 4. Background service run (requires ./scripts/install-imessage-launch-agent.sh
#    first; the LaunchAgent answers the development-channel prompt via expect).
launchctl kickstart -k "gui/$(id -u)/com.gabriel.imessage-claude"
tail -f state/service.log
```

In the running session, validate the channel with:

- `/imessage:configure` — confirms FDA access, self-handle learning,
  and current policy.
- `/imessage:access` — prints the access state.
- Send an iMessage to yourself — should surface as a channel
  notification.
- Approve a proposed reply — should dispatch via `reply` and append to
  `approved-examples.jsonl`.

## Next steps before a public release

1. **Marketplace identity.** Rename `gabriel-local-plugins` to the
   publisher's marketplace, or migrate the plugin into an existing
   marketplace's `plugins/` list. Update `marketplace.json`, README
   install instructions, and any skill references.
2. **LaunchAgent label.** The default label
   `com.gabriel.imessage-claude` is personal. Override with
   `IMESSAGE_LAUNCH_LABEL=com.yourorg.imessage-claude
   ./scripts/install-imessage-launch-agent.sh` or patch the default.
3. **Remove the dev-channel gate.** Public distribution will not be
   able to assume `--dangerously-load-development-channels`. Follow the
   Claude Code channel publication process once it stabilizes.
4. **Provenance.** Decide how to ship dependencies — committed
   `node_modules/` (increases tarball but guarantees offline start),
   lockfile-only with `bun install` at first run (current default), or
   a pre-built single-file bundle.
5. **Threat-model review.** Re-audit `gate()`, `assertSendable`, and
   the permission-relay regex against the channel contract's security
   guarantees. The current implementation is conservative but not
   formally reviewed.
6. **Author/homepage sweep.** Replace `gabrielchiappa@outlook.com` and
   the GitHub URL with the publisher's details before release.
