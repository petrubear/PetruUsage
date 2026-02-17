# Technical Debt Registry

**Last Updated:** February 17, 2026
**Total Items:** 29
**Critical (P0):** 4

## Priority Definitions

| Priority | Definition | SLA |
|----------|------------|-----|
| P0 | Blocking development or causing incidents | Immediate |
| P1 | Significant impact on velocity | This sprint |
| P2 | Moderate impact, workaround exists | This quarter |
| P3 | Minor, address when convenient | Backlog |

---

## P0 - Critical

### DEBT-006: Gemini (formerly Antigravity) provider adapter — RESOLVED
- **Location:** `PetruUsage/Infrastructure/Providers/Antigravity/AntigravityUsageAdapter.swift`
- **Added:** February 16, 2026
- **Resolved:** February 17, 2026
- **Resolution:** Fixed DB path to `~/Library/Application Support/Antigravity/User/globalStorage/state.vscdb`, corrected proto nesting (outer field 6 → inner), fixed Data slice indexing crash, fixed SQLite WAL-mode read. Working at runtime with live credentials

### DEBT-008: Cursor provider adapter — hidden from UI, needs account investigation
- **Location:** `PetruUsage/Infrastructure/Providers/Cursor/CursorUsageAdapter.swift`
- **Added:** February 16, 2026
- **Updated:** February 17, 2026
- **Impact:** Cursor provider returns `planUsage` from API but `limit` field can't be extracted. Logging added but values are privacy-redacted by Apple
- **Status:** Code preserved with logging and improved error handling. Hidden from UI via `Provider.visibleCases`. API returns 200 with `planUsage` (5 fields) but `flexDouble(planUsage["limit"])` returns nil — likely a plan/account-specific issue
- **Remaining:** Test with a different Cursor account; inspect raw API response by writing to temp file (bypasses os_log privacy redaction)

### DEBT-010: Missing LS (Language Server) probing in Gemini adapter
- **Location:** `PetruUsage/Infrastructure/Providers/Antigravity/AntigravityUsageAdapter.swift`
- **Added:** February 16, 2026
- **Impact:** The adapter only uses the Cloud Code API, missing the higher-quality data available from the local Language Server. The reference plugin tries LS first (probing ports on 127.0.0.1) and only falls back to Cloud Code
- **Proposed Fix:** Port `discoverLs()`, `findWorkingPort()`, `probeLs()`, and `callLs()` from the reference plugin (plugin.js lines 178-425) — discover the `language_server_macos` process, probe its ports, and query `GetUserStatus` / `GetCommandModelConfigs`
- **Estimated Effort:** 6 hours

### DEBT-012: Cursor adapter planUsage values may be off by 100x
- **Location:** `PetruUsage/Infrastructure/Providers/Cursor/CursorUsageAdapter.swift:352-394`
- **Added:** February 16, 2026
- **Impact:** Plan usage values are divided by 100 assuming cents, but the API may return values in different scales depending on version. The reference plugin uses `ctx.fmt.dollars()` which has its own scaling
- **Proposed Fix:** Inspect actual API responses (now logged) and determine correct scaling. Add unit test with sample API data
- **Estimated Effort:** 1 hour

### DEBT-013: RefreshUsageUseCase callback not MainActor-safe
- **Location:** `PetruUsage/Application/UseCases/RefreshUsageUseCase.swift:12-20`
- **Added:** February 16, 2026
- **Impact:** The `onUpdate` callback executes on a background thread but updates `@MainActor` properties in `UsageViewModel`. The ViewModel wraps it in `Task { @MainActor ... }` but this creates a gap where concurrent fetches could interleave
- **Proposed Fix:** Mark the `onUpdate` parameter as `@MainActor @Sendable` or restructure to return results and let the ViewModel update itself
- **Estimated Effort:** 1 hour

---

## P1 - High Priority

