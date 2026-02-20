# Session State

**Last Updated:** February 17, 2026, 5:30 PM
**Session Status:** Complete — ready for next session
**Git:** `master` branch, clean working tree, up to date with `origin/master`
**Last Commit:** `564c051 docs: add README.md`

## Current State

**4 of 5 providers working at runtime: Claude, Codex, Gemini, Kiro.** Cursor hidden from UI.

- Build: passing
- Tests: 17/17 passing
- Working tree: clean (all changes committed and pushed)

## What Was Accomplished (Feb 17)

### Session 1 (earlier)
- Rewrote AntigravityUsageAdapter to use Gemini CLI credentials (turned out to be wrong approach)
- Added `flexDouble()`/`flexInt()` helpers for Cursor's Connect protocol
- Popover height increased to 700

### Session 2 (this session)
- **Fixed Gemini adapter** — correct DB path (`~/Library/Application Support/Antigravity/...`), correct proto nesting (outer field 6 → inner), fixed Data slice crash, fixed SQLite WAL-mode read
- **Added logging** to Gemini and Cursor adapters (`os.Logger`)
- **Hidden Cursor** from UI via `Provider.visibleCases` (code preserved)
- **Fixed SQLiteService** — `SQLITE_OPEN_READONLY` → `SQLITE_OPEN_READWRITE` for WAL-mode compatibility
- **Updated tech debt** — resolved 11 items, 29 remaining (4 P0)
- **Added README.md**
- **Updated all context files**

## Key Technical Decisions

| Decision | Rationale |
|----------|-----------|
| Antigravity reads its own `state.vscdb`, not VS Code/Cursor's | Matches reference plugin; Antigravity is a standalone Electron app with its own storage |
| Protobuf decoded inline (~50 lines) | Avoids external dependency; only needs varint + length-delimited wire types |
| `SQLITE_OPEN_READWRITE` instead of `READONLY` | WAL-mode DBs held by other processes can't be read in readonly mode |
| `Data(slice)` for protobuf sub-messages | Swift `Data` slices keep original indices; must re-base before recursive parsing |
| `Provider.visibleCases` for UI filtering | Keeps `.cursor` in `allCases` for infrastructure (registry, settings persistence) while hiding from UI |
| API key used as Bearer token for Gemini | Matches reference plugin behavior — Cloud Code API accepts API key as Bearer |

## Next Session Priorities

1. **Investigate Cursor** on a different account or inspect raw API response (write to temp file to bypass os_log privacy redaction)
2. **Add LS probing** to Gemini adapter (DEBT-010) — `language_server_macos` process discovery, port probing, `GetUserStatus`/`GetCommandModelConfigs` calls
3. **Add `os.Logger`** to Claude and Codex adapters (DEBT-021)
4. **Delete dead code** — `TokenRefreshService` (DEBT-019), `CredentialReadingPort` (DEBT-020)
5. **Performance** — static `ISO8601DateFormatter` (DEBT-024)

## Reference Files

These external reference implementations are useful when debugging adapter issues:

| Provider | Reference Plugin |
|----------|-----------------|
| Claude | `/Users/edison/Documents/Projects/Github/openusage/plugins/claude/plugin.js` |
| Cursor | `/Users/edison/Documents/Projects/Github/openusage/plugins/cursor/plugin.js` |
| Codex | `/Users/edison/Documents/Projects/Github/openusage/plugins/codex/plugin.js` |
| Antigravity | `/Users/edison/Documents/Projects/Github/openusage/plugins/antigravity/plugin.js` |

## Handoff Notes

- **Antigravity DB path:** `~/Library/Application Support/Antigravity/User/globalStorage/state.vscdb`
- **Proto structure:** outer field 6 → inner (1=accessToken, 3=refreshToken, 4→1=expiryEpochSeconds)
- **Data slices:** Always use `data[data.startIndex + i]` or `Data(slice)` — Swift slices keep original indices
- **SQLite WAL:** Uses `SQLITE_OPEN_READWRITE` (not READONLY) so other processes' WAL files are accessible
- **Provider visibility:** `Provider.visibleCases` excludes `.cursor`; used in ViewModel, FetchAllUsageUseCase, SettingsView, tests
- **Logging:** subsystem `com.petru.PetruUsage`, categories `Antigravity`/`Cursor`. Use `log stream --level debug` for live output. Debug values are privacy-redacted in `log show`
- **Build system:** `xcodegen generate` regenerates `.xcodeproj` from `project.yml`. Swift 5 language mode (Swift 6 strict concurrency disabled)
