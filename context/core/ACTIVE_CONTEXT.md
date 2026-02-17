# Active Context

**Current Focus:** 4/5 providers working — polish and remaining debt
**Started:** February 16, 2026
**Last Updated:** February 17, 2026
**Priority:** P1

## Status

**Claude, Codex, Gemini, and Kiro are fully working at runtime.** Cursor is hidden from the UI (code preserved) because the test account can't fetch usage data from Cursor's Connect API.

## What Was Done (Feb 17 — Session 2)

### Antigravity/Gemini — FIXED
- Corrected DB path to `~/Library/Application Support/Antigravity/User/globalStorage/state.vscdb` (Antigravity's own state DB, matching reference plugin)
- Restored SQLite-based credential loading with protobuf decoder
- Fixed proto field nesting: outer field 6 → inner (field 1=accessToken, field 3=refreshToken, field 4→1=expiry)
- Fixed `Data` slice indexing crash (Swift slices keep original indices)
- API key used as Bearer token (matching reference plugin)
- Added `os.Logger` tracing throughout

### Cursor — Hidden from UI
- Added `os.Logger` tracing for credential load, API response, field extraction
- Improved error handling: throws `ProviderError.invalidResponse` instead of silent fallthrough
- Hidden via `Provider.visibleCases` filtering (code fully preserved)

### Infrastructure Fixes
- SQLiteService: `SQLITE_OPEN_READONLY` → `SQLITE_OPEN_READWRITE` for WAL-mode DB compatibility
- Provider model: added `static var visibleCases` to filter hidden providers

## Requirements
- [x] Menu bar icon appears, no dock icon
- [x] Popover shows provider cards without scrolling (height 700)
- [x] Claude provider shows session/weekly usage with plan label
- [ ] ~~Cursor provider shows plan usage~~ (hidden — account issue)
- [x] Codex provider shows session/weekly/credits
- [x] Gemini provider shows per-model quotas with reset timers
- [x] Kiro provider shows cached usage breakdowns
- [x] Settings window with provider toggles
- [x] Auto-refresh on configurable interval
- [x] Graceful error messages when credentials are missing or expired
- [x] All tests pass (17/17)
- [x] Build succeeds

## Next Priorities
1. **Investigate Cursor on a different account** — may be a plan/permissions issue
2. **Add LS (Language Server) probing** to Gemini adapter (DEBT-010) for higher-quality data
3. **Add `os.Logger`** to Claude and Codex adapters (DEBT-021)
4. **Clean up dead code** — TokenRefreshService (DEBT-019), CredentialReadingPort (DEBT-020)
5. **Static ISO8601DateFormatter** (DEBT-024) — performance improvement

## Open Questions
- Why does Cursor's Connect API return `planUsage` with unextractable `limit`? Is it a plan-specific issue?
- Does the Antigravity LS (language_server_macos) provide better data than Cloud Code API?
