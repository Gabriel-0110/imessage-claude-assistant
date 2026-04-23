#!/usr/bin/env bash
# Quick preflight before starting Claude Code with the local iMessage channel.
# Lightweight subset of doctor.sh focused on fail-fast blockers.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHAT_DB="${IMESSAGE_DB_PATH:-$HOME/Library/Messages/chat.db}"

fail() { echo "preflight: $*" >&2; exit 1; }

command -v bun >/dev/null 2>&1 || fail "bun not installed"
[[ -r "$CHAT_DB" ]] || fail "chat.db unreadable (grant Full Disk Access): $CHAT_DB"
[[ -f "$REPO_ROOT/plugins/imessage/server.ts" ]] || fail "plugin server.ts missing"
[[ -f "$REPO_ROOT/.claude-plugin/marketplace.json" ]] || fail "marketplace.json missing"

# Validate JSON files quickly
for f in \
  "$REPO_ROOT/.claude-plugin/marketplace.json" \
  "$REPO_ROOT/plugins/imessage/.mcp.json" \
  "$REPO_ROOT/plugins/imessage/.claude-plugin/plugin.json" \
  "$REPO_ROOT/plugins/imessage/package.json" \
; do
  bun -e "JSON.parse(require('fs').readFileSync('$f','utf8'))" >/dev/null 2>&1 \
    || fail "invalid JSON: $f"
done

echo "preflight: ok"
