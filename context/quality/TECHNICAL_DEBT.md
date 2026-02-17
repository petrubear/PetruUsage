# Technical Debt Registry

**Last Updated:** February 16, 2026
**Total Items:** 35
**Critical (P0):** 10

## Priority Definitions

| Priority | Definition | SLA |
|----------|------------|-----|
| P0 | Blocking development or causing incidents | Immediate |
| P1 | Significant impact on velocity | This sprint |
| P2 | Moderate impact, workaround exists | This quarter |
| P3 | Minor, address when convenient | Backlog |

---

## P0 - Critical

### DEBT-006: Antigravity provider adapter not working
- **Location:** `PetruUsage/Infrastructure/Providers/Antigravity/AntigravityUsageAdapter.swift`
- **Added:** February 16, 2026
- **Impact:** Antigravity provider fails to fetch usage data at runtime; users see an error instead of per-model Gemini quotas
- **Proposed Fix:** Debug credential loading (SQLite queries, protobuf decoding, Google OAuth refresh) and Cloud Code API calls against a live Antigravity installation; compare behavior with the OpenUsage reference plugin
- **Estimated Effort:** 4 hours

### DEBT-007: Kiro provider adapter not working
- **Location:** `PetruUsage/Infrastructure/Providers/Kiro/KiroUsageAdapter.swift`
- **Added:** February 16, 2026
- **Impact:** Kiro provider fails to fetch usage data at runtime; users see an error instead of cached usage breakdowns
- **Proposed Fix:** Debug SQLite query against live Kiro `state.vscdb`; verify the key `kiro.resourceNotifications.usageState` exists and its JSON structure matches the expected `usageBreakdowns` schema; check token log fallback path
- **Estimated Effort:** 3 hours

### DEBT-008: Cursor provider adapter not working
- **Location:** `PetruUsage/Infrastructure/Providers/Cursor/CursorUsageAdapter.swift`
- **Added:** February 16, 2026
- **Impact:** Cursor provider fails to fetch usage data at runtime; users see an error instead of plan usage and credit grants
- **Proposed Fix:** Debug SQLite credential loading from `state.vscdb`, JWT decoding of the access token, token refresh flow, and Connect protocol API calls; compare with the OpenUsage reference plugin
- **Estimated Effort:** 4 hours

### DEBT-009: Missing Enterprise account handling in Cursor adapter
- **Location:** `PetruUsage/Infrastructure/Providers/Cursor/CursorUsageAdapter.swift:62-82`
- **Added:** February 16, 2026
- **Impact:** Enterprise Cursor users get "No active Cursor subscription" error because the adapter doesn't detect Enterprise accounts and switch to the REST usage API
- **Proposed Fix:** Port the `buildEnterpriseResult` logic from the reference plugin (plugin.js lines 156-221) — detect Enterprise when `!usage.planUsage && planName == "enterprise"`, then call `https://cursor.com/api/usage` with session cookie
- **Estimated Effort:** 3 hours

### DEBT-010: Missing LS (Language Server) probing in Antigravity adapter
- **Location:** `PetruUsage/Infrastructure/Providers/Antigravity/AntigravityUsageAdapter.swift`
- **Added:** February 16, 2026
- **Impact:** The adapter only uses the Cloud Code API, missing the higher-quality data available from the local Language Server. The reference plugin tries LS first (probing ports on 127.0.0.1) and only falls back to Cloud Code
- **Proposed Fix:** Port `discoverLs()`, `findWorkingPort()`, `probeLs()`, and `callLs()` from the reference plugin (plugin.js lines 178-425) — discover the `language_server_macos` process, probe its ports, and query `GetUserStatus` / `GetCommandModelConfigs`
- **Estimated Effort:** 6 hours

