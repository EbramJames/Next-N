#!/usr/bin/env bash
# ============================================================================
# Next N — Universal Linux AppImage Builder
# Usage: ./packaging/linux/package-appimage.sh <x86_64|aarch64> <publish-dir> <version>
# ============================================================================
set -euo pipefail

ARCH="${1:-x86_64}"
PUBLISH_DIR="${2:?Publish directory is required}"
VERSION="${3:-1.0.0}"
VERSION="${VERSION#v}"

case "$ARCH" in
  x86_64|x64|amd64)
    ARCH="x86_64"
    XRAY_ASSET="Xray-linux-64.zip"
    SING_ARCH="amd64"
    ;;
  aarch64|arm64)
    ARCH="aarch64"
    XRAY_ASSET="Xray-linux-arm64-v8a.zip"
    SING_ARCH="arm64"
    ;;
  *)
    echo "Unsupported AppImage arch: $ARCH (use x86_64|aarch64)" >&2
    exit 1
    ;;
esac

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DIST_DIR="$REPO_ROOT/dist"
mkdir -p "$DIST_DIR"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

APPDIR="$WORKDIR/NextN.AppDir"
mkdir -p "$APPDIR/usr/bin/bin/xray" "$APPDIR/usr/bin/bin/sing_box" "$APPDIR/usr/bin/bin/srss"

echo "[1/4] Staging Next N AppDir..."
cp -a "$PUBLISH_DIR/." "$APPDIR/usr/bin/"
chmod +x "$APPDIR/usr/bin/NextN"
echo "Installed via Next N AppImage. User data is stored in ~/.local/share/NextN." > "$APPDIR/usr/bin/NotStoreConfigHere.txt"

cp "$REPO_ROOT/src/NextN.Desktop/NextN.png" "$APPDIR/nextn.png"
ln -sf nextn.png "$APPDIR/.DirIcon"

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
install -m 755 "$WORKDIR/xray/xray" "$APPDIR/usr/bin/bin/xray/xray"

SING_TAG="$(gh_api https://api.github.com/repos/SagerNet/sing-box/releases/latest | jq -re '.tag_name')"
SING_VER="${SING_TAG#v}"
fetch_file "https://github.com/SagerNet/sing-box/releases/download/${SING_TAG}/sing-box-${SING_VER}-linux-${SING_ARCH}.tar.gz" "$WORKDIR/singbox.tar.gz"
tar -C "$WORKDIR" -xzf "$WORKDIR/singbox.tar.gz"
SING_BIN="$(find "$WORKDIR" -type f -name 'sing-box' | head -n1)"
install -m 755 "$SING_BIN" "$APPDIR/usr/bin/bin/sing_box/sing-box"

fetch_file "https://github.com/Loyalsoldier/V2ray-rules-dat/releases/latest/download/geosite.dat" "$APPDIR/usr/bin/bin/geosite.dat"
fetch_file "https://github.com/Loyalsoldier/V2ray-rules-dat/releases/latest/download/geoip.dat" "$APPDIR/usr/bin/bin/geoip.dat"
fetch_file "https://raw.githubusercontent.com/Loyalsoldier/geoip/release/geoip-only-cn-private.dat" "$APPDIR/usr/bin/bin/geoip-only-cn-private.dat"
fetch_file "https://raw.githubusercontent.com/Loyalsoldier/geoip/release/Country.mmdb" "$APPDIR/usr/bin/bin/Country.mmdb"
fetch_file "https://github.com/MetaCubeX/meta-rules-dat/releases/latest/download/geoip.metadb" "$APPDIR/usr/bin/bin/geoip.metadb"

for f in geoip-private.srs geoip-cn.srs geoip-facebook.srs geoip-fastly.srs geoip-google.srs geoip-netflix.srs geoip-telegram.srs geoip-twitter.srs; do
  fetch_file "https://raw.githubusercontent.com/2dust/sing-box-rules/refs/heads/rule-set-geoip/$f" "$APPDIR/usr/bin/bin/srss/$f"
done
for f in geosite-cn.srs geosite-gfw.srs geosite-google.srs geosite-greatfire.srs geosite-geolocation-cn.srs geosite-category-ads-all.srs geosite-private.srs; do
  fetch_file "https://raw.githubusercontent.com/2dust/sing-box-rules/refs/heads/rule-set-geosite/$f" "$APPDIR/usr/bin/bin/srss/$f"
done

echo "[3/4] Writing AppRun and desktop entry..."
cat > "$APPDIR/AppRun" <<'EOF'
#!/usr/bin/env bash
HERE="$(dirname "$(readlink -f "${0}")")"
exec "$HERE/usr/bin/NextN" "$@"
EOF
chmod 0755 "$APPDIR/AppRun"

cat > "$APPDIR/nextn.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Next N
GenericName=Network Proxy Client
Comment=Modern Cross-Platform Proxy Client powered by Xray-core and sing-box
Exec=NextN
Icon=nextn
Terminal=false
Categories=Network;Utility;
StartupWMClass=NextN
EOF

echo "[4/4] Packaging AppImage..."
APPIMAGETOOL="$WORKDIR/appimagetool"
curl -fL "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${ARCH}.AppImage" -o "$APPIMAGETOOL"
chmod +x "$APPIMAGETOOL"

OUT_FILE="$DIST_DIR/NextN-linux-${ARCH}.AppImage"
ARCH="$ARCH" "$APPIMAGETOOL" --appimage-extract-and-run "$APPDIR" "$OUT_FILE"

echo "[OK] AppImage built: $OUT_FILE"
