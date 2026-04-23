#!/usr/bin/env bash
#
# Convenience launcher. Prefer scripts/run-imessage-claude.sh, which adds
# preflight validation. This wrapper exists for dock/finder shortcuts.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude || true)}"
if [[ -z "${CLAUDE_BIN}" ]]; then
  echo "error: 'claude' not found on PATH; set CLAUDE_BIN or install Claude Code." >&2
  exit 1
fi

exec "$CLAUDE_BIN" --dangerously-load-development-channels plugin:imessage@gabriel-local-plugins
