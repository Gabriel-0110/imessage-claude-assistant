# Review Existing Messages

Use the iMessage plugin tools to review existing message history on demand.

## Behavior

1. Ask me which contact or thread I want to review if I did not specify one.
2. Use chat_messages to fetch recent history for that thread.
3. Summarize the conversation briefly.
4. Identify the latest message that may need a reply.
5. Generate exactly 3 reply options:
   - Option 1: safest / neutral
   - Option 2: warm / natural
   - Option 3: shortest / efficient
6. Offer:
   - send 1
   - send 2
   - send 3
   - edit 1: ...
   - edit 2: ...
   - edit 3: ...
   - new: ...
   - ignore
7. Never send automatically.
8. Only send after my explicit approval.
9. After approval, update ~/.claude/imessage-style-profile.md based only on the final reply I approved or rewrote.