### DEBT-001: No credential persistence after token refresh
- **Location:** `PetruUsage/Infrastructure/Providers/Claude/ClaudeUsageAdapter.swift`
- **Added:** February 16, 2026
- **Impact:** Refreshed tokens are not saved back to the credential file/keychain, so tokens may be refreshed repeatedly on every fetch cycle
- **Proposed Fix:** After successful refresh, write updated credentials back using the same source (file or keychain). Apply same fix to Cursor (write back to SQLite) and Codex (write back to file/keychain)
- **Estimated Effort:** 3 hours

### DEBT-002: SQL injection risk in SQLite queries
- **Location:** `CursorUsageAdapter.swift:138`, `KiroUsageAdapter.swift:35`, `AntigravityUsageAdapter.swift:173-175`
- **Added:** February 16, 2026
- **Impact:** SQLite keys are currently hardcoded strings so this is safe in practice, but the pattern of string-interpolated SQL is fragile and could become a real vulnerability if keys ever come from user input
- **Proposed Fix:** Add parameterized query support to `SQLiteService` using `sqlite3_bind_text`, update all callers
- **Estimated Effort:** 3 hours

### DEBT-019: TokenRefreshService is dead code
- **Location:** `PetruUsage/Application/Services/TokenRefreshService.swift`
- **Added:** February 16, 2026
- **Impact:** Defined but never instantiated or used anywhere. Each adapter implements its own retry-on-401 logic inline instead
- **Proposed Fix:** Either integrate it into the adapters (replace duplicated retry logic) or delete the file
- **Estimated Effort:** 2 hours

### DEBT-020: CredentialReadingPort is dead code
- **Location:** `PetruUsage/Domain/Ports/CredentialReadingPort.swift`
- **Added:** February 16, 2026
- **Impact:** Protocol defined but never implemented or used. Each adapter reads credentials directly
- **Proposed Fix:** Either implement per-provider credential readers conforming to the port, or delete the file
- **Estimated Effort:** 1 hour

### DEBT-021: Silent token refresh errors across all adapters
- **Location:** `ClaudeUsageAdapter.swift:24-27`, `CodexUsageAdapter.swift:24-29`
- **Added:** February 16, 2026
- **Updated:** February 17, 2026
- **Impact:** Claude and Codex adapters use `try?` to silently swallow refresh errors. Users see generic errors without knowing the refresh specifically failed
- **Status:** Partially addressed — Cursor and Antigravity adapters now have `os.Logger` tracing for refresh failures. Claude and Codex still need logging
- **Proposed Fix:** Add `os.Logger` to Claude and Codex adapters
- **Estimated Effort:** 1 hour

---

## P2 - Medium Priority

### DEBT-003: Missing app icon
- **Location:** `PetruUsage/Assets.xcassets/AppIcon.appiconset/`
- **Added:** February 16, 2026
- **Impact:** App shows generic icon in menu bar and settings
- **Proposed Fix:** Design and add proper app icon assets
- **Estimated Effort:** 1 hour

### DEBT-004: Settings window opening mechanism
- **Location:** `PetruUsage/PetruUsageApp.swift:68-74`
- **Added:** February 16, 2026
- **Impact:** Opening settings uses window title matching which is fragile
- **Proposed Fix:** Use `@Environment(\.openWindow)` with proper window ID, or use Settings scene
- **Estimated Effort:** 1 hour

### DEBT-022: Direct FileManager access in adapters without port abstraction
- **Location:** `ClaudeUsageAdapter.swift:53-58`, `CodexUsageAdapter.swift:131-147`, `KiroUsageAdapter.swift:86-92`, `AntigravityUsageAdapter.swift`
- **Added:** February 16, 2026
- **Impact:** Adapters use `FileManager.default` directly, bypassing the hexagonal architecture. Makes credential loading untestable without real files on disk
- **Proposed Fix:** Create a `FileSystemPort` protocol with `fileExists(atPath:)`, `contents(atPath:)` methods; inject into adapters
- **Estimated Effort:** 2 hours

