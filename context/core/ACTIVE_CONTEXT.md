# Active Context

**Current Focus:** Fix non-working provider adapters (P0 debt)
**Started:** February 16, 2026
**Target Completion:** Next session
**Priority:** P0

## Scope

### Files Being Modified
- `PetruUsage/Infrastructure/Providers/Cursor/CursorUsageAdapter.swift` — Fix billingCycleEnd type, planUsage scaling, add Enterprise handling, add shouldLogout check
- `PetruUsage/Infrastructure/Providers/Antigravity/AntigravityUsageAdapter.swift` — Debug protobuf decoding, add token cache, add User-Agent, fix force-unwrap
- `PetruUsage/Infrastructure/Providers/Kiro/KiroUsageAdapter.swift` — Debug SQLite key/schema, verify JSON parsing
- `PetruUsage/Infrastructure/Providers/Claude/ClaudeUsageAdapter.swift` — Add plan/subscription display, add User-Agent, add credential persistence after refresh
- `PetruUsage/Infrastructure/Providers/Codex/CodexUsageAdapter.swift` — Add User-Agent, verify with live data

### Files to Reference (Read-Only)
- `/Users/edison/Documents/Projects/Github/openusage/plugins/claude/plugin.js` — Reference implementation
- `/Users/edison/Documents/Projects/Github/openusage/plugins/cursor/plugin.js` — Reference implementation
- `/Users/edison/Documents/Projects/Github/openusage/plugins/codex/plugin.js` — Reference implementation
- `/Users/edison/Documents/Projects/Github/openusage/plugins/antigravity/plugin.js` — Reference implementation

### Files Out of Scope
- `PetruUsage/Domain/` — Models and ports are stable
- `PetruUsage/Presentation/` — UI is functional, polish comes later
- `PetruUsage/Application/` — Use cases work correctly

## Requirements
- [x] Menu bar icon appears, no dock icon
- [x] Popover shows provider cards
- [ ] Claude provider shows session/weekly usage with plan label
- [ ] Cursor provider shows plan usage, credit grants, billing cycle
- [ ] Codex provider shows session/weekly/credits
- [ ] Antigravity provider shows per-model Gemini quotas with reset timers
- [ ] Kiro provider shows cached usage breakdowns
- [x] Settings window with provider toggles
- [x] Auto-refresh on configurable interval

## Technical Approach
Debug each failing adapter by:
1. Inspecting actual SQLite data and credential files on disk
2. Comparing parsed values against what the reference JS plugins expect
3. Making test API calls with real tokens to verify endpoints and response formats
4. Fixing type mismatches, missing headers, and logic gaps

## Patterns to Follow
- Match the reference OpenUsage plugins exactly for API calls, headers, and response parsing
- Keep adapter changes minimal and focused on correctness
- Add unit tests with sample API response data for each fix

## Out of Scope
- Antigravity LS probing (DEBT-010) — complex feature, separate task
- Cursor Enterprise support (DEBT-009) — separate task after basic adapter works
- Logging infrastructure (DEBT-035) — separate task
- UI polish, app icon, settings improvements

## Open Questions
- What is the exact JSON structure of Kiro's `kiro.resourceNotifications.usageState` key?
- Does the Cursor API return planUsage values in cents or dollars?
- Does `billingCycleEnd` come back as a String or Number from Cursor's Connect API?

## Acceptance Criteria
- [ ] All 5 providers display data when credentials exist on machine
- [ ] Claude shows session %, weekly %, and plan label (Pro/Team/etc.)
- [ ] Cursor shows plan usage with billing cycle reset timer
- [ ] Codex shows session/weekly percentages
- [ ] Antigravity shows per-model quota percentages
- [ ] Kiro shows usage breakdowns from cached state
- [ ] Graceful error messages when credentials are missing or expired
- [x] All tests pass
- [x] Build succeeds
