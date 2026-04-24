#!/usr/bin/env bash
#
# LaunchAgent entrypoint. Runs Claude Code with the iMessage local channel
# under a pseudo-TTY so that the development-channel confirmation prompt can
# be answered automatically.
#
# Paths are derived from the script location so the file is safe to commit
# and works for any installation location.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Respect existing PATH; only prepend common locations that LaunchAgents miss.
export PATH="${PATH:+$PATH:}/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.local/bin:$HOME/.bun/bin"

cd "$REPO_ROOT"
mkdir -p "$REPO_ROOT/state"

CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude || true)}"
if [[ -z "${CLAUDE_BIN}" ]]; then
  echo "error: 'claude' not found on PATH; set CLAUDE_BIN." >&2
  exit 1
fi

LOG_FILE="$REPO_ROOT/state/service.log"

# Local channel plugins require --dangerously-load-development-channels and a
# TTY-backed confirmation. expect(1) provides the pseudo-TTY and answers.
exec /usr/bin/expect <<EOF >> "$LOG_FILE" 2>&1
log_user 1
set timeout -1
spawn $CLAUDE_BIN --debug mcp --debug-file $REPO_ROOT/state/claude-debug.log --dangerously-load-development-channels plugin:imessage@gabriel-local-plugins
expect {
  -regexp {Enter.*confirm} {
    send "1\r"
    exp_continue
  }
  -regexp {Listening for channel messages from:} {}
}
expect eof
EOF
