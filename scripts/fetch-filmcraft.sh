#!/bin/sh
# Fetch the pinned FilmCraft web bundle into filmcraft/dist.
set -eu
VER="${1:-$(cat filmcraft/VERSION 2>/dev/null || echo 0.20.1)}"
DEST="filmcraft/dist"
URL="https://github.com/storytold/filmcraft/releases/download/v${VER}/filmcraft-web-${VER}.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl -fsSL "$URL" -o "$TMP/fc.zip"
unzip -q -o "$TMP/fc.zip" -d "$TMP/extract"
rm -rf "$DEST"
mkdir -p "$DEST"
mv "$TMP"/extract/filmcraft-web-*/. "$DEST"/
echo "FilmCraft $VER installed to $DEST"
