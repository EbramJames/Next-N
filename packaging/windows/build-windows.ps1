<#
.SYNOPSIS
    Builds Next N for Windows, bundles Xray-core + sing-box + Geo rules,
    and produces both an NSIS Windows Installer (.exe) and a Portable archive (.zip).
#>
[CmdletBinding()]
param(
    [ValidateSet("x64", "arm64", "x86")]
    [string]$Arch = "x64",

    [string]$Version = "1.0.0",

    [switch]$SkipCoreDownload,
    [switch]$SkipInstaller,
    [switch]$SkipPortable
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$rid = "win-$Arch"
$distDir = Join-Path $repoRoot "dist"
$stageDir = Join-Path $distDir "stage-$rid"
$portableDir = Join-Path $distDir "NextN-windows-$Arch-portable"

# Locate dotnet CLI (supports both system PATH and user-local ~/.dotnet)
$dotnet = Get-Command dotnet -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
if (-not $dotnet -and (Test-Path "$env:USERPROFILE\.dotnet\dotnet.exe")) {
    $dotnet = "$env:USERPROFILE\.dotnet\dotnet.exe"
    $env:DOTNET_ROOT = "$env:USERPROFILE\.dotnet"
}
if (-not $dotnet) { throw "dotnet SDK not found on PATH or in $env:USERPROFILE\.dotnet" }

Write-Host "============================================================"
Write-Host " Building Next N v$Version for Windows ($rid)"
Write-Host "============================================================"

New-Item -ItemType Directory -Force -Path $distDir | Out-Null
if (Test-Path $stageDir) { Remove-Item -Recurse -Force $stageDir }
New-Item -ItemType Directory -Force -Path $stageDir | Out-Null

# 1. Publish NextN.Desktop (self-contained)
Write-Host "[1/4] Publishing NextN.Desktop ($rid)..."
& $dotnet publish (Join-Path $repoRoot "src\NextN.Desktop\NextN.Desktop.csproj") `
    -c Release -r $rid `
    -p:SelfContained=true `
    -p:PublishSingleFile=false `
    -p:Version=$Version `
    -o $stageDir
if ($LASTEXITCODE -ne 0) { throw "NextN.Desktop publish failed" }

# 2. Publish NextN.Updater (self-contained, trimmed)
Write-Host "[2/4] Publishing NextN.Updater ($rid)..."
& $dotnet publish (Join-Path $repoRoot "src\NextN.Updater\NextN.Updater.csproj") `
    -c Release -r $rid `
    -p:SelfContained=true `
    -p:PublishSingleFile=true `
    -p:PublishTrimmed=true `
    -p:Version=$Version `
    -o $stageDir
if ($LASTEXITCODE -ne 0) { throw "NextN.Updater publish failed" }

# Strip debug symbols
Get-ChildItem -Path $stageDir -Recurse -Filter "*.pdb" | Remove-Item -Force -ErrorAction SilentlyContinue

# 3. Bundle Xray-core, sing-box, and GeoIP/GeoSite rules
if (-not $SkipCoreDownload) {
    Write-Host "[3/4] Bundling Xray-core, sing-box, and routing assets..."
    & (Join-Path $PSScriptRoot "fetch-cores.ps1") -OutputDir $stageDir -Arch $Arch
}
else {
    Write-Host "[3/4] Skipping core download (-SkipCoreDownload specified)."
}

# 4a. Build NSIS Windows Installer (.exe)
if (-not $SkipInstaller) {
    $makensis = Get-Command makensis -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
    if (-not $makensis -and (Test-Path "C:\Program Files (x86)\NSIS\makensis.exe")) {
        $makensis = "C:\Program Files (x86)\NSIS\makensis.exe"
    }
    if (-not $makensis -and (Test-Path "C:\Program Files\NSIS\makensis.exe")) {
        $makensis = "C:\Program Files\NSIS\makensis.exe"
    }
    if (-not $makensis) {
        throw "NSIS (makensis.exe) not found. Install NSIS 3 to compile the Windows Installer."
    }

    $installerOut = Join-Path $distDir "NextN-Setup-$Arch.exe"
    Write-Host "[4/4] Compiling NSIS Windows Installer -> $installerOut"
    & $makensis `
        "/DAPP_VERSION=$Version" `
        "/DAPP_ARCH=$Arch" `
        "/DSTAGE_DIR=$stageDir" `
        "/DOUTPUT_EXE=$installerOut" `
        (Join-Path $PSScriptRoot "NextN.nsi")
    if ($LASTEXITCODE -ne 0) { throw "NSIS installer compilation failed" }
    Write-Host "  [OK] Installer built: $installerOut"
}

# 4b. Build Portable ZIP
if (-not $SkipPortable) {
    $zipOut = Join-Path $distDir "NextN-windows-$Arch-portable.zip"
    if (Test-Path $zipOut) { Remove-Item -Force $zipOut }
    if (Test-Path $portableDir) { Remove-Item -Recurse -Force $portableDir }
    Copy-Item -Recurse -Force $stageDir $portableDir
    Write-Host "[4/4] Packaging Portable ZIP -> $zipOut"
    Compress-Archive -Path $portableDir -DestinationPath $zipOut -CompressionLevel Optimal
    Remove-Item -Recurse -Force $portableDir
    Write-Host "  [OK] Portable archive built: $zipOut"
}

Write-Host "============================================================"
Write-Host " Windows packaging completed cleanly!"
Write-Host "============================================================"
Get-ChildItem $distDir -File | Select-Object Name, @{N='SizeMB';E={[Math]::Round($_.Length/1MB,2)}} | Format-Table -AutoSize
