# Setup notes

## Local install

Inside Claude Code:

    /plugin install imessage@gabriel-local-plugins

Then restart Claude Code with:

    claude --dangerously-load-development-channels plugin:imessage@gabriel-local-plugins

Because this is a local fork rather than an approved marketplace channel, `--channels`
alone will fail with an allowlist warning. When prompted, choose:

    1. I am using this for local development

## Permission requirements

The iMessage plugin reads the local Messages database (chat.db), so the terminal
app that launches Claude Code needs Full Disk Access.

The first outbound reply may also trigger an Automation permission prompt so the
terminal app can control Messages.

## Testing

1. Start Claude with the iMessage channel enabled.
2. Text yourself from your iPhone.
3. Confirm the message appears in Claude.
4. Ask Claude to draft 3 reply options.
5. Approve, edit, or replace the reply before sending.

## Access control

This local plugin supports self-chat, allowlists, pairing, and a custom `disabled`
mode that delivers all DMs without approval or pairing.

## Diagnostics

Run a full environment check any time:

```sh
./scripts/doctor.sh
```

Or a fast preflight (invoked automatically by `run-imessage-claude.sh`):

```sh
./scripts/preflight.sh
```

Inside a running Claude session, call the `health_check` MCP tool for a
live status report.

## On-demand review

Once running, review existing threads without waiting for new messages:

```text
/imessage:review                    # overview + pending-reply list
/imessage:review pending            # only unanswered threads
/imessage:review recent 24          # recent_chats with 24h window
/imessage:review +15551234567       # drill into a specific contact
```
