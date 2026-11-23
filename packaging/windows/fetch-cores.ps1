<#
.SYNOPSIS
    Downloads official Xray-core, sing-box, and GeoIP/GeoSite routing databases for Next N.
.PARAMETER OutputDir
    Target application directory where bin/ will be created.
.PARAMETER Arch
    Target Windows architecture: x64, arm64, or x86.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OutputDir,

    [ValidateSet("x64", "arm64", "x86")]
    [string]$Arch = "x64",

    [string]$XrayVersion = "",
    [string]$SingBoxVersion = ""
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$headers = @{
    "User-Agent" = "NextN-Builder/1.0"
    "Accept"     = "application/vnd.github+json"
}
if ($env:GITHUB_TOKEN) {
    $headers["Authorization"] = "Bearer $env:GITHUB_TOKEN"
}

function Get-LatestReleaseTag([string]$Repo) {
    $resp = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers $headers
    return $resp.tag_name
}

function Invoke-DownloadFile([string]$Url, [string]$Dest) {
    Write-Host "  -> Downloading $Url"
    $parent = Split-Path -Parent $Dest
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }

    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        try {
            if ($curl) {
                & $curl -fsSL --retry 3 --retry-delay 2 -A "NextN-Builder/1.0" -o $Dest $Url
                if ($LASTEXITCODE -eq 0 -and (Test-Path $Dest) -and ((Get-Item $Dest).Length -gt 0)) {
                    return
                }
            }
            else {
                Invoke-WebRequest -Uri $Url -OutFile $Dest -Headers @{ "User-Agent" = "NextN-Builder/1.0" } -UseBasicParsing
                if ((Test-Path $Dest) -and ((Get-Item $Dest).Length -gt 0)) {
                    return
                }
            }
        }
        catch {
            Write-Warning "  Attempt $attempt failed for $Url : $($_.Exception.Message)"
        }
        Start-Sleep -Seconds (2 * $attempt)
    }
    throw "Failed to download $Url after 5 attempts."
}

$binDir  = Join-Path $OutputDir "bin"
$xrayDir = Join-Path $binDir "xray"
$singDir = Join-Path $binDir "sing_box"
$srssDir = Join-Path $binDir "srss"
$tmpDir  = Join-Path ([System.IO.Path]::GetTempPath()) ("nextn-cores-" + [Guid]::NewGuid().ToString("N"))

New-Item -ItemType Directory -Force -Path $xrayDir, $singDir, $srssDir, $tmpDir | Out-Null

try {
    # 1. Xray-core
    $xrayTag = if ($XrayVersion) { "v$($XrayVersion.TrimStart('v'))" } else { Get-LatestReleaseTag "XTLS/Xray-core" }
    $xrayAsset = switch ($Arch) {
        "x64"   { "Xray-windows-64.zip" }
        "arm64" { "Xray-windows-arm64-v8a.zip" }
        "x86"   { "Xray-windows-32.zip" }
    }
    Write-Host "[1/3] Fetching Xray-core ($xrayTag / $Arch)..."
    $xrayZip = Join-Path $tmpDir "xray.zip"
    Invoke-DownloadFile "https://github.com/XTLS/Xray-core/releases/download/$xrayTag/$xrayAsset" $xrayZip
    Expand-Archive -Path $xrayZip -DestinationPath (Join-Path $tmpDir "xray") -Force
    Copy-Item (Join-Path $tmpDir "xray\xray.exe") (Join-Path $xrayDir "xray.exe") -Force

    # 2. sing-box
    $singTag = if ($SingBoxVersion) { "v$($SingBoxVersion.TrimStart('v'))" } else { Get-LatestReleaseTag "SagerNet/sing-box" }
    $singVerClean = $singTag.TrimStart('v')
    $singArch = switch ($Arch) {
        "x64"   { "amd64" }
        "arm64" { "arm64" }
        "x86"   { "386" }
    }
    Write-Host "[2/3] Fetching sing-box ($singTag / $Arch)..."
    $singZip = Join-Path $tmpDir "sing-box.zip"
    Invoke-DownloadFile "https://github.com/SagerNet/sing-box/releases/download/$singTag/sing-box-$singVerClean-windows-$singArch.zip" $singZip
    Expand-Archive -Path $singZip -DestinationPath (Join-Path $tmpDir "sing-box") -Force
    $singExe = Get-ChildItem (Join-Path $tmpDir "sing-box") -Recurse -Filter "sing-box.exe" | Select-Object -First 1
    if (-not $singExe) { throw "sing-box.exe not found inside archive" }
    Copy-Item $singExe.FullName (Join-Path $singDir "sing-box.exe") -Force

    $cronet = Get-ChildItem (Join-Path $tmpDir "sing-box") -Recurse -Filter "libcronet*.dll" | Select-Object -First 1
    if ($cronet) {
        Copy-Item $cronet.FullName (Join-Path $singDir "libcronet.dll") -Force
    }

    # 3. GeoIP / GeoSite / sing-box SRS rulesets
    Write-Host "[3/3] Fetching GeoIP, GeoSite, and sing-box rule-sets..."
    Invoke-DownloadFile "https://github.com/Loyalsoldier/V2ray-rules-dat/releases/latest/download/geosite.dat" (Join-Path $binDir "geosite.dat")
    Invoke-DownloadFile "https://github.com/Loyalsoldier/V2ray-rules-dat/releases/latest/download/geoip.dat" (Join-Path $binDir "geoip.dat")
    Invoke-DownloadFile "https://raw.githubusercontent.com/Loyalsoldier/geoip/release/geoip-only-cn-private.dat" (Join-Path $binDir "geoip-only-cn-private.dat")
    Invoke-DownloadFile "https://raw.githubusercontent.com/Loyalsoldier/geoip/release/Country.mmdb" (Join-Path $binDir "Country.mmdb")
    Invoke-DownloadFile "https://github.com/MetaCubeX/meta-rules-dat/releases/latest/download/geoip.metadb" (Join-Path $binDir "geoip.metadb")

    $geoipSrs = @(
        "geoip-private.srs", "geoip-cn.srs", "geoip-facebook.srs", "geoip-fastly.srs",
        "geoip-google.srs", "geoip-netflix.srs", "geoip-telegram.srs", "geoip-twitter.srs"
    )
    foreach ($f in $geoipSrs) {
        Invoke-DownloadFile "https://raw.githubusercontent.com/2dust/sing-box-rules/refs/heads/rule-set-geoip/$f" (Join-Path $srssDir $f)
    }

    $geositeSrs = @(
        "geosite-cn.srs", "geosite-gfw.srs", "geosite-google.srs", "geosite-greatfire.srs",
        "geosite-geolocation-cn.srs", "geosite-category-ads-all.srs", "geosite-private.srs"
    )
    foreach ($f in $geositeSrs) {
        Invoke-DownloadFile "https://raw.githubusercontent.com/2dust/sing-box-rules/refs/heads/rule-set-geosite/$f" (Join-Path $srssDir $f)
    }

    Write-Host "[OK] Cores and routing databases ready in $binDir"
}
finally {
    if (Test-Path $tmpDir) {
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $tmpDir
    }
}
