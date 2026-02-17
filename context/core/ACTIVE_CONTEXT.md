# Active Context

**Current Focus:** Post-implementation testing and polish
**Started:** February 16, 2026
**Target Completion:** Ongoing
**Priority:** P1

## Scope

### Files Being Modified
- None currently (initial implementation complete)

### Files to Reference (Read-Only)
- `PetruUsage/Infrastructure/Providers/*/` - Provider adapters for debugging
- `PetruUsage/Presentation/Views/` - UI views for visual polish
- `PetruUsage/PetruUsageApp.swift` - DI wiring and app entry point

### Files Out of Scope
- `project.yml` - Project generation config, stable
- `PetruUsage/Domain/` - Domain models and ports, stable

## Requirements
- [x] Menu bar icon appears, no dock icon
- [x] Popover shows provider cards with usage data
- [ ] Claude provider shows session/weekly usage with reset timers
- [ ] Cursor provider shows plan usage and credit grants
- [ ] Codex provider shows session/weekly/credits
- [ ] Antigravity provider shows per-model Gemini quotas
- [ ] Kiro provider shows cached usage data
- [x] Settings window with provider toggles
- [x] Auto-refresh on configurable interval

## Technical Approach
All providers implemented following the OpenUsage plugin patterns. Each adapter reads local credentials (files, keychain, or SQLite databases), refreshes tokens if needed, and calls the provider's usage API. Results are displayed as progress bars with percentage, reset timers, and plan info.

## Out of Scope
- API key input (app reads existing credentials only)
- Notifications/alerts for high usage
- Historical usage tracking
- Multi-account support per provider

## Open Questions
- Should the settings window use `Settings` scene instead of `Window` scene?
- Should auto-refresh pause when the popover is closed?

## Acceptance Criteria
- [x] All tests pass
- [x] Build succeeds
- [ ] Each provider displays correct data when credentials exist
- [ ] Graceful error messages when credentials are missing
- [ ] Settings persist across app restarts
