# PetruUsage

## Overview

PetruUsage is a macOS menu bar application that tracks AI coding tool usage limits and reset schedules. It reads locally-stored credentials left by CLI tools (Claude, Cursor, Codex, Antigravity, Kiro) and queries provider APIs for real-time usage data, displaying it in a compact menu bar popover.

## Tech Stack

- **Language:** Swift 5 (Swift 6 toolchain)
- **Framework:** SwiftUI (MenuBarExtra)
- **Platform:** macOS 14+ (Sonoma)
- **Database:** SQLite3 (reading .vscdb files from editor extensions)
- **Key Dependencies:** Zero third-party packages. System frameworks only (SwiftUI, Foundation, Security, SQLite3, ServiceManagement, AppKit)

## Architecture

Hexagonal (Ports & Adapters) architecture. Domain layer defines port protocols, Infrastructure layer implements adapters. Application layer orchestrates via protocols only, using concurrent TaskGroup for parallel provider fetches. Presentation layer uses SwiftUI with @Observable ViewModels.

## Quick Commands

| Action             | Command                                                                                               |
| ------------------ | ----------------------------------------------------------------------------------------------------- |
| Build              | `xcodebuild -project PetruUsage.xcodeproj -scheme PetruUsage build`                                   |
| Test               | `xcodebuild -project PetruUsage.xcodeproj -scheme PetruUsageTests test -destination 'platform=macOS'` |
| Run                | Open `PetruUsage.xcodeproj` in Xcode and run                                                          |
| Regenerate Project | `xcodegen generate`                                                                                   |

## Project Structure

```
PetruUsage/
├── PetruUsage/
│   ├── PetruUsageApp.swift           # @main, MenuBarExtra entry + DI
│   ├── Info.plist                     # LSUIElement = YES
│   ├── Domain/
│   │   ├── Models/                    # Provider, UsageMetric, ProviderStatus, Credential
│   │   └── Ports/                     # Protocol definitions (ports)
│   ├── Application/
│   │   ├── UseCases/                  # FetchAll, FetchProvider, Refresh, Toggle
│   │   └── Services/                  # ProviderRegistry, TokenRefreshService
│   ├── Infrastructure/
│   │   ├── Network/                   # URLSessionHTTPClient
│   │   ├── Persistence/              # SQLiteService, UserDefaultsSettingsAdapter
│   │   ├── Keychain/                  # KeychainService
│   │   └── Providers/                 # Claude, Cursor, Codex, Antigravity, Kiro adapters
│   └── Presentation/
│       ├── ViewModels/                # UsageViewModel, SettingsViewModel
│       ├── Views/                     # MenuBarView, ProviderCardView, SettingsView
│       └── Helpers/                   # JWTDecoder, ColorExtensions, DateFormatting
├── PetruUsageTests/                   # Unit tests
└── project.yml                        # XcodeGen project spec
```

## Conventions

- Use async/await for all asynchronous operations
- All dependencies injected through initializers (constructor injection)
- Domain layer has zero imports beyond Foundation
- Infrastructure adapters implement Domain port protocols
- @Observable for ViewModels, @MainActor for UI-related classes
- Provider-specific logic stays in its adapter file

## Context Files

| File                                 | Purpose                |
| ------------------------------------ | ---------------------- |
| `context/core/SESSION_STATE.md`      | Current session status |
| `context/core/ACTIVE_CONTEXT.md`     | Current focus areas    |
| `context/architecture/SYSTEM_MAP.md` | Detailed architecture  |
| `context/quality/TECHNICAL_DEBT.md`  | Debt registry          |
| `.cursor/rules/project.mdc`          | Cursor AI rules        |

## Current Focus

4 of 5 providers working at runtime (Claude, Codex, Gemini, Kiro). Cursor hidden from UI pending account investigation. Build succeeds, 17 tests pass.

## Important Notes

- App Sandbox is disabled (must read ~/. credential files and ~/Library/Application Support/ databases)
- LSUIElement = YES hides the app from the dock by default
- No API keys or passwords are stored by this app; it reads credentials left by the CLI tools themselves
- Provider APIs may change; adapter implementations mirror the OpenUsage plugin logic
