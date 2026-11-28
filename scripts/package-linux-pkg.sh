#!/bin/sh
# Build .deb and .rpm packages from a flutter linux release bundle, laid
# out as /opt/wfm with a /usr/bin/wfm symlink, desktop entry and icon.
# Usage: scripts/package-linux-pkg.sh <version> <flutter-arch> [out-dir]
# where flutter-arch is x64 | arm64. Needs dpkg-deb and rpmbuild.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?usage: $0 <version> <x64|arm64> [out-dir]}"
FLUTTER_ARCH="${2:?usage: $0 <version> <x64|arm64> [out-dir]}"
OUT="${3:-artifacts}"
BUNDLE="$ROOT/build/linux/$FLUTTER_ARCH/release/bundle"
[ -d "$BUNDLE" ] || { echo "no bundle at $BUNDLE; run flutter build first" >&2; exit 1; }
case "$FLUTTER_ARCH" in
  x64)   DEB_ARCH=amd64; SUFFIX=linux-x86_64 ;;
  arm64) DEB_ARCH=arm64; SUFFIX=linux-aarch64 ;;
  *) echo "unknown arch $FLUTTER_ARCH" >&2; exit 2 ;;
esac
mkdir -p "$ROOT/$OUT"

STAGE="$(mktemp -d)/wfm"
mkdir -p "$STAGE/opt/wfm" "$STAGE/usr/bin" \
  "$STAGE/usr/share/applications" \
  "$STAGE/usr/share/icons/hicolor/512x512/apps"
cp -a "$BUNDLE/." "$STAGE/opt/wfm/"
ln -s /opt/wfm/wfm "$STAGE/usr/bin/wfm"
cp "$ROOT/web/icons/Icon-512.png" \
  "$STAGE/usr/share/icons/hicolor/512x512/apps/gitlab.httpanimations.wfm.png"
cat > "$STAGE/usr/share/applications/gitlab.httpanimations.wfm.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=WFM
Exec=/opt/wfm/wfm
Icon=gitlab.httpanimations.wfm
Terminal=false
Categories=AudioVideo;
EOF

mkdir -p "$STAGE/DEBIAN"
cat > "$STAGE/DEBIAN/control" <<EOF
Package: wfm
Version: $VERSION
Section: video
Priority: optional
Architecture: $DEB_ARCH
Maintainer: WFM <https://gitlab.com/HttpAnimations/wfm>
Depends: libgtk-3-0t64 | libgtk-3-0, libwebkit2gtk-4.1-0 | libwebkit2gtk-4.0-37, libxkbcommon0, libasound2t64 | libasound2
Description: WFM film manager desktop app
EOF
dpkg-deb --build --root-owner-group "$STAGE" \
  "$ROOT/$OUT/wfm-desktop-$VERSION-$SUFFIX.deb"
rm -rf "$STAGE/DEBIAN"

RPMTOP="$(mktemp -d)/rpmtop"
mkdir -p "$RPMTOP/BUILD" "$RPMTOP/RPMS" "$RPMTOP/SOURCES" "$RPMTOP/SPECS" "$RPMTOP/SRPMS"
cat > "$RPMTOP/SPECS/wfm.spec" <<EOF
Name: wfm
Version: $VERSION
Release: 1
Summary: WFM film manager desktop app
License: AGPL-3.0-only
Requires: gtk3
%description
WFM film manager desktop app
%prep
%build
%install
cp -a %{stagedir}/. %{buildroot}/
%files
%defattr(-,root,root)
/opt/wfm
/usr/bin/wfm
/usr/share/applications/gitlab.httpanimations.wfm.desktop
/usr/share/icons/hicolor/512x512/apps/gitlab.httpanimations.wfm.png
EOF
rpmbuild -bb \
  --define "_topdir $RPMTOP" \
  --define "stagedir $STAGE" \
  "$RPMTOP/SPECS/wfm.spec" >/dev/null
find "$RPMTOP/RPMS" -name '*.rpm' -exec cp {} \
  "$ROOT/$OUT/wfm-desktop-$VERSION-$SUFFIX.rpm" \;

ls -la "$ROOT/$OUT/"
