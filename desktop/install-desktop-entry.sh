#!/bin/sh
# Install a .desktop entry + icon pointing at the wfm binary in this folder,
# so launchers and Wayland sessions show the WFM icon. Run from the
# extracted bundle directory. Safe to re-run.
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)"
APPS="$HOME/.local/share/applications"
ICONS="$HOME/.local/share/icons/hicolor/512x512/apps"
mkdir -p "$APPS" "$ICONS"
cp "$DIR/gitlab.httpanimations.wfm.png" "$ICONS/"
cat > "$APPS/gitlab.httpanimations.wfm.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=WFM
Exec=$DIR/wfm
Icon=gitlab.httpanimations.wfm
Terminal=false
Categories=AudioVideo;
EOF
update-desktop-database "$APPS" 2>/dev/null || true
echo "installed desktop entry -> $DIR/wfm"
