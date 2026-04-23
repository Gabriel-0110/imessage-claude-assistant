#!/usr/bin/env bash
#
# Install (or refresh) the per-user LaunchAgent that runs the iMessage
# Claude service at login.
#
# The plist under macos/ is a template with placeholders (__REPO_ROOT__,
# __HOME__). This script substitutes them to the current user's paths at
# install time so nothing personal needs to be committed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

LABEL="${IMESSAGE_LAUNCH_LABEL:-com.gabriel.imessage-claude}"
PLIST_SOURCE="$REPO_ROOT/macos/com.gabriel.imessage-claude.plist"
PLIST_TARGET="$HOME/Library/LaunchAgents/$LABEL.plist"
STATE_DIR="$REPO_ROOT/state"

if [[ ! -f "$PLIST_SOURCE" ]]; then
  echo "error: plist template not found at $PLIST_SOURCE" >&2
  exit 1
fi

mkdir -p "$STATE_DIR"
mkdir -p "$HOME/Library/LaunchAgents"

# Substitute placeholders into the installed plist.
sed \
  -e "s|__REPO_ROOT__|$REPO_ROOT|g" \
  -e "s|__HOME__|$HOME|g" \
  -e "s|__LABEL__|$LABEL|g" \
  "$PLIST_SOURCE" > "$PLIST_TARGET"

launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_TARGET"
launchctl kickstart -k "gui/$(id -u)/$LABEL"

echo "Installed and started $LABEL"
echo "Plist: $PLIST_TARGET"
echo "Logs:"
echo "  $STATE_DIR/launchd.out.log"
echo "  $STATE_DIR/launchd.err.log"
