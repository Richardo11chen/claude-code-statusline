---
name: setup-statusline
description: Setup or uninstall the CJK-safe status bar. Copies the script to ~/.claude/ and configures settings.json.
---

# Setup StatusLine

This skill manages the CJK-Safe StatusLine plugin for Windows. Supports setup and uninstall.

## Usage

- `/setup-statusline` or "setup statusline" — first-time setup
- `/setup-statusline uninstall` or "卸载状态栏" — remove everything

## Operation: Setup (default)

### Step 0: Check if already configured

Check if `~/.claude/statusline.ps1` exists AND `~/.claude/settings.json` contains `"statusLine"` with a command referencing `statusline.ps1`.

If already fully configured, tell the user: "状态栏已配置，无需重复安装。如需卸载请说 uninstall。" Stop here.

If the script exists but config is missing, proceed to Step 1 and repair.

### Step 1: Copy the script

Copy the bundled PowerShell script to `~/.claude/`:

```powershell
Copy-Item -Path "<plugin_root>/scripts/statusline.ps1" -Destination "$HOME/.claude/statusline.ps1" -Force
```

`<plugin_root>` is the plugin directory containing `.claude-plugin/plugin.json`. On the user's machine it's at `$HOME/.claude/plugins/claude-code-statusline/`. Use the actual path.

### Step 2: Configure statusLine

Read `~/.claude/settings.json`. Merge the following `"statusLine"` key into the JSON. If the key already exists, replace it (update). If it doesn't exist, add it.

**statusLine config to add:**

```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command \"& (Join-Path (Resolve-Path ~) '.claude\\statusline.ps1')\"",
    "padding": 2
  }
}
```

**Permission to add** (if not already present):

```json
"Bash(powershell *)"
```

Add it to `permissions.allow` array in `~/.claude/settings.json`.

### Step 3: Confirm

Tell the user:
- "✅ 状态栏安装完成！"
- "运行 `/reload-plugins` 立即生效，或重启 Claude Code。"
- "卸载：输入 `/setup-statusline uninstall`"

---

## Operation: Uninstall

### Step 1: Remove script

Delete `~/.claude/statusline.ps1` if it exists.

### Step 2: Remove config

Read `~/.claude/settings.json`. Remove the `"statusLine"` key from the JSON.

### Step 3: Remove permission

Remove `"Bash(powershell *)"` from `permissions.allow` if present.

### Step 4: Confirm

Tell the user: "✅ 已卸载。statusLine 配置和脚本均已移除。运行 `/reload-plugins` 后生效。"
