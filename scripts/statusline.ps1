# statusline.ps1 — Claude Code status bar
# MUST be saved as UTF-8 with BOM (PowerShell on CJK Windows reads .ps1 as system codepage)
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$raw = [Console]::In.ReadToEnd()

# Prefer JSON parsing (safe when InputEncoding is UTF-8).
# Fall back to regex extraction if JSON is corrupted by CJK encoding.
try {
    $data = $raw | ConvertFrom-Json
    $cw    = $data.context_window
    $pct   = [int]($cw.used_percentage ?? 0)
    $inTok = [int]($cw.total_input_tokens ?? 0)
    $outTok  = [int]($cw.total_output_tokens ?? 0)
    $dur   = [double]($data.cost.total_duration_ms ?? 0)
} catch {
    # Regex extraction avoids JSON parsing, which breaks when session_name
    # contains CJK GBK bytes that alias to ASCII " (0x22) or \ (0x5C)
    # Anchor to context_window to avoid matching current_usage sub-fields
    $pct  = if ($raw -match '"context_window".*?"used_percentage":(\d+)')   { [int]$Matches[1] }    else { 0 }
    $inTok  = if ($raw -match '"context_window".*?"total_input_tokens":(\d+)')  { [int]$Matches[1] }    else { 0 }
    $outTok = if ($raw -match '"context_window".*?"total_output_tokens":(\d+)') { [int]$Matches[1] }    else { 0 }
    $dur  = if ($raw -match '"total_duration_ms":(\d+)') { [double]$Matches[1] } else { 0 }
}

$mins = [math]::Floor($dur / 60000)
$secs = [math]::Floor(($dur % 60000) / 1000)

$n   = [math]::Floor($pct / 10)
$bar = ([string][char]0x2588 * $n) + ([string][char]0x2591 * (10 - $n))

# Cumulative token tracking — use peak context window as monotonic estimate.
# context_window.total_* shrinks on /compact, but peak only grows.
$tokCache = "$env:TEMP\cc_tok_peak.json"
$maxIn  = $inTok
$maxOut = $outTok
if (Test-Path $tokCache) {
    try {
        $tc = Get-Content $tokCache -Raw | ConvertFrom-Json
        if ([int]$tc.maxIn -gt $maxIn)  { $maxIn  = [int]$tc.maxIn }
        if ([int]$tc.maxOut -gt $maxOut) { $maxOut = [int]$tc.maxOut }
    } catch {}
}
if ($inTok -gt $maxIn)   { $maxIn  = $inTok }
if ($outTok -gt $maxOut) { $maxOut = $outTok }
try { @{maxIn=$maxIn; maxOut=$maxOut} | ConvertTo-Json -Compress | Set-Content $tokCache } catch {}

# DeepSeek balance — cached 5 min to avoid API call every render
$cache = "$env:TEMP\ds_balance_cache.json"
$bal   = ""
if ((Test-Path $cache) -and ((Get-Item $cache).LastWriteTime -gt (Get-Date).AddMinutes(-5))) {
    $c = Get-Content $cache -Raw | ConvertFrom-Json
    $bal = " ¥$($c.total)$($c.currency)"
} else {
    try {
        $r = Invoke-RestMethod "https://api.deepseek.com/user/balance" `
            -Headers @{Authorization="Bearer $env:ANTHROPIC_AUTH_TOKEN"} -TimeoutSec 3 -ErrorAction Stop
        if ($r.balance_infos) {
            $b = $r.balance_infos[0]
            @{total=$b.total_balance; currency=$b.currency} | ConvertTo-Json | Set-Content $cache
            $bal = " ¥$($b.total_balance)$($b.currency)"
        }
    } catch {}
    if (-not $bal -and (Test-Path $cache)) {
        $c = Get-Content $cache -Raw | ConvertFrom-Json
        $bal = " ¥$($c.total)$($c.currency)"
    }
}

$tokStr = if ($maxIn -ge 1000) { '{0:F1}k/{1:F1}k' -f ($maxIn/1000), ($maxOut/1000) } else { '{0}/{1}' -f $maxIn, $maxOut }
[Console]::Write(('{0} {1}% | {2} tok | {3}m{4}s |{5}' -f $bar, $pct, $tokStr, $mins, $secs, $bal))
