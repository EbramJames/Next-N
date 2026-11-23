# Next N — Architecture Overview

Next N is built on **.NET 10** and **Avalonia UI 12**, engineered as a clean, unified cross-platform proxy workstation for Windows, macOS, and Linux.

## Solution Layout

```text
Next-N/
├── src/
│   ├── NextN.Core/        # Domain models, protocol URI codecs, Xray/sing-box config builders,
│   │                      # routing/DNS/TUN managers, SQLite storage, ReactiveUI ViewModels
│   ├── NextN.UdpTest/     # Low-level SOCKS5 UDP relay test client (DNS, NTP, STUN, MCBE)
│   ├── NextN.Desktop/     # Unified cross-platform Avalonia 12 desktop UI & platform services
│   └── NextN.Updater/     # Standalone process-safe updater & elevation restart helper
├── tests/
│   └── NextN.Core.Tests/  # TUnit automated verification suite (137+ tests)
├── packaging/
│   ├── windows/           # NSIS MUI2 Windows installer, core bundler, build scripts
│   ├── macos/             # macOS .app bundle & DMG packager
│   └── linux/             # Debian (.deb), RPM (.rpm), and universal AppImage packagers
└── docs/                  # Architecture and build documentation
```

## Key Architectural Principles

### 1. Single Unified Cross-Platform UI (`NextN.Desktop`)
Instead of maintaining divergent platform-specific UI codebases, Next N renders a single Avalonia 12 application across Windows, macOS, and Linux using compiled bindings (`AvaloniaUseCompiledBindingsByDefault`) and ReactiveUI MVVM.

- **Design Tokens (`Themes/NextNTheme.axaml`)**: Adaptive `Dark` and `Light` brush dictionaries power the obsidian/indigo dark default and clean light mode, alongside Semi Avalonia accent palettes (`Aquatic`, `Desert`, `Dusk`, `NightSky`).
- **Sidebar Workspace Shell (`Views/MainWindow.axaml`)**: Consolidates connection status, workspace navigation (`Servers`, `Proxies`, `Connections`, `Logs`), quick configuration shortcuts (`Subscriptions`, `Routing`, `DNS`, `Settings`), and top-bar actions (`+ Add Server`, `Subscriptions`, `Reload`, overflow menu).
- **Bottom Control Dock (`Views/StatusBarView.axaml`)**: Keeps System Proxy mode, Routing ruleset, TUN shield toggle, local/LAN ports, and live speed telemetry permanently accessible.

### 2. Zero-Submodule Platform Layer (`NextN.Desktop/Platform`)
Global hotkeys on Windows are handled by `Win32GlobalHotkeyEngine` using source-generated `[LibraryImport]` P/Invoke calls (`RegisterHotKey` / `UnregisterHotKey`) running on a dedicated Win32 message thread, eliminating external git submodule dependencies and guaranteeing hotkeys continue working even when minimized to the system tray.

### 3. Configuration & Data Isolation (Installed vs. Portable)
- **Installed Mode** (Windows NSIS Installer, macOS `.app`, Linux `.deb`/`.rpm`/`.AppImage`): Ships a `NotStoreConfigHere.txt` sentinel in the application directory so all user profiles, SQLite databases (`guiNDB.db`), logs, and runtime configs live safely in `%LOCALAPPDATA%\NextN` (Windows), `~/Library/Application Support/NextN` (macOS), or `~/.local/share/NextN` (Linux). This keeps profiles intact across upgrades and consistent when relaunching elevated for TUN mode.
- **Portable Mode**: Removing `NotStoreConfigHere.txt` (default in `-portable.zip`) stores all user data alongside `NextN.exe`.

### 4. Protocol & Core Engine (`NextN.Core`)
- Generates validated runtime configurations for **Xray-core**, **sing-box**, and **mihomo**.
- Supports VLESS (including Reality / XHTTP / Vision), VMess, Trojan, Shadowsocks, Hysteria2, WireGuard, TUIC, AnyTLS, Naive, MASQUE, SOCKS, HTTP, Policy Groups, and Proxy Chains.
- Exports native `nextn://` internal URIs while retaining backward-compatible import support for legacy `v2rayn://` URIs.
- Uses parameterized SQLite queries (`SQLiteHelper.QueryAsync<T>(sql, args)`) to protect server filtering and storage operations.