### DEBT-011: Cursor adapter billingCycleEnd type mismatch
- **Location:** `PetruUsage/Infrastructure/Providers/Cursor/CursorUsageAdapter.swift:183-185`
- **Added:** February 16, 2026
- **Impact:** `billingCycleEnd` is cast as `String` but the API returns it as a number (milliseconds). Date parsing silently fails, so billing cycle end / reset timer is never shown
- **Proposed Fix:** Cast as `Double` or `NSNumber` instead of `String`: `if let cycleEnd = usage["billingCycleEnd"] as? Double` (matching reference plugin.js line 374: `Number(usage.billingCycleEnd)`)
- **Estimated Effort:** 30 minutes

### DEBT-012: Cursor adapter planUsage values may be off by 100x
- **Location:** `PetruUsage/Infrastructure/Providers/Cursor/CursorUsageAdapter.swift:174-195`
- **Added:** February 16, 2026
- **Impact:** Plan usage values are divided by 100 assuming cents, but the API may return values in different scales depending on version. The reference plugin uses `ctx.fmt.dollars()` which has its own scaling
- **Proposed Fix:** Inspect actual API responses and determine correct scaling. Add unit test with sample API data
- **Estimated Effort:** 1 hour

### DEBT-013: RefreshUsageUseCase callback not MainActor-safe
- **Location:** `PetruUsage/Application/UseCases/RefreshUsageUseCase.swift:12-20`
- **Added:** February 16, 2026
- **Impact:** The `onUpdate` callback executes on a background thread but updates `@MainActor` properties in `UsageViewModel`. The ViewModel wraps it in `Task { @MainActor ... }` but this creates a gap where concurrent fetches could interleave
- **Proposed Fix:** Mark the `onUpdate` parameter as `@MainActor @Sendable` or restructure to return results and let the ViewModel update itself
- **Estimated Effort:** 1 hour

### DEBT-014: Missing User-Agent headers on all provider API requests
- **Location:** `ClaudeUsageAdapter.swift:143`, `CodexUsageAdapter.swift:150`, `AntigravityUsageAdapter.swift:148`, `CursorUsageAdapter.swift:100`
- **Added:** February 16, 2026
- **Impact:** Some servers may reject requests or serve different responses without User-Agent. All reference plugins include User-Agent headers (e.g., `"User-Agent": "OpenUsage"` or `"User-Agent": "antigravity"`)
- **Proposed Fix:** Add `"User-Agent": "PetruUsage"` to all HTTP requests in each adapter
- **Estimated Effort:** 30 minutes

### DEBT-015: Claude adapter missing plan/subscription display
- **Location:** `PetruUsage/Infrastructure/Providers/Claude/ClaudeUsageAdapter.swift:234`
- **Added:** February 16, 2026
- **Impact:** Always returns `plan: nil` so the user's subscription tier (Pro, Team, etc.) is never shown. The reference plugin (plugin.js lines 342-348) extracts plan from `creds.oauth.subscriptionType`
- **Proposed Fix:** Parse `subscriptionType` from the credential JSON's `claudeAiOauth` object and pass it as the plan label
- **Estimated Effort:** 30 minutes

---

## P1 - High Priority

### DEBT-001: No credential persistence after token refresh
- **Location:** `PetruUsage/Infrastructure/Providers/Claude/ClaudeUsageAdapter.swift`
- **Added:** February 16, 2026
- **Impact:** Refreshed tokens are not saved back to the credential file/keychain, so tokens may be refreshed repeatedly on every fetch cycle
- **Proposed Fix:** After successful refresh, write updated credentials back using the same source (file or keychain). Apply same fix to Cursor (write back to SQLite) and Codex (write back to file/keychain)
- **Estimated Effort:** 3 hours

### DEBT-002: SQL injection risk in SQLite queries
- **Location:** `CursorUsageAdapter.swift:90`, `KiroUsageAdapter.swift:35`, `AntigravityUsageAdapter.swift:68-88`
- **Added:** February 16, 2026
- **Impact:** SQLite keys are currently hardcoded strings so this is safe in practice, but the pattern of string-interpolated SQL is fragile and could become a real vulnerability if keys ever come from user input
- **Proposed Fix:** Add parameterized query support to `SQLiteService` using `sqlite3_bind_text`, update all callers
- **Estimated Effort:** 3 hours

