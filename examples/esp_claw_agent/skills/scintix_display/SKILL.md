---
{
  "name": "scintix_display",
  "description": "Show a full-screen message on the Scintix P4 LCD, styled to match the agent's face screen.",
  "metadata": {
    "cap_groups": [
      "cap_lua"
    ],
    "manage_mode": "readonly"
  }
}
---

# Scintix P4 Display

Use this skill when the user asks to show, write, print, or display a message on the board's screen.

Run the script with `lua_run_script`, passing the message in `args.text`.
If `lua_run_script` returns an error, report that error directly to the user.

## Args Schema

```json
{
  "type": "object",
  "properties": {
    "text": {
      "type": "string",
      "default": "Hello from Scintix P4"
    },
    "font_size": {
      "type": "integer",
      "default": 24
    },
    "hold_ms": {
      "type": "integer",
      "default": 8000,
      "minimum": 0,
      "maximum": 30000
    }
  }
}
```

## Tool Call Inputs

Show a message:
```json
{"path":"{CUR_SKILL_DIR}/scripts/show_text.lua","args":{"text":"Hello from Claude"}}
```
