# iMessage Claude Assistant

This project holds the local setup and behavior rules for using Claude Code with the official iMessage plugin on macOS.

## What it does
- Receives iMessages through the official Claude Code iMessage plugin
- Proposes 3 reply options
- Waits for approval, edits, or a brand-new draft
- Learns Gabriel's reply style over time

## Main files
- CLAUDE.md -> project rules for Claude
- ~/.claude/imessage-style-profile.md -> persistent style profile
- docs/setup.md -> setup notes
- scripts/run-imessage-claude.sh -> helper launcher

## Usage
Start Claude Code from this folder with the iMessage channel enabled:
claude --channels plugin:imessage@claude-plugins-official