### DEBT-016: Cursor adapter missing "shouldLogout" handling
- **Location:** `PetruUsage/Infrastructure/Providers/Cursor/CursorUsageAdapter.swift:133-145`
- **Added:** February 16, 2026
- **Impact:** The adapter doesn't check for `shouldLogout: true` in refresh responses. The reference plugin (plugin.js lines 107-111) checks this and throws a specific re-auth message
- **Proposed Fix:** After parsing refresh response, check `body.shouldLogout == true` and throw `ProviderError.authExpired("Session expired. Sign in via Cursor app.")`
- **Estimated Effort:** 30 minutes

### DEBT-017: Antigravity adapter missing token cache
- **Location:** `PetruUsage/Infrastructure/Providers/Antigravity/AntigravityUsageAdapter.swift`
- **Added:** February 16, 2026
- **Impact:** No caching of refreshed Google OAuth tokens between fetch cycles, causing unnecessary token refreshes and API calls. The reference plugin (plugin.js lines 150-174) caches tokens in a file with expiration
- **Proposed Fix:** Cache refreshed access token and its expiration in UserDefaults or a file, check cache before refreshing
- **Estimated Effort:** 1 hour

### DEBT-018: Unsafe force-unwrap in Antigravity token expiry check
- **Location:** `PetruUsage/Infrastructure/Providers/Antigravity/AntigravityUsageAdapter.swift:38`
- **Added:** February 16, 2026
- **Impact:** `proto.expirySeconds!` force-unwraps after a nil check, but in a compound `||` condition. While logically safe (short-circuit), it's fragile and could crash if refactored
- **Proposed Fix:** Use `if let` or optional map: `proto.expirySeconds.map({ $0 > Date().timeIntervalSince1970 }) ?? true`
- **Estimated Effort:** 15 minutes

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
- **Location:** `ClaudeUsageAdapter.swift:24-27`, `CursorUsageAdapter.swift:38-42`, `CodexUsageAdapter.swift:24-29`
- **Added:** February 16, 2026
- **Impact:** All adapters use `try?` to silently swallow refresh errors. Users see generic errors without knowing the refresh specifically failed. Reference plugins log these failures
- **Proposed Fix:** Log refresh failures (os_log or print for debug builds), and propagate specific error messages (e.g., "Token refresh failed: invalid_grant") to the UI
- **Estimated Effort:** 2 hours

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
- **Location:** `ClaudeUsageAdapter.swift:53-58`, `CodexUsageAdapter.swift:131-147`, `KiroUsageAdapter.swift:86-92`
- **Added:** February 16, 2026
- **Impact:** Adapters use `FileManager.default` directly, bypassing the hexagonal architecture. Makes credential loading untestable without real files on disk
- **Proposed Fix:** Create a `FileSystemPort` protocol with `fileExists(atPath:)`, `contents(atPath:)` methods; inject into adapters
- **Estimated Effort:** 2 hours

### DEBT-023: ProtobufDecoder inline in Antigravity adapter
- **Location:** `PetruUsage/Infrastructure/Providers/Antigravity/AntigravityUsageAdapter.swift:288-356`
- **Added:** February 16, 2026
- **Impact:** Protobuf varint decoder is defined in the same file as business logic, with unexplained magic field numbers (1, 3, 4, 6). Hard to test independently
- **Proposed Fix:** Extract `ProtobufDecoder` to its own file under `Presentation/Helpers/` or `Infrastructure/`, add comments explaining the protobuf schema fields, and add unit tests
- **Estimated Effort:** 1 hour

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

### DEBT-035: No logging infrastructure
- **Location:** Project-wide
- **Added:** February 16, 2026
- **Impact:** No `os_log` or `Logger` usage anywhere. All errors are silently swallowed or returned as strings. Makes debugging production issues very difficult
- **Proposed Fix:** Add `os.Logger` instances per adapter/service for structured logging with appropriate log levels
- **Estimated Effort:** 2 hours

---

## Resolved Debt (Last 30 Days)

| ID | Title | Resolved | Resolution |
|----|-------|----------|------------|
| - | - | - | - |
