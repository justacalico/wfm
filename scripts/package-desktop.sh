#!/bin/sh
# Stage the bundled craft helpers next to a built desktop app so the app
# finds them at <exe>/craft/. Usage: scripts/package-desktop.sh <os>
# where <os> is linux | macos | windows. Run after `flutter build <os>`
# and after build-filmcraft-native.sh / build-webview.sh.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OS="${1:?usage: $0 <linux|macos|windows>}"
case "$OS" in
  linux)   BUNDLE="$ROOT/build/linux/x64/release/bundle" ;;
  macos)   BUNDLE="$ROOT/build/macos/Build/Products/Release/wfm.app/Contents/MacOS" ;;
  windows) BUNDLE="$ROOT/build/windows/x64/runner/Release" ;;
  *) echo "unknown os $OS" >&2; exit 2 ;;
esac
[ -d "$BUNDLE" ] || { echo "no bundle at $BUNDLE; run flutter build first" >&2; exit 1; }
mkdir -p "$BUNDLE/craft"
cp -a "$ROOT"/desktop/craft/. "$BUNDLE/craft/"
if [ "$OS" = linux ]; then
  cp "$ROOT/web/icons/Icon-512.png" "$BUNDLE/gitlab.httpanimations.wfm.png"
  cp "$ROOT/desktop/install-desktop-entry.sh" "$BUNDLE/"
  chmod +x "$BUNDLE/install-desktop-entry.sh"
fi
echo "staged desktop/craft into $BUNDLE/craft"
