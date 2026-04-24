#!/usr/bin/env bash
# Wrapper to debug MCP server startup
LOG="/tmp/imessage-mcp-debug.log"
echo "[$(date)] MCP server starting (PID=$$, PPID=$PPID, USER=$USER)" >> "$LOG"
echo "[$(date)] PATH=$PATH" >> "$LOG"
echo "[$(date)] IMESSAGE_DB_PATH=${IMESSAGE_DB_PATH:-unset}" >> "$LOG"

exec /Users/gabrielchiappa/.bun/bin/bun \
  /Users/gabrielchiappa/Coding/imessage-claude-assistant/plugins/imessage/server.ts \
  2>> "$LOG"
