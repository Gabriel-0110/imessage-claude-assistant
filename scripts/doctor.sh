#!/usr/bin/env bash
# Diagnostics for the local iMessage Claude assistant.
# Prints a one-screen health summary without requiring Claude Code to be running.
# Exits non-zero if a fatal issue is detected (FDA missing, chat.db unreadable).

set -uo pipefail

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; }
warn() { printf "  \033[33m!\033[0m %s\n" "$*"; }
bad()  { printf "  \033[31m✗\033[0m %s\n" "$*"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_DIR="$REPO_ROOT/plugins/imessage"
STATE_DIR="${IMESSAGE_STATE_DIR:-$HOME/.claude/channels/imessage}"
ACCESS_FILE="$STATE_DIR/access.json"
CHAT_DB="${IMESSAGE_DB_PATH:-$HOME/Library/Messages/chat.db}"

fatal=0

bold "== iMessage Claude — doctor =="

bold "Environment"
if command -v bun >/dev/null 2>&1; then
  ok "bun: $(bun --version) ($(command -v bun))"
else
  bad "bun not found on PATH — install from https://bun.sh"
  fatal=1
fi

if command -v claude >/dev/null 2>&1; then
  ok "claude: $(command -v claude)"
else
  warn "claude CLI not on PATH — install Claude Code if you plan to use this interactively"
fi

bold "Files"
for f in \
  "$PLUGIN_DIR/server.ts" \
  "$PLUGIN_DIR/package.json" \
  "$PLUGIN_DIR/.mcp.json" \
  "$PLUGIN_DIR/.claude-plugin/plugin.json" \
  "$REPO_ROOT/.claude-plugin/marketplace.json" \
  ; do
  if [[ -f "$f" ]]; then ok "found: ${f#$REPO_ROOT/}"
  else bad "missing: ${f#$REPO_ROOT/}"; fatal=1; fi
done

bold "JSON validity"
for f in \
  "$PLUGIN_DIR/package.json" \
  "$PLUGIN_DIR/.mcp.json" \
  "$PLUGIN_DIR/.claude-plugin/plugin.json" \
  "$REPO_ROOT/.claude-plugin/marketplace.json" \
  ; do
  if [[ -f "$f" ]]; then
    if command -v bun >/dev/null 2>&1 && bun -e "JSON.parse(require('fs').readFileSync('$f','utf8'))" >/dev/null 2>&1; then
      ok "valid json: ${f#$REPO_ROOT/}"
    elif python3 -c "import json,sys; json.load(open('$f'))" >/dev/null 2>&1; then
      ok "valid json: ${f#$REPO_ROOT/}"
    else
      bad "invalid json: ${f#$REPO_ROOT/}"
      fatal=1
    fi
  fi
done

bold "Full Disk Access / chat.db"
if [[ -r "$CHAT_DB" ]]; then
  ok "chat.db readable ($CHAT_DB)"
else
  bad "chat.db unreadable — grant Full Disk Access to your terminal: System Settings → Privacy & Security → Full Disk Access"
  bad "path: $CHAT_DB"
  fatal=1
fi

bold "State"
if [[ -d "$STATE_DIR" ]]; then ok "state dir: $STATE_DIR"
else warn "state dir missing (will be created on first run): $STATE_DIR"; fi

if [[ -f "$ACCESS_FILE" ]]; then
  ok "access.json present"
  if command -v bun >/dev/null 2>&1; then
    bun -e "
      const a = JSON.parse(require('fs').readFileSync('$ACCESS_FILE','utf8'));
      const s = k => a[k] ?? null;
      console.log('    policy:', s('dmPolicy'));
      console.log('    allowFrom:', (a.allowFrom||[]).length);
      console.log('    pending:', Object.keys(a.pending||{}).length);
      console.log('    groups:', Object.keys(a.groups||{}).length);
      if (s('dmPolicy') === 'disabled') console.warn('    WARNING: disabled policy delivers ALL DMs without approval.');
    " 2>/dev/null || warn "could not parse access.json"
  fi
else
  warn "access.json missing (default allowlist policy will apply)"
fi

bold "Launch agent"
PLIST="$HOME/Library/LaunchAgents/com.gabriel.imessage-claude.plist"
if [[ -f "$PLIST" ]]; then
  ok "installed: $PLIST"
  if launchctl print "gui/$(id -u)/com.gabriel.imessage-claude" >/dev/null 2>&1; then
    ok "loaded in launchd"
  else
    warn "plist exists but not loaded — run: launchctl bootstrap gui/\$(id -u) '$PLIST'"
  fi
else
  warn "launch agent not installed (optional) — see scripts/install-imessage-launch-agent.sh"
fi

echo
if [[ "$fatal" -ne 0 ]]; then
  bold "Result: ✗ fatal issues detected"
  exit 1
fi
bold "Result: ✓ ready"
