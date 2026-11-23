#!/usr/bin/env bash
# ============================================================================
# Next N — Fedora / RHEL / Rocky / AlmaLinux (.rpm) Package Builder
# Usage: ./packaging/linux/package-rhel.sh <x86_64|aarch64> <publish-dir> <version>
# ============================================================================
set -euo pipefail

RPM_ARCH="${1:-x86_64}"
PUBLISH_DIR="${2:?Publish directory is required}"
VERSION="${3:-1.0.0}"
VERSION="${VERSION#v}"

case "$RPM_ARCH" in
  x86_64|x64|amd64)
    RPM_ARCH="x86_64"
    XRAY_ASSET="Xray-linux-64.zip"
    SING_ARCH="amd64"
    ;;
  aarch64|arm64)
    RPM_ARCH="aarch64"
    XRAY_ASSET="Xray-linux-arm64-v8a.zip"
    SING_ARCH="arm64"
    ;;
  *)
    echo "Unsupported RPM arch: $RPM_ARCH (use x86_64|aarch64)" >&2
    exit 1
    ;;
esac

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DIST_DIR="$REPO_ROOT/dist"
mkdir -p "$DIST_DIR"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

PKGROOT="NextN-${VERSION}"
STAGE="$WORKDIR/$PKGROOT"
mkdir -p "$STAGE/bin/xray" "$STAGE/bin/sing_box" "$STAGE/bin/srss"

echo "[1/4] Staging Next N binaries..."
cp -a "$PUBLISH_DIR/." "$STAGE/"
cp "$REPO_ROOT/src/NextN.Desktop/NextN.png" "$STAGE/nextn.png"
echo "Installed by Next N RPM package. User data is stored in ~/.local/share/NextN." > "$STAGE/NotStoreConfigHere.txt"

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
install -m 755 "$WORKDIR/xray/xray" "$STAGE/bin/xray/xray"

SING_TAG="$(gh_api https://api.github.com/repos/SagerNet/sing-box/releases/latest | jq -re '.tag_name')"
SING_VER="${SING_TAG#v}"
fetch_file "https://github.com/SagerNet/sing-box/releases/download/${SING_TAG}/sing-box-${SING_VER}-linux-${SING_ARCH}.tar.gz" "$WORKDIR/singbox.tar.gz"
tar -C "$WORKDIR" -xzf "$WORKDIR/singbox.tar.gz"
SING_BIN="$(find "$WORKDIR" -type f -name 'sing-box' | head -n1)"
install -m 755 "$SING_BIN" "$STAGE/bin/sing_box/sing-box"

fetch_file "https://github.com/Loyalsoldier/V2ray-rules-dat/releases/latest/download/geosite.dat" "$STAGE/bin/geosite.dat"
fetch_file "https://github.com/Loyalsoldier/V2ray-rules-dat/releases/latest/download/geoip.dat" "$STAGE/bin/geoip.dat"
fetch_file "https://raw.githubusercontent.com/Loyalsoldier/geoip/release/geoip-only-cn-private.dat" "$STAGE/bin/geoip-only-cn-private.dat"
fetch_file "https://raw.githubusercontent.com/Loyalsoldier/geoip/release/Country.mmdb" "$STAGE/bin/Country.mmdb"
fetch_file "https://github.com/MetaCubeX/meta-rules-dat/releases/latest/download/geoip.metadb" "$STAGE/bin/geoip.metadb"

for f in geoip-private.srs geoip-cn.srs geoip-facebook.srs geoip-fastly.srs geoip-google.srs geoip-netflix.srs geoip-telegram.srs geoip-twitter.srs; do
  fetch_file "https://raw.githubusercontent.com/2dust/sing-box-rules/refs/heads/rule-set-geoip/$f" "$STAGE/bin/srss/$f"
done
for f in geosite-cn.srs geosite-gfw.srs geosite-google.srs geosite-greatfire.srs geosite-geolocation-cn.srs geosite-category-ads-all.srs geosite-private.srs; do
  fetch_file "https://raw.githubusercontent.com/2dust/sing-box-rules/refs/heads/rule-set-geosite/$f" "$STAGE/bin/srss/$f"
