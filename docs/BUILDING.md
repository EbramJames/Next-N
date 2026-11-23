# Building & Packaging Next N

## Prerequisites

| Requirement | Version |
| :--- | :--- |
| **.NET SDK** | `10.0.x` |
| **Windows Installer** | NSIS 3 (`makensis.exe`) |
| **macOS DMG** | `create-dmg`, `jq` (via Homebrew) |
| **Linux DEB / RPM** | `dpkg-dev`, `rpmbuild`, `jq`, `curl`, `unzip` |

## Build & Run from Source

```bash
# Clone the repository
git clone https://github.com/EbramJames/Next-N.git
cd Next-N

# Restore & build all projects
dotnet build NextN.sln -c Release

# Run the full unit test suite
dotnet test --project tests/NextN.Core.Tests/NextN.Core.Tests.csproj -c Release

# Launch Next N locally
dotnet run --project src/NextN.Desktop/NextN.Desktop.csproj
```

## Packaging Native Installers

### Windows (NSIS Setup `.exe` + Portable `.zip`)

```powershell
# Builds NextN.exe + NextN.Updater.exe, fetches latest Xray-core, sing-box & Geo rules,
# compiles dist/NextN-Setup-x64.exe and dist/NextN-windows-x64-portable.zip
.\packaging\windows\build-windows.ps1 -Arch x64 -Version 1.0.0
```

Supported `-Arch` values: `x64`, `arm64`, `x86`.

### macOS (`.dmg` Installer)

```bash
dotnet publish src/NextN.Desktop/NextN.Desktop.csproj -c Release -r osx-arm64 -p:SelfContained=true -p:PublishSingleFile=false -o publish/osx-arm64
./packaging/macos/package-osx.sh arm64 publish/osx-arm64 1.0.0
```

### Linux (`.deb`, `.rpm`, and `.AppImage`)

```bash
dotnet publish src/NextN.Desktop/NextN.Desktop.csproj -c Release -r linux-x64 -p:SelfContained=true -p:PublishSingleFile=false -o publish/linux-x64

# Debian / Ubuntu
./packaging/linux/package-debian.sh amd64 publish/linux-x64 1.0.0

# Fedora / RHEL / Rocky / AlmaLinux
./packaging/linux/package-rhel.sh x86_64 publish/linux-x64 1.0.0

# Universal Linux AppImage
./packaging/linux/package-appimage.sh x86_64 publish/linux-x64 1.0.0
```
