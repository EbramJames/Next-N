#!/usr/bin/env bash
# ============================================================================
# Next N — Debian / Ubuntu (.deb) Package Builder
# Usage: ./packaging/linux/package-debian.sh <amd64|arm64> <publish-dir> <version>
# ============================================================================
set -euo pipefail

DEB_ARCH="${1:-amd64}"
PUBLISH_DIR="${2:?Publish directory is required}"
VERSION="${3:-1.0.0}"
VERSION="${VERSION#v}"

case "$DEB_ARCH" in
  amd64|x64)
    DEB_ARCH="amd64"
    XRAY_ASSET="Xray-linux-64.zip"
    SING_ARCH="amd64"
    ;;
  arm64|aarch64)
    DEB_ARCH="arm64"
    XRAY_ASSET="Xray-linux-arm64-v8a.zip"
    SING_ARCH="arm64"
    ;;
  *)
    echo "Unsupported Debian arch: $DEB_ARCH (use amd64|arm64)" >&2
    exit 1
    ;;
esac

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DIST_DIR="$REPO_ROOT/dist"
mkdir -p "$DIST_DIR"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

STAGE="$WORKDIR/nextn_${VERSION}_${DEB_ARCH}"
DEBIAN_DIR="$STAGE/DEBIAN"
OPT_DIR="$STAGE/opt/NextN"

mkdir -p "$OPT_DIR/bin/xray" "$OPT_DIR/bin/sing_box" "$OPT_DIR/bin/srss" \
         "$STAGE/usr/bin" \
         "$STAGE/usr/share/applications" \
         "$STAGE/usr/share/icons/hicolor/512x512/apps" \
         "$DEBIAN_DIR"

echo "[1/4] Staging Next N binaries..."
cp -a "$PUBLISH_DIR/." "$OPT_DIR/"
echo "Installed by Next N Debian package. User data is stored in ~/.local/share/NextN." > "$OPT_DIR/NotStoreConfigHere.txt"

if [[ -f "$REPO_ROOT/src/NextN.Desktop/NextN.png" ]]; then
  cp "$REPO_ROOT/src/NextN.Desktop/NextN.png" "$STAGE/usr/share/icons/hicolor/512x512/apps/nextn.png"
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
install -m 755 "$WORKDIR/xray/xray" "$OPT_DIR/bin/xray/xray"

SING_TAG="$(gh_api https://api.github.com/repos/SagerNet/sing-box/releases/latest | jq -re '.tag_name')"
SING_VER="${SING_TAG#v}"
fetch_file "https://github.com/SagerNet/sing-box/releases/download/${SING_TAG}/sing-box-${SING_VER}-linux-${SING_ARCH}.tar.gz" "$WORKDIR/singbox.tar.gz"
tar -C "$WORKDIR" -xzf "$WORKDIR/singbox.tar.gz"
SING_BIN="$(find "$WORKDIR" -type f -name 'sing-box' | head -n1)"
install -m 755 "$SING_BIN" "$OPT_DIR/bin/sing_box/sing-box"

fetch_file "https://github.com/Loyalsoldier/V2ray-rules-dat/releases/latest/download/geosite.dat" "$OPT_DIR/bin/geosite.dat"
fetch_file "https://github.com/Loyalsoldier/V2ray-rules-dat/releases/latest/download/geoip.dat" "$OPT_DIR/bin/geoip.dat"
fetch_file "https://raw.githubusercontent.com/Loyalsoldier/geoip/release/geoip-only-cn-private.dat" "$OPT_DIR/bin/geoip-only-cn-private.dat"
fetch_file "https://raw.githubusercontent.com/Loyalsoldier/geoip/release/Country.mmdb" "$OPT_DIR/bin/Country.mmdb"
fetch_file "https://github.com/MetaCubeX/meta-rules-dat/releases/latest/download/geoip.metadb" "$OPT_DIR/bin/geoip.metadb"

for f in geoip-private.srs geoip-cn.srs geoip-facebook.srs geoip-fastly.srs geoip-google.srs geoip-netflix.srs geoip-telegram.srs geoip-twitter.srs; do
  fetch_file "https://raw.githubusercontent.com/2dust/sing-box-rules/refs/heads/rule-set-geoip/$f" "$OPT_DIR/bin/srss/$f"
done
for f in geosite-cn.srs geosite-gfw.srs geosite-google.srs geosite-greatfire.srs geosite-geolocation-cn.srs geosite-category-ads-all.srs geosite-private.srs; do
  fetch_file "https://raw.githubusercontent.com/2dust/sing-box-rules/refs/heads/rule-set-geosite/$f" "$OPT_DIR/bin/srss/$f"
done

echo "[3/4] Writing launcher, desktop entry, and DEBIAN control metadata..."
cat > "$STAGE/usr/bin/nextn" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec /opt/NextN/NextN "$@"
EOF
chmod 0755 "$STAGE/usr/bin/nextn"

cat > "$STAGE/usr/share/applications/nextn.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Next N
GenericName=Network Proxy Client
Comment=Modern Cross-Platform Proxy Client powered by Xray-core and sing-box
Exec=/usr/bin/nextn
Icon=nextn
Terminal=false
Categories=Network;Utility;
StartupWMClass=NextN
EOF
chmod 0644 "$STAGE/usr/share/applications/nextn.desktop"

cat > "$DEBIAN_DIR/control" <<EOF
Package: nextn
Version: ${VERSION}
Architecture: ${DEB_ARCH}
Maintainer: EbramJames <ebramjames630@gmail.com>
Homepage: https://github.com/EbramJames/Next-N
Section: net
Priority: optional
Depends: libc6, libgcc-s1, libstdc++6, zlib1g, fontconfig, libfreetype6, desktop-file-utils, xdg-utils
Description: Next N — Modern Cross-Platform Proxy Client
 Unified Avalonia desktop proxy client supporting VLESS, VMess, Trojan,
 Shadowsocks, Hysteria2, WireGuard, TUIC, AnyTLS, Naive, SOCKS, and HTTP
 via Xray-core and sing-box with native TUN mode and smart routing.
EOF

cat > "$DEBIAN_DIR/postinst" <<'EOF'
#!/bin/sh
set -e
update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -f /usr/share/icons/hicolor >/dev/null 2>&1 || true
exit 0
EOF
chmod 0755 "$DEBIAN_DIR/postinst"

cat > "$DEBIAN_DIR/postrm" <<'EOF'
#!/bin/sh
set -e
update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -f /usr/share/icons/hicolor >/dev/null 2>&1 || true
exit 0
EOF
chmod 0755 "$DEBIAN_DIR/postrm"

find "$OPT_DIR" -type d -exec chmod 0755 {} +
find "$OPT_DIR" -type f -exec chmod 0644 {} +
chmod 0755 "$OPT_DIR/NextN"
[[ -f "$OPT_DIR/NextN.Updater" ]] && chmod 0755 "$OPT_DIR/NextN.Updater" || true
chmod 0755 "$OPT_DIR/bin/xray/xray" "$OPT_DIR/bin/sing_box/sing-box"

echo "[4/4] Building .deb package..."
DEB_OUT="$DIST_DIR/NextN-linux-${DEB_ARCH}.deb"
dpkg-deb --root-owner-group --build "$STAGE" "$DEB_OUT"

echo "[OK] Debian package built: $DEB_OUT"
