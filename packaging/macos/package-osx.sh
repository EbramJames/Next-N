#!/usr/bin/env bash
# ============================================================================
# Next N — macOS .app Bundle, .dmg Installer & .zip Archive Packager
# Works natively on macOS (create-dmg / hdiutil) AND cross-platform on Linux
# (xorriso HFS+ + libdmg-hfsplus UDZO + rcodesign ad-hoc signing).
# Usage: ./packaging/macos/package-osx.sh <arm64|x64> <publish-dir> <version>
# ============================================================================
set -euo pipefail

ARCH="${1:-arm64}"
PUBLISH_DIR="${2:?Publish directory is required}"
VERSION="${3:-1.0.0}"
VERSION="${VERSION#v}"

case "$ARCH" in
  arm64)
    XRAY_ASSET="Xray-macos-arm64-v8a.zip"
    SING_ARCH="arm64"
    OUT_ARCH="arm64"
    ;;
  x64|64)
    XRAY_ASSET="Xray-macos-64.zip"
    SING_ARCH="amd64"
    OUT_ARCH="x64"
    ;;
  *)
    echo "Unsupported macOS arch: $ARCH (use arm64|x64)" >&2
    exit 1
    ;;
esac

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DIST_DIR="$REPO_ROOT/dist"
mkdir -p "$DIST_DIR"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

APP_DIR="$WORKDIR/Next N.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"
mkdir -p "$MACOS_DIR/bin/xray" "$MACOS_DIR/bin/sing_box" "$MACOS_DIR/bin/srss" "$RES_DIR"

echo "[1/5] Staging Next N macOS desktop binaries ($OUT_ARCH)..."
cp -a "$PUBLISH_DIR/." "$MACOS_DIR/"
chmod 0755 "$MACOS_DIR/NextN"
[[ -f "$MACOS_DIR/NextN.Updater" ]] && chmod 0755 "$MACOS_DIR/NextN.Updater" || true
echo "Installed by Next N macOS Bundle. User data is stored in Application Support." > "$MACOS_DIR/NotStoreConfigHere.txt"

if [[ -f "$MACOS_DIR/NextN.icns" ]]; then
  cp -f "$MACOS_DIR/NextN.icns" "$RES_DIR/AppIcon.icns"
elif [[ -f "$REPO_ROOT/src/NextN.Desktop/NextN.icns" ]]; then
  cp -f "$REPO_ROOT/src/NextN.Desktop/NextN.icns" "$RES_DIR/AppIcon.icns"
fi

echo "[2/5] Downloading official Xray-core, sing-box, and Geo assets..."
gh_api() {
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    curl -fsSL --retry 4 --retry-delay 2 -H "Authorization: Bearer ${GITHUB_TOKEN}" -H "User-Agent: NextN-Packager" "$1"
  else
    curl -fsSL --retry 4 --retry-delay 2 -H "User-Agent: NextN-Packager" "$1"
  fi
}
fetch_file() {
  curl -fsSL --retry 4 --retry-delay 2 -o "$2" "$1"
}

XRAY_TAG="$(gh_api https://api.github.com/repos/XTLS/Xray-core/releases/latest | jq -re '.tag_name')"
fetch_file "https://github.com/XTLS/Xray-core/releases/download/${XRAY_TAG}/${XRAY_ASSET}" "$WORKDIR/xray.zip"
unzip -q "$WORKDIR/xray.zip" -d "$WORKDIR/xray"
install -m 0755 "$WORKDIR/xray/xray" "$MACOS_DIR/bin/xray/xray"

SING_TAG="$(gh_api https://api.github.com/repos/SagerNet/sing-box/releases/latest | jq -re '.tag_name')"
SING_VER="${SING_TAG#v}"
fetch_file "https://github.com/SagerNet/sing-box/releases/download/${SING_TAG}/sing-box-${SING_VER}-darwin-${SING_ARCH}.tar.gz" "$WORKDIR/singbox.tar.gz"
tar -C "$WORKDIR" -xzf "$WORKDIR/singbox.tar.gz"
SING_BIN="$(find "$WORKDIR" -type f -name 'sing-box' | head -n1)"
install -m 0755 "$SING_BIN" "$MACOS_DIR/bin/sing_box/sing-box"

fetch_file "https://github.com/Loyalsoldier/V2ray-rules-dat/releases/latest/download/geosite.dat" "$MACOS_DIR/bin/geosite.dat"
fetch_file "https://github.com/Loyalsoldier/V2ray-rules-dat/releases/latest/download/geoip.dat" "$MACOS_DIR/bin/geoip.dat"
fetch_file "https://raw.githubusercontent.com/Loyalsoldier/geoip/release/geoip-only-cn-private.dat" "$MACOS_DIR/bin/geoip-only-cn-private.dat"
fetch_file "https://raw.githubusercontent.com/Loyalsoldier/geoip/release/Country.mmdb" "$MACOS_DIR/bin/Country.mmdb"
fetch_file "https://github.com/MetaCubeX/meta-rules-dat/releases/latest/download/geoip.metadb" "$MACOS_DIR/bin/geoip.metadb"

