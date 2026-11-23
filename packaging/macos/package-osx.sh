#!/usr/bin/env bash
# ============================================================================
# Next N — macOS .app Bundle & .dmg Installer Packager
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

echo "[1/4] Staging Next N desktop binaries..."
cp -a "$PUBLISH_DIR/." "$MACOS_DIR/"
chmod +x "$MACOS_DIR/NextN"
[[ -f "$MACOS_DIR/NextN.Updater" ]] && chmod +x "$MACOS_DIR/NextN.Updater" || true
echo "Installed by Next N macOS Bundle. User data is stored in Application Support." > "$MACOS_DIR/NotStoreConfigHere.txt"

if [[ -f "$MACOS_DIR/NextN.icns" ]]; then
  cp -f "$MACOS_DIR/NextN.icns" "$RES_DIR/AppIcon.icns"
elif [[ -f "$REPO_ROOT/src/NextN.Desktop/NextN.icns" ]]; then
  cp -f "$REPO_ROOT/src/NextN.Desktop/NextN.icns" "$RES_DIR/AppIcon.icns"
fi

echo "[2/4] Downloading official Xray-core, sing-box, and Geo assets..."
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
install -m 755 "$WORKDIR/xray/xray" "$MACOS_DIR/bin/xray/xray"

SING_TAG="$(gh_api https://api.github.com/repos/SagerNet/sing-box/releases/latest | jq -re '.tag_name')"
SING_VER="${SING_TAG#v}"
fetch_file "https://github.com/SagerNet/sing-box/releases/download/${SING_TAG}/sing-box-${SING_VER}-darwin-${SING_ARCH}.tar.gz" "$WORKDIR/singbox.tar.gz"
tar -C "$WORKDIR" -xzf "$WORKDIR/singbox.tar.gz"
SING_BIN="$(find "$WORKDIR" -type f -name 'sing-box' | head -n1)"
install -m 755 "$SING_BIN" "$MACOS_DIR/bin/sing_box/sing-box"

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

echo "[3/4] Writing Info.plist..."
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

echo "[4/4] Creating macOS DMG installer..."
DMG_OUT="$DIST_DIR/NextN-macos-${OUT_ARCH}.dmg"
rm -f "$DMG_OUT"

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
      DMG_STAGE="$WORKDIR/dmg-stage"
      mkdir -p "$DMG_STAGE"
      cp -a "$APP_DIR" "$DMG_STAGE/"
      ln -sf /Applications "$DMG_STAGE/Applications"
      hdiutil create -volname "Next N Installer" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG_OUT"
    }
else
  DMG_STAGE="$WORKDIR/dmg-stage"
  mkdir -p "$DMG_STAGE"
  cp -a "$APP_DIR" "$DMG_STAGE/"
  ln -sf /Applications "$DMG_STAGE/Applications"
  hdiutil create -volname "Next N Installer" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG_OUT"
fi

echo "[OK] macOS installer built: $DMG_OUT"
