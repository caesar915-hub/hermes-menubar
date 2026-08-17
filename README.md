# ⚡️ Hermes Menu Bar for macOS

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![GitHub Release](https://img.shields.io/github/v/release/caesar915-hub/hermes-menubar?color=blue&label=Release)](https://github.com/caesar915-hub/hermes-menubar/releases)
[![Homebrew Tap](https://img.shields.io/badge/Homebrew-caesar915--hub%2Ftap-gold.svg)](https://github.com/caesar915-hub/homebrew-tap)
[![Platform](https://img.shields.io/badge/Platform-macOS%2013%2B%20(Ventura%20%7C%20Sonoma%20%7C%20Sequoia%20%7C%20Tahoe)-black.svg)](https://apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B%20%7C%206.0%2B-orange.svg)](https://swift.org)
[![Architecture](https://img.shields.io/badge/Architecture-Universal%20(Apple%20Silicon%20%26%20Intel)-purple.svg)](https://apple.com)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

A native, lightweight macOS menu bar utility for [Hermes Agent](https://github.com/NousResearch/Hermes-Agent), inspired by [exelban/stats](https://github.com/exelban/stats).

Monitor real-time **ON/OFF** status indicators for all your Hermes profiles and Telegram gateways directly in the macOS top menu bar, with interactive controls to start, stop, restart, inspect logs, and open chats.

---

## ✨ Features

- **🎯 Independent Per-Profile Menu Bar Items**:
  - Each profile (`default`, `my-man`, `marketing`, etc.) can display its own independent status item in the top bar.
  - Automatically discovers newly created profiles in `~/.hermes/profiles/` in real-time.
- **🟢 Instant Visual ON / OFF Indicators**:
  - **🟢 Green Dot**: Profile is actively running with Telegram gateway connected & polling.
  - **⚪ Gray Dot**: Profile gateway is stopped (OFF).
  - **🟡 Yellow Dot**: Transitioning or reconnecting.
  - **🔴 Red Dot**: Gateway or network error.
- **⚡️ Interactive Dropdown Context Menu**:
  - **Live Telemetry**: Current status, active PID, and configured LLM model.
  - **Process Controls**: Non-blocking `Start`, `Stop`, and `Restart` actions.
  - **Quick Launchers**:
    - 📱 **Open Telegram App** (brings native Telegram.app to front or falls back to web)
    - 💬 **Open Chat in Terminal** (`hermes --profile <name>`)
    - 📜 **Tail Live Logs** (`tail -f gateway.log`)
    - 📁 **Open Profile Folder** in Finder
  - **Batch Controls**: `Start All Profiles`, `Stop All Profiles`, `Restart All Profiles`.
- **🎛 Smart Display Modes**:
  - **Multi-Icon Mode (Default)**: Separate icons for each profile (`DEF`, `MM`, `MKT`).
  - **Single Combined Mode**: Compact unified icon (`⚡️ Hermes 🟢 [3/3]`) to save menu bar space on notched MacBooks.
- **🚀 Ultra-Lightweight Execution**:
  - Pure native Swift & AppKit (`LSUIElement = true`).
  - **< 15 MB RAM** resident memory footprint.
  - **~0% idle CPU**: Uses kernel `kqueue` (`DispatchSource`) event monitoring on `gateway_state.json` instead of aggressive polling loops.

---

---

## 🛠 Installation

### Option 1: Homebrew (Recommended)

```bash
# Install via official Homebrew tap
brew install caesar915-hub/tap/hermes-menubar
```

### Option 2: Quick Install (Build from Source)

Clone the repository and run the build script:

```bash
git clone https://github.com/caesar915-hub/hermes-menubar.git
cd hermes-menubar
./build.sh
```

---

## 💻 Terminal Commands (Lowercase CLI)

You can control and query the menu bar app directly from your terminal using clean, lowercase commands:

| Action | Terminal Command |
|---|---|
| **Check Status & PID** | `hermes-menubar` *(or `hermes-menubar status`)* |
| **Launch App** | `hermes-menubar start` |
| **Stop / Quit App** | `hermes-menubar stop` |
| **Restart App** | `hermes-menubar restart` |
| **Tail Gateway Logs** | `hermes-menubar logs` |
| **CLI Help** | `hermes-menubar help` |

---

## ⚙️ Configuration & Environment

`HermesMenuBar` is completely installation-agnostic and automatically scans standard locations. If you use custom paths, you can optionally configure environment variables:

| Environment Variable | Description | Default |
|---|---|---|
| `HERMES_HOME` | Custom Hermes home directory containing `profiles/` | `~/.hermes` |
| `HERMES_BIN` | Custom path to the `hermes` CLI executable | Auto-discovered from `~/.local/bin`, `~/.hermes/.../venv/bin`, Homebrew, or system `$PATH` |

---

## 🖥 Requirements

- **Operating System**: macOS 13.0 (Ventura) or newer (Sonoma, Sequoia, Tahoe).
- **Architecture**: Universal (Apple Silicon M1/M2/M3/M4 & Intel x86_64).
- **Hermes Agent**: Any installation of Hermes Agent CLI (`v0.10+`).

---

## 🏗 Architecture

```
HermesMenuBar
├── Models/
│   ├── Profile.swift          # Profile domain model and PID liveness validation
│   └── GatewayState.swift     # JSON decodable schema for gateway_state.json
├── Services/
│   ├── ProfileDiscovery.swift # Dynamic ~/.hermes/ directory & profile scanner
│   ├── ProfileMonitor.swift   # Kernel kqueue file watcher + fallback safety timer
│   └── ProcessRunner.swift    # Non-blocking async CLI execution engine
└── UI/
    ├── StatusItemManager.swift# Multi-item & single-item mode coordinator
    ├── ProfileStatusItem.swift# Custom vector drawing & status dot rendering
    └── ProfileMenuBuilder.swift# Native AppKit context menu builder
```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