for f in geoip-private.srs geoip-cn.srs geoip-facebook.srs geoip-fastly.srs geoip-google.srs geoip-netflix.srs geoip-telegram.srs geoip-twitter.srs; do
  fetch_file "https://raw.githubusercontent.com/2dust/sing-box-rules/refs/heads/rule-set-geoip/$f" "$MACOS_DIR/bin/srss/$f"
done
for f in geosite-cn.srs geosite-gfw.srs geosite-google.srs geosite-greatfire.srs geosite-geolocation-cn.srs geosite-category-ads-all.srs geosite-private.srs; do
  fetch_file "https://raw.githubusercontent.com/2dust/sing-box-rules/refs/heads/rule-set-geosite/$f" "$MACOS_DIR/bin/srss/$f"
done

echo "[3/5] Writing Info.plist and ad-hoc signing macOS binaries..."
cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>en</string>
    <string>fa</string>
    <string>zh-Hans</string>
    <string>zh-Hant</string>
    <string>fr</string>
    <string>ru</string>
    <string>hu</string>
    <string>id</string>
    <string>az</string>
  </array>
  <key>CFBundleDisplayName</key>
  <string>Next N</string>
  <key>CFBundleExecutable</key>
  <string>NextN</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>com.ebramjames.nextn</string>
  <key>CFBundleName</key>
  <string>Next N</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>CSResourcesFileMapped</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
</dict>
</plist>
EOF

HOST_OS="$(uname -s)"
if [[ "$HOST_OS" == "Darwin" ]]; then
  codesign --force --deep --sign - "$APP_DIR"
elif command -v rcodesign >/dev/null 2>&1; then
  echo "  Ad-hoc signing Mach-O executables and .dylibs via rcodesign..."
  # Sign individual Mach-O binaries (required on Apple Silicon after cross-publish)
  rcodesign sign "$MACOS_DIR/NextN"
  [[ -f "$MACOS_DIR/NextN.Updater" ]] && rcodesign sign "$MACOS_DIR/NextN.Updater" || true
  rcodesign sign "$MACOS_DIR/bin/xray/xray"
  rcodesign sign "$MACOS_DIR/bin/sing_box/sing-box"
  while IFS= read -r -d '' dylib; do
    rcodesign sign "$dylib"
  done < <(find "$MACOS_DIR" -type f -name '*.dylib' -print0)
  echo "  Ad-hoc signing completed."
fi

echo "[4/5] Building macOS .zip archive (for direct install & in-app updater)..."
ZIP_OUT="$DIST_DIR/NextN-macos-${OUT_ARCH}.zip"
rm -f "$ZIP_OUT"
(cd "$WORKDIR" && zip -qry "$ZIP_OUT" "Next N.app")
echo "  Built: $ZIP_OUT"

echo "[5/5] Building macOS .dmg installer..."
DMG_OUT="$DIST_DIR/NextN-macos-${OUT_ARCH}.dmg"
rm -f "$DMG_OUT"

DMG_STAGE="$WORKDIR/dmg-stage"
mkdir -p "$DMG_STAGE"
cp -a "$APP_DIR" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"

if [[ "$HOST_OS" == "Darwin" ]]; then
  if command -v create-dmg >/dev/null 2>&1; then
    create-dmg \
      --volname "Next N Installer" \
      --window-size 680 420 \
      --icon-size 100 \
      --icon "Next N.app" 175 185 \
      --hide-extension "Next N.app" \
      --app-drop-link 505 185 \
      --skip-jenkins \
      "$DMG_OUT" \
      "$APP_DIR" || {
        echo "create-dmg failed on headless runner; falling back to hdiutil..."
        hdiutil create -volname "Next N Installer" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG_OUT"
      }
  else
    hdiutil create -volname "Next N Installer" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG_OUT"
  fi
else
  # Cross-platform Linux DMG builder: HFS+ hybrid image via xorriso + UDZO compression via libdmg-hfsplus (dmg)
  if ! command -v xorriso >/dev/null 2>&1; then
    echo "ERROR: xorriso is required on Linux to generate HFS+ macOS images." >&2
    exit 1
  fi
  if ! command -v dmg >/dev/null 2>&1; then
    echo "ERROR: 'dmg' (from libdmg-hfsplus) is required on Linux to generate compressed UDZO .dmg files." >&2
    exit 1
  fi

  RAW_ISO="$WORKDIR/NextN-macos-${OUT_ARCH}-uncompressed.iso"
  xorriso -as mkisofs \
    -V "Next N Installer" \
    -D -R -no-pad \
    -hfsplus \
    -o "$RAW_ISO" \
    "$DMG_STAGE"

  dmg "$RAW_ISO" "$DMG_OUT"

  # Verify Apple UDIF 'koly' signature at the last 512 bytes of the DMG
  MAGIC="$(tail -c 512 "$DMG_OUT" | head -c 4)"
  if [[ "$MAGIC" != "koly" ]]; then
    echo "ERROR: Generated DMG failed UDIF koly trailer verification (got '$MAGIC')." >&2
    exit 1
  fi
  echo "  Verified Apple UDIF 'koly' trailer on $DMG_OUT"
fi

ls -lh "$DMG_OUT" "$ZIP_OUT"
echo "[OK] macOS installer built and verified: $DMG_OUT"
