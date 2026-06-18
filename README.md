# CJK-Safe StatusLine for Claude Code

A real-time status bar plugin for Claude Code that survives CJK Windows encoding hell (GBK/Shift-JIS/EUC-KR vs UTF-8).

## What it shows

```
████████░░ 78% | 15.5k/1.2k tok | 15m22s | ¥12.50CNY
```

| Segment | Meaning |
|---------|---------|
| `████████░░` | Context bar (10 segments, filled = used) |
| `78%` | Context window used percentage |
| `15.5k/1.2k tok` | Input / Output tokens in current context |
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

- Windows with PowerShell 5.1+ (PowerShell 7 recommended)
- DeepSeek API key in `ANTHROPIC_AUTH_TOKEN` env var (for balance display)

## Install

```bash
claude plugins install claude-code-statusline@Richardo11chen
```

Or manually:

1. Add to `~/.claude/settings.json`:
```json
{
  "extraKnownMarketplaces": {
    "Richardo11chen-plugins": {
      "source": {
        "source": "github",
        "repo": "Richardo11chen/claude-code-statusline"
      }
    }
  },
  "enabledPlugins": {
    "claude-code-statusline@Richardo11chen-plugins": true
  }
}
```

2. Restart Claude Code.

## How it works

### Encoding safety

```
session_name → GBK bytes (D0 C5 CF A2 …)
                ↓
          byte 0x22 = ASCII " → JSON string terminates early
                ↓
          ConvertFrom-Json → FAIL → $data = $null → all zeros
```

**Fix:** JSON parsing with encoding-correct stdin, regex fallback:
```powershell
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

try {
    $data = $raw | ConvertFrom-Json
    $pct    = [int]($data.context_window.used_percentage ?? 0)
    $inTok  = [int]($data.context_window.total_input_tokens ?? 0)
    $outTok = [int]($data.context_window.total_output_tokens ?? 0)
} catch {
    # CJK-safe regex fallback
    $pct  = if ($raw -match '"context_window".*?"used_percentage":(\d+)') { ... }
    $inTok  = if ($raw -match '"total_input_tokens":(\d+)')  { ... }
    $outTok = if ($raw -match '"total_output_tokens":(\d+)') { ... }
}
```

No JSON parser → no encoding bugs.

### Output safety

- `[Console]::Write()` instead of `Write-Host` (which goes to console host, not stdout)
- `[Console]::OutputEncoding = UTF8` for proper Unicode output
- `[char]0xNNNN` codepoints instead of bare Unicode literals
- UTF-8 with BOM file encoding (required by PowerShell 5.1 on CJK Windows)

## Files

```
claude-code-statusline/
├── .claude-plugin/
│   └── plugin.json
├── settings.json          # StatusLine hook config
├── scripts/
│   └── statusline.ps1     # The status bar script
├── README.md
├── LICENSE
└── CHANGELOG.md
```
