# PetruUsage

A macOS menu bar app that tracks AI coding tool usage limits and reset schedules in one place.

PetruUsage reads locally-stored credentials left by CLI tools and editor extensions, queries provider APIs for real-time usage data, and displays it in a compact menu bar popover. No API keys or passwords are stored — it piggybacks on credentials already on your machine.

## Supported Providers

| Provider | Data Source | What It Shows |
|----------|------------|---------------|
| **Claude** | `~/.claude/` credentials + Keychain | Session %, weekly %, plan label |
| **Codex** | `~/.codex/` credentials + Keychain | Session %, weekly %, credits |
| **Gemini** | Antigravity extension `state.vscdb` | Per-model quota % with reset timers |
| **Kiro** | Kiro IDE `state.vscdb` + token log | Cached usage breakdowns |
| **Cursor** | Cursor `state.vscdb` | Plan usage, credits (hidden — WIP) |

## Requirements

- macOS 14+ (Sonoma)
- Xcode 16+ (Swift 6 toolchain, Swift 5 language mode)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (for project regeneration)
- At least one supported AI tool installed and authenticated

## Getting Started

```bash
# Clone
git clone git@github.com:petrubear/PetruUsage.git
cd PetruUsage

# Generate Xcode project (if .xcodeproj is missing)
xcodegen generate

# Build
xcodebuild -project PetruUsage.xcodeproj -scheme PetruUsage build

# Test
xcodebuild -project PetruUsage.xcodeproj -scheme PetruUsageTests test -destination 'platform=macOS'

# Run
open PetruUsage.xcodeproj  # then Run in Xcode
```

## How It Works

1. On launch, the app places an icon in the macOS menu bar (no dock icon)
2. Click the icon to open a popover showing all enabled providers
3. Each provider card displays usage metrics, progress bars, and reset timers
4. Data refreshes automatically on a configurable interval (default: 5 minutes)
5. Open Settings to toggle providers, change refresh interval, or configure startup behavior

### Credential Reading

PetruUsage **never stores credentials**. It reads tokens and session data that CLI tools and editor extensions leave on disk:

- **JSON files** in `~/.claude/`, `~/.codex/` (CLI credential files)
- **macOS Keychain** entries created by Claude and Codex CLIs
- **SQLite databases** (`state.vscdb`) from VS Code-based editors (Antigravity, Cursor, Kiro)
- **Protobuf-encoded tokens** decoded inline from Antigravity's state DB

Because of this, the App Sandbox is disabled — the app needs direct filesystem access to `~/` and `~/Library/Application Support/`.

## Architecture

Hexagonal (Ports & Adapters) with four layers:

```
Domain          Models + Port protocols (zero dependencies beyond Foundation)
Application     Use cases + Services (orchestration via protocols)
Infrastructure  Adapters: HTTP client, SQLite, Keychain, per-provider API logic
Presentation    SwiftUI views + @Observable ViewModels
```

All provider fetches run in parallel via Swift `TaskGroup`. Each provider adapter is self-contained — credential reading, token refresh, API calls, and response parsing all live in a single file.

## Project Structure

```
PetruUsage/
├── PetruUsage/
│   ├── PetruUsageApp.swift           # @main entry point + dependency injection
│   ├── Domain/
│   │   ├── Models/                   # Provider, UsageMetric, ProviderStatus, Credential
│   │   └── Ports/                    # Protocol definitions
│   ├── Application/
│   │   ├── UseCases/                 # FetchAll, Refresh, Toggle
│   │   └── Services/                 # ProviderRegistry
│   ├── Infrastructure/
│   │   ├── Network/                  # URLSessionHTTPClient
│   │   ├── Persistence/              # SQLiteService, UserDefaultsSettingsAdapter
│   │   ├── Keychain/                 # KeychainService
│   │   └── Providers/                # Claude, Cursor, Codex, Antigravity, Kiro adapters
│   └── Presentation/
│       ├── ViewModels/               # UsageViewModel, SettingsViewModel
│       ├── Views/                    # MenuBarView, ProviderCardView, SettingsView
│       └── Helpers/                  # JWTDecoder, ColorExtensions, DateFormatting
├── PetruUsageTests/                  # Unit tests (17 tests)
└── project.yml                       # XcodeGen spec
```

## Tech Stack

- **Swift 5** (Swift 6 toolchain)
- **SwiftUI** (MenuBarExtra)
- **Zero third-party dependencies** — system frameworks only (Foundation, SwiftUI, Security, SQLite3, ServiceManagement, AppKit)

## Acknowledgments

Provider adapter logic is based on the [OpenUsage](https://github.com/nicepkg/openusage) VS Code extension plugin system.

## License

Private project.