### DEBT-024: ISO8601DateFormatter created on every call
- **Location:** `CodexUsageAdapter.swift`, `AntigravityUsageAdapter.swift`, `KiroUsageAdapter.swift`
- **Added:** February 16, 2026
- **Impact:** New `ISO8601DateFormatter` instances created for every date parse. DateFormatters are expensive to create
- **Proposed Fix:** Use a `static let` formatter instance in a shared extension or helper
- **Estimated Effort:** 30 minutes

### DEBT-025: DateFormatting helper duplicates ResetTimerView logic
- **Location:** `PetruUsage/Presentation/Helpers/DateFormatting.swift:25-45`
- **Added:** February 16, 2026
- **Impact:** `DateFormatting.countdown()` is defined but never used; `ResetTimerView` implements its own identical formatting
- **Proposed Fix:** Have `ResetTimerView` call `DateFormatting.countdown()`, or delete the unused function
- **Estimated Effort:** 15 minutes

### DEBT-026: URLSessionHTTPClient lowercases all response header keys
- **Location:** `PetruUsage/Infrastructure/Network/URLSessionHTTPClient.swift:35`
- **Added:** February 16, 2026
- **Impact:** All header keys are lowercased in the response. Callers must know to use lowercase keys. The Codex adapter reads `x-codex-primary-used-percent` (already lowercase, so works), but this is an implicit contract that's easy to break
- **Proposed Fix:** Document the behavior in `HTTPResponse`, or use a case-insensitive dictionary wrapper
- **Estimated Effort:** 30 minutes

### DEBT-027: Codex adapter credits calculation uses hardcoded limit of 1000
- **Location:** `PetruUsage/Infrastructure/Providers/Codex/CodexUsageAdapter.swift:245-250`
- **Added:** February 16, 2026
- **Impact:** Credits progress bar assumes a fixed limit of 1000 credits. The actual limit may differ per plan
- **Proposed Fix:** Fetch actual credit limit from API if available, or remove the progress bar in favor of a text display showing remaining balance
- **Estimated Effort:** 1 hour

### DEBT-028: Codex adapter regex compiled on every call
- **Location:** `PetruUsage/Infrastructure/Providers/Codex/CodexUsageAdapter.swift:212`
- **Added:** February 16, 2026
- **Impact:** `#"^GPT-[\d.]+-Codex-"#` regex is recompiled via `replacingOccurrences(of:options:.regularExpression)` on every model name in every fetch cycle
- **Proposed Fix:** Use a `static let` compiled `Regex` or `NSRegularExpression`
- **Estimated Effort:** 15 minutes

---

## P3 - Low Priority

### DEBT-005: No error retry mechanism in UI
- **Location:** `PetruUsage/Presentation/Views/ProviderCardView.swift`
- **Added:** February 16, 2026
- **Impact:** When a provider errors, user must wait for auto-refresh or manually refresh all
- **Proposed Fix:** Add per-provider retry button in error state
- **Estimated Effort:** 1 hour

### DEBT-029: MenuBarView uses onAppear for initial fetch
- **Location:** `PetruUsage/Presentation/Views/MenuBarView.swift:78-82`
- **Added:** February 16, 2026
- **Impact:** `refreshAll()` in `onAppear` could trigger multiple times if the view is re-created. Minor in practice since guarded by `lastRefreshed == nil`
- **Proposed Fix:** Use `.task` modifier instead of `.onAppear` for async work
- **Estimated Effort:** 15 minutes

### DEBT-030: Inconsistent error message style across adapters
- **Location:** All adapter files
- **Added:** February 16, 2026
- **Impact:** Error messages use different wording patterns: "Sign in via Cursor app" vs "Run `claude` to authenticate" vs "Run `codex` to authenticate". Not user-facing critical but inconsistent
- **Proposed Fix:** Standardize to a common format like "Not logged in. Open [Provider] to authenticate."
- **Estimated Effort:** 30 minutes

