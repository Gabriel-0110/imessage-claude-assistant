# Setup notes

## Official install
Inside Claude Code:
    /plugin install imessage@claude-plugins-official

Then restart Claude Code with:
    claude --channels plugin:imessage@claude-plugins-official

## Permission requirements
The iMessage plugin reads the local Messages database (chat.db), so the terminal app that launches Claude Code needs Full Disk Access.

The first outbound reply may also trigger an Automation permission prompt so the terminal app can control Messages.

## Testing
1. Start Claude with the iMessage channel enabled.
2. Text yourself from your iPhone.
3. Confirm the message appears in Claude.
4. Ask Claude to draft 3 reply options.
5. Approve, edit, or replace the reply before sending.

## Access control
The official plugin defaults to self-chat first. Other senders need to be explicitly allowed.
