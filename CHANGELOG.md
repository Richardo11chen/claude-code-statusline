# Changelog

## 1.0.1 (2026-06-18)

- Fix: PS5.1 compatibility (replace `??`, drop `-Compress`)
- Fix: use `powershell` instead of `pwsh` (built into Windows)
- Fix: cumulative token peak tracking (stops fluctuation after `/compact`)
- Fix: correct install flow with `/reload-plugins` step

## 1.0.0 (2026-06-18)

- Initial release
- UTF-8 safe context bar with block characters
- Real-time input/output token display with cumulative peak tracking
- DeepSeek balance with 5-minute cache
- JSON parsing with CJK-safe regex fallback
- PS5.1+ compatible (uses `powershell` built into Windows 10/11)
- CJK Windows (GBK/Shift-JIS/EUC-KR) tested
