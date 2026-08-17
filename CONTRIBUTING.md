# Contributing to Hermes Menu Bar

Thank you for your interest in contributing to **Hermes Menu Bar**! We welcome bug reports, feature requests, documentation improvements, and pull requests.

---

## 🛠 Development Setup

### Prerequisites
- macOS 13.0 (Ventura) or newer
- Xcode 15+ / Command Line Tools (`xcode-select --install`)
- Swift 5.9+ or Swift 6.0+

### Building Locally

Clone the repository and build using Swift Package Manager or the build script:

```bash
git clone https://github.com/caesar915-hub/hermes-menubar.git
cd hermes-menubar

# Quick build and launch
./build.sh

# Or build universal binary without launching
./build.sh --universal --no-launch
```

---

## 📐 Architecture Overview

- **`Models/`**: `Profile.swift`, `GatewayState.swift` — Data structures, status enums, JSON parsing, PID validation.
- **`Services/`**: 
  - `ProfileDiscovery.swift` — Dynamic `~/.hermes/` scanning and model extraction.
  - `ProfileMonitor.swift` — Kernel `kqueue` (`DispatchSource`) event monitoring.
  - `ProcessRunner.swift` — Non-blocking asynchronous CLI execution.
- **`UI/`**: 
  - `ProfileStatusItem.swift` — Custom vector icon drawing, SF Symbols, and status badges.
  - `ProfileMenuBuilder.swift` — AppKit dropdown menus and action handlers.
  - `StatusItemManager.swift` — Multi-icon vs. Single-icon mode coordinator.

---

## 🧪 Guidelines for Pull Requests

1. **Keep it Lightweight**: Hermes Menu Bar is designed to consume <15MB RAM and ~0% idle CPU. Avoid heavy third-party dependencies.
2. **MainActor Safety**: All AppKit UI modifications (`NSStatusItem`, `NSMenu`, `NSImage`) must be executed on the Main Actor.
3. **Installation Agnostic**: Never hardcode user paths; always use `FileManager.default.homeDirectoryForCurrentUser` or environment variables (`HERMES_HOME`, `HERMES_BIN`).
4. **Follow Semantic Commit Messages**: Use prefixes like `feat:`, `fix:`, `docs:`, `refactor:`, `test:`.
