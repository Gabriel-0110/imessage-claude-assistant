#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Fail fast on setup problems (FDA, missing files, invalid JSON).
"$REPO_ROOT/scripts/preflight.sh"

exec claude --dangerously-load-development-channels plugin:imessage@gabriel-local-plugins
