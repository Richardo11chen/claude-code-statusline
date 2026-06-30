# CJK-Safe StatusLine for Claude Code

一个适用于 Claude Code 的实时状态栏插件，专为 CJK（中文/日文/韩文）Windows 编码地狱而生（GBK/Shift-JIS/EUC-KR vs UTF-8）。

## 显示内容

```
████████░░ 78% | 15.5k/1.2k tok | 15m22s | ¥12.50CNY
```

| 区块 | 含义 |
|------|------|
| `████████░░` | 上下文进度条（10 格，填充 = 已用） |
| `78%` | 上下文窗口使用百分比 |
| `15.5k/1.2k tok` | 输入 / 输出 Token 数（累积峰值） |
| `15m22s` | 会话持续时间 |
| `¥12.50CNY` | DeepSeek 余额（5 分钟缓存） |

## 为什么需要这个插件

在中文/日文/韩文 Windows 上，PowerShell 5.1 默认使用系统代码页（中文 GBK/CP936，日文 CP932，韩文 CP949），**不是 UTF-8**。这会导致：

- `.ps1` 文件以错误编码读取 → 乱码 → 语法错误
- `Write-Host` 输出到控制台主机而非标准输出 → Claude Code 无任何显示
- CJK 字符在 JSON 字符串中的字节可能误匹配 `"`（0x22）或 `\`（0x5C）→ JSON 结构损坏
- `$input` 与 `-File` 参数不兼容 → 数据为空 → 全部显示 0

本插件将所有修复方案整合在一个包中。同时兼容 PowerShell 5.1 和 7。

## 系统要求

- Windows 10/11，自带 PowerShell 5.1+（无需额外安装）
- DeepSeek API 密钥设置在 `ANTHROPIC_AUTH_TOKEN` 环境变量中（用于显示余额）

## 安装

**第 1 步** — 添加市场源（每台机器只需一次）：

```
/plugin marketplace add Richardo11chen/claude-code-statusline
```

**第 2 步** — 安装插件：

```
/plugin install claude-code-statusline@Richardo11chen-plugins
```

**第 3 步** — 运行配置（自动设置状态栏）：

```
/setup-statusline
```

**第 4 步** — 加载生效：

```
/reload-plugins
```

搞定，无需重启。脚本会被复制到 `~/.claude/statusline.ps1`，`settings.json` 会自动更新。

### 手动安装（不使用市场）

1. 复制 `scripts/statusline.ps1` 到 `~/.claude/statusline.ps1`
2. 在 `~/.claude/settings.json` 中添加：

```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command \"& (Join-Path (Resolve-Path ~) '.claude\\statusline.ps1')\"",
    "padding": 2
  }
}
```

### 更新

重新运行 `/setup-statusline` 即可更新脚本到最新版本。

### 卸载

```
/setup-statusline uninstall
```

## 工作原理

### 编码安全

```
session_name → GBK 字节 (D0 C5 CF A2 …)
                ↓
          字节 0x22 = ASCII " → JSON 字符串提前终止
                ↓
          ConvertFrom-Json → 失败 → $data = $null → 全部显示 0
```

**解决方案：** 先设输入编码再 JSON 解析，CJK 边缘情况回落正则提取：

```powershell
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
filter def($d) { if ($null -eq $_) { $d } else { $_ } }  # PS5.1 空值合并

try {
    $data = $raw | ConvertFrom-Json
    $pct   = [int](($data.context_window.used_percentage) | def 0)
    $inTok = [int](($data.context_window.total_input_tokens) | def 0)
} catch {
    # CJK 安全的正则回退
    $pct   = if ($raw -match '"context_window".*?"used_percentage":(\d+)') { [int]$Matches[1] } else { 0 }
    $inTok = if ($raw -match '"total_input_tokens":(\d+)') { [int]$Matches[1] } else { 0 }
}
```

### 输出安全

- 使用 `[Console]::Write()` 而非 `Write-Host`（后者会输出到控制台主机而非标准输出）
- 设置 `[Console]::OutputEncoding = UTF8` 确保 Unicode 正常输出
- 用 `[char]0xNNNN` 编码点代替直接写 Unicode 字符
- 文件保存为 UTF-8 with BOM（CJK Windows 上 PowerShell 5.1 的要求）

### Token 累积追踪

`context_window.total_*` 在执行 `/compact` 后会缩小。本插件通过 `%TEMP%\cc_tok_peak.json` 缓存历史峰值，显示的 Token 数只会增长不会下降。

## 文件结构

```
claude-code-statusline/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── skills/
│   └── setup-statusline/
│       └── SKILL.md              # /setup-statusline 自动配置
├── settings.json                  # StatusLine 配置参考
├── scripts/
│   └── statusline.ps1             # PS5.1+ 兼容的状态栏脚本
├── README.md
├── README.zh-CN.md
├── LICENSE
└── CHANGELOG.md
```

## 协议

MIT