### DEBT-031: Magic numbers throughout adapters
- **Location:** Multiple adapter files
- **Added:** February 16, 2026
- **Impact:** Values like `5 * 60 * 60` (session window), `7 * 24 * 60 * 60` (weekly window), `100` (percentage limit) are repeated without named constants
- **Proposed Fix:** Extract to named constants at the top of each file or in a shared constants file
- **Estimated Effort:** 30 minutes

### DEBT-032: Kiro adapter has no API integration
- **Location:** `PetruUsage/Infrastructure/Providers/Kiro/KiroUsageAdapter.swift`
- **Added:** February 16, 2026
- **Impact:** Kiro adapter only reads cached SQLite data and a local token log file. No actual API calls are made. This is by design (no known public API), but limits data freshness
- **Proposed Fix:** Monitor for a public Kiro usage API; for now, document the limitation clearly in the UI when displaying Kiro data (e.g., "Cached data" badge)
- **Estimated Effort:** 30 minutes

### DEBT-033: SettingsViewModel onProvidersChanged closure potential retain cycle
- **Location:** `PetruUsage/Presentation/ViewModels/SettingsViewModel.swift:9`
- **Added:** February 16, 2026
- **Impact:** The `onProvidersChanged` closure passed at init could capture the caller strongly. In `PetruUsageApp.swift` it captures `usageVM` which is owned by state, so unlikely to leak in practice
- **Proposed Fix:** Use `[weak usageVM]` in the closure at the call site, or restructure to use Combine/observation
- **Estimated Effort:** 15 minutes

### DEBT-034: sqlite3_close called with potentially nil pointer
- **Location:** `PetruUsage/Infrastructure/Persistence/SQLiteService.swift:12-15`
- **Added:** February 16, 2026
- **Impact:** In the error path of `sqlite3_open_v2`, `sqlite3_close(db)` is called where `db` could be nil. `sqlite3_close(nil)` is actually safe per SQLite docs (returns SQLITE_OK), but the `db.map` on line 13 already handles the nil case
- **Proposed Fix:** Remove the redundant `sqlite3_close(db)` from the error path since `defer` won't run and `db` is nil
- **Estimated Effort:** 5 minutes

---

## Resolved Debt (Last 30 Days)

| ID | Title | Resolved | Resolution |
|----|-------|----------|------------|
| DEBT-007 | Kiro provider adapter not working | Feb 17, 2026 | User confirmed working fine |
| DEBT-009 | Cursor missing Enterprise handling | Feb 17, 2026 | Already implemented in adapter |
| DEBT-011 | Cursor billingCycleEnd type mismatch | Feb 17, 2026 | Replaced with `flexDouble()` helper |
| DEBT-014 | Missing User-Agent headers | Feb 17, 2026 | All adapters now include `User-Agent: PetruUsage` |
| DEBT-015 | Claude adapter missing plan display | Feb 17, 2026 | User confirmed Claude working fine |
| DEBT-016 | Cursor missing shouldLogout handling | Feb 17, 2026 | Already implemented in adapter |
| DEBT-017 | Antigravity missing token cache | Feb 17, 2026 | Already implemented, noted as resolved |
| DEBT-018 | Unsafe force-unwrap in Antigravity | Feb 17, 2026 | Removed with Gemini CLI credential rewrite |
| DEBT-023 | ProtobufDecoder inline | Feb 17, 2026 | Restored as minimal inline wire-format decoder (~40 lines) matching reference plugin |
| DEBT-006 | Gemini adapter not working | Feb 17, 2026 | Fixed DB path, proto nesting, Data slice indexing, SQLite WAL mode |
| DEBT-035 | No logging infrastructure | Feb 17, 2026 | Added `os.Logger` to Antigravity and Cursor adapters |