done

echo "[3/4] Writing RPM spec file..."
RPM_TOPDIR="$WORKDIR/rpmbuild"
mkdir -p "$RPM_TOPDIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
tar -C "$WORKDIR" -czf "$RPM_TOPDIR/SOURCES/${PKGROOT}.tar.gz" "$PKGROOT"

SPECFILE="$RPM_TOPDIR/SPECS/nextn.spec"
cat > "$SPECFILE" <<EOF
%global debug_package %{nil}
%undefine _debuginfo_subpackages
%undefine _debugsource_packages
%global __os_install_post %{nil}
%global __strip /bin/true
AutoReqProv:    no

Name:           nextn
Version:        ${VERSION}
Release:        1%{?dist}
Summary:        Next N — Modern Cross-Platform Network Proxy Client
License:        GPL-3.0-or-later
URL:            https://github.com/EbramJames/Next-N
BugURL:         https://github.com/EbramJames/Next-N/issues
ExclusiveArch:  x86_64 aarch64
Source0:        ${PKGROOT}.tar.gz

Requires:       fontconfig, freetype, desktop-file-utils, xdg-utils

%description
Next N is a modern cross-platform desktop proxy client powered by Xray-core
and sing-box supporting VLESS, VMess, Trojan, Shadowsocks, Hysteria2,
WireGuard, TUIC, AnyTLS, Naive, SOCKS, and HTTP with native TUN mode.

%prep
%setup -q -n ${PKGROOT}

%build

%install
install -dm0755 %{buildroot}/opt/NextN
cp -a * %{buildroot}/opt/NextN/
find %{buildroot}/opt/NextN -type d -exec chmod 0755 {} +
find %{buildroot}/opt/NextN -type f -exec chmod 0644 {} +
chmod 0755 %{buildroot}/opt/NextN/NextN
[ -f %{buildroot}/opt/NextN/NextN.Updater ] && chmod 0755 %{buildroot}/opt/NextN/NextN.Updater || :
chmod 0755 %{buildroot}/opt/NextN/bin/xray/xray %{buildroot}/opt/NextN/bin/sing_box/sing-box

install -dm0755 %{buildroot}%{_bindir}
cat > %{buildroot}%{_bindir}/nextn << 'LAUNCHER'
#!/usr/bin/env bash
set -euo pipefail
exec /opt/NextN/NextN "\$@"
LAUNCHER
chmod 0755 %{buildroot}%{_bindir}/nextn

install -dm0755 %{buildroot}%{_datadir}/applications
cat > %{buildroot}%{_datadir}/applications/nextn.desktop << 'DESKTOP'
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
DESKTOP
chmod 0644 %{buildroot}%{_datadir}/applications/nextn.desktop

install -dm0755 %{buildroot}%{_datadir}/icons/hicolor/512x512/apps
install -m0644 %{buildroot}/opt/NextN/nextn.png %{buildroot}%{_datadir}/icons/hicolor/512x512/apps/nextn.png

%post
/usr/bin/update-desktop-database %{_datadir}/applications >/dev/null 2>&1 || true
/usr/bin/gtk-update-icon-cache -f %{_datadir}/icons/hicolor >/dev/null 2>&1 || true

%postun
/usr/bin/update-desktop-database %{_datadir}/applications >/dev/null 2>&1 || true
/usr/bin/gtk-update-icon-cache -f %{_datadir}/icons/hicolor >/dev/null 2>&1 || true

%files
%{_bindir}/nextn
/opt/NextN
%{_datadir}/applications/nextn.desktop
%{_datadir}/icons/hicolor/512x512/apps/nextn.png
EOF

echo "[4/4] Building RPM package..."
rpmbuild --define "_topdir $RPM_TOPDIR" -bb "$SPECFILE" --target "$RPM_ARCH"
RPM_BUILT="$(find "$RPM_TOPDIR/RPMS" -name "*.rpm" | head -n1)"
cp -f "$RPM_BUILT" "$DIST_DIR/NextN-linux-${RPM_ARCH}.rpm"

echo "[OK] RPM package built: $DIST_DIR/NextN-linux-${RPM_ARCH}.rpm"
