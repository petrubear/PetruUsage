# Technical Debt Registry

**Last Updated:** February 16, 2026
**Total Items:** 5
**Critical (P0):** 0

## Priority Definitions

| Priority | Definition | SLA |
|----------|------------|-----|
| P0 | Blocking development or causing incidents | Immediate |
| P1 | Significant impact on velocity | This sprint |
| P2 | Moderate impact, workaround exists | This quarter |
| P3 | Minor, address when convenient | Backlog |

---

## P0 - Critical

None.

---

## P1 - High Priority

### DEBT-001: No credential persistence after token refresh
- **Location:** `PetruUsage/Infrastructure/Providers/Claude/ClaudeUsageAdapter.swift`
- **Added:** February 16, 2026
- **Impact:** Refreshed tokens are not saved back to the credential file/keychain, so tokens may be refreshed repeatedly
- **Proposed Fix:** After successful refresh, write updated credentials back using the same source (file or keychain)
- **Estimated Effort:** 2 hours

### DEBT-002: SQL injection risk in SQLite queries
- **Location:** `PetruUsage/Infrastructure/Providers/Cursor/CursorUsageAdapter.swift:80`
- **Added:** February 16, 2026
- **Impact:** SQLite keys are hardcoded strings so this is currently safe, but the pattern of string-interpolated SQL is fragile
- **Proposed Fix:** Use parameterized queries in SQLiteService (sqlite3_bind_text)
- **Estimated Effort:** 3 hours

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

---

## P3 - Low Priority

### DEBT-005: No error retry mechanism in UI
- **Location:** `PetruUsage/Presentation/Views/ProviderCardView.swift`
- **Added:** February 16, 2026
- **Impact:** When a provider errors, user must wait for auto-refresh or manually refresh all
- **Proposed Fix:** Add per-provider retry button in error state
- **Estimated Effort:** 1 hour

---

## Resolved Debt (Last 30 Days)

| ID | Title | Resolved | Resolution |
|----|-------|----------|------------|
| - | - | - | - |
