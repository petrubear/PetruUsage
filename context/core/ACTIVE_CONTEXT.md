# Active Context

**Current Focus:** 4/5 providers working — polish and remaining debt
**Last Updated:** February 17, 2026
**Priority:** P1 (no P0 blockers — all critical providers working)

## Status

**Claude, Codex, Gemini, and Kiro are fully working at runtime.** Cursor is hidden from the UI (code preserved) because the test account can't fetch usage data from Cursor's Connect API.

Build passes. 17/17 tests pass. Working tree clean, pushed to origin.

## Provider Status

| Provider | Status | Credential Source | Notes |
|----------|--------|-------------------|-------|
| Claude | Working | `~/.claude/` + Keychain | Session %, weekly %, plan label |
| Codex | Working | `~/.codex/` + Keychain | Session %, weekly %, credits |
| Gemini | Working | Antigravity `state.vscdb` (proto) | Per-model quotas with reset timers |
| Kiro | Working | Kiro `state.vscdb` + token log | Cached usage breakdowns |
| Cursor | Hidden | Cursor `state.vscdb` | API returns 200 but `planUsage.limit` not extractable |

## Completed (Feb 17)

### Gemini Adapter — FIXED
- Correct DB path: `~/Library/Application Support/Antigravity/User/globalStorage/state.vscdb`
- Correct protobuf nesting: outer field 6 → inner (1=accessToken, 3=refreshToken, 4→1=expiry)
- Fixed Data slice indexing crash + SQLite WAL-mode read issue
- Added `os.Logger` tracing

### Cursor Adapter — Hidden
- Added `os.Logger` + improved error handling
- Hidden via `Provider.visibleCases` (code preserved)

### Infrastructure
- SQLiteService WAL fix (`READWRITE` instead of `READONLY`)
- `Provider.visibleCases` for UI filtering
- README.md added

## Requirements Checklist
- [x] Menu bar icon appears, no dock icon
- [x] Popover shows provider cards (height 700)
- [x] Claude: session/weekly usage with plan label
- [x] Codex: session/weekly/credits
- [x] Gemini: per-model quotas with reset timers
- [x] Kiro: cached usage breakdowns
- [ ] ~~Cursor: plan usage~~ (hidden — account issue)
- [x] Settings window with provider toggles
- [x] Auto-refresh on configurable interval
- [x] Graceful error messages for missing/expired credentials
- [x] All tests pass (17/17)
- [x] Build succeeds

## Next Priorities

1. **Investigate Cursor** on a different account or inspect raw API response
2. **Add LS probing** to Gemini adapter (DEBT-010) — discover `language_server_macos`, probe ports, query `GetUserStatus`/`GetCommandModelConfigs`
3. **Add `os.Logger`** to Claude and Codex adapters (DEBT-021)
4. **Delete dead code** — `TokenRefreshService` (DEBT-019), `CredentialReadingPort` (DEBT-020)
5. **Performance** — static `ISO8601DateFormatter` instances (DEBT-024)
6. **App icon** (DEBT-003)

## Open Questions
- Why does Cursor's Connect API return `planUsage` with unextractable `limit`? Plan-specific issue?
- Does the Antigravity LS provide better data than Cloud Code API?
- Should we add more providers (e.g., Windsurf, Copilot)?

## Key Files for Next Session

| File | What It Does |
|------|-------------|
| `PetruUsage/Infrastructure/Providers/Antigravity/AntigravityUsageAdapter.swift` | Gemini adapter — protobuf decoder, Cloud Code API, token refresh |
| `PetruUsage/Infrastructure/Providers/Cursor/CursorUsageAdapter.swift` | Cursor adapter — has logging, hidden from UI |
| `PetruUsage/Domain/Models/Provider.swift` | `visibleCases` controls which providers appear in UI |
| `PetruUsage/Infrastructure/Persistence/SQLiteService.swift` | WAL-mode fix lives here |
| `context/quality/TECHNICAL_DEBT.md` | 29 items, 4 P0, prioritized backlog |
