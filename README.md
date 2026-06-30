# CJK-Safe StatusLine for Claude Code

[中文文档](README.zh-CN.md)

A real-time status bar plugin for Claude Code that survives CJK Windows encoding hell (GBK/Shift-JIS/EUC-KR vs UTF-8).

## What it shows

```
████████░░ 78% | 15.5k/1.2k tok | 15m22s | ¥12.50CNY
```

| Segment | Meaning |
|---------|---------|
| `████████░░` | Context bar (10 segments, filled = used) |
| `78%` | Context window used percentage |
| `15.5k/1.2k tok` | Input / Output tokens (cumulative peak, survives `/compact`) |
| `15m22s` | Session duration |
| `¥12.50CNY` | DeepSeek balance (cached 5 min) |

## Why this exists

On Chinese/Japanese/Korean Windows, PowerShell 5.1 defaults to the system codepage (GBK/CP936 for Chinese, CP932 for Japanese, CP949 for Korean), **not UTF-8**. This causes:

- `.ps1` files read with wrong encoding → garbled characters → syntax errors
- `Write-Host` output goes to console host, not stdout → Claude Code sees nothing
- CJK bytes in JSON strings can alias to `"` (0x22) or `\` (0x5C) → JSON structure breaks
- `$input` unreliable with `-File` → empty data → all zeros

This plugin bundles all fixes in one package. Works on both PowerShell 5.1 and 7.

## Requirements

- Windows 10/11 with PowerShell 5.1+ (built-in, no extra install needed)
- DeepSeek API key in `ANTHROPIC_AUTH_TOKEN` env var (for balance display)

## Install

**Step 1** — Add the marketplace (once per machine):

```bash
/plugin marketplace add Richardo11chen/claude-code-statusline
```

**Step 2** — Install the plugin:

```bash
/plugin install claude-code-statusline@Richardo11chen-plugins
```

**Step 3** — Reload to load the plugin's skill:

```bash
/reload-plugins
```

**Step 4** — Run setup (auto-configures statusLine):

```bash
/setup-statusline
```

That's it. No restart needed. The script is copied to `~/.claude/statusline.ps1` and your `settings.json` is updated automatically.

### Uninstall

```bash
/setup-statusline uninstall
```

It removes the statusLine config from `settings.json`, deletes `~/.claude/statusline.ps1`, and cleans up permissions.

### Manual install without marketplace

1. Copy `scripts/statusline.ps1` to `~/.claude/statusline.ps1`
2. Add this to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command \"& (Join-Path (Resolve-Path ~) '.claude\\statusline.ps1')\"",
    "padding": 2
  }
}
```

## How it works

### Encoding safety

```
session_name → GBK bytes (D0 C5 CF A2 …)
                ↓
          byte 0x22 = ASCII " → JSON string terminates early
                ↓
          ConvertFrom-Json → FAIL → $data = $null → all zeros
```

**Fix:** JSON parsing with correct input encoding, regex fallback for CJK edge cases:
```powershell
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
filter def($d) { if ($null -eq $_) { $d } else { $_ } }  # PS5.1 null-coalesce

try {
    $data = $raw | ConvertFrom-Json
    $cw     = $data.context_window
    $pct    = [int](($cw.used_percentage) | def 0)
    $inTok  = [int](($cw.total_input_tokens) | def 0)
    $outTok = [int](($cw.total_output_tokens) | def 0)
    $dur    = [double](($data.cost.total_duration_ms) | def 0)
} catch {
    # CJK-safe regex fallback — avoids Phantom-" bug
    $pct   = if ($raw -match '"context_window".*?"used_percentage":(\d+)') { [int]$Matches[1] } else { 0 }
    $inTok = if ($raw -match '"context_window".*?"total_input_tokens":(\d+)') { [int]$Matches[1] } else { 0 }
    $outTok = if ($raw -match '"context_window".*?"total_output_tokens":(\d+)') { [int]$Matches[1] } else { 0 }
    $dur   = if ($raw -match '"total_duration_ms":(\d+)') { [double]$Matches[1] } else { 0 }
}
```

No JSON parser → no encoding bugs.

### Cumulative peak tracking

`context_window.total_input_tokens` shrinks after `/compact` (context compression), causing the displayed number to fluctuate down. To fix this, the script tracks the **maximum observed value** in `%TEMP%\cc_tok_peak.json`:

```powershell
$tokCache = "$env:TEMP\cc_tok_peak.json"
$maxIn  = $inTok
if (Test-Path $tokCache) {
    $tc = Get-Content $tokCache -Raw | ConvertFrom-Json
    if ([int]$tc.maxIn -gt $maxIn) { $maxIn = [int]$tc.maxIn }
}
if ($inTok -gt $maxIn) { $maxIn = $inTok }
@{maxIn=$maxIn; ...} | ConvertTo-Json | Set-Content $tokCache
```

The displayed token count **only goes up** across a session.

### Output safety

- `[Console]::Write()` instead of `Write-Host` (which goes to console host, not stdout)
- `[Console]::OutputEncoding = UTF8` for proper Unicode output
- `[char]0xNNNN` codepoints instead of bare Unicode literals
- UTF-8 with BOM file encoding (required by PowerShell 5.1 on CJK Windows)

## Files

```
claude-code-statusline/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── skills/
│   └── setup-statusline/
│       └── SKILL.md            # /setup-statusline auto-config
├── settings.json                # StatusLine hook config
├── scripts/
│   └── statusline.ps1           # PS5.1+ compatible status bar
├── README.md
├── README.zh-CN.md
├── LICENSE
└── CHANGELOG.md
```
