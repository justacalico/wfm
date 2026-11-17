#!/usr/bin/env bash
set -euo pipefail

VERSION="$1"

if [[ -z "$VERSION" ]]; then
  echo "Error: version is required" >&2
  exit 1
fi

build=1
if grep -q '^version: .*+' pubspec.yaml; then
  build=$(grep '^version: ' pubspec.yaml | sed 's/.*+//')
  build=$((build + 1))
fi
sed -i "s/^version: .*/version: ${VERSION}+${build}/" pubspec.yaml

if ! grep -q "^version: ${VERSION}+" pubspec.yaml; then
  echo "Error: pubspec.yaml version not updated" >&2
  exit 1
fi

# Keep the server crate version (reported by /api/version) in sync with the
# release tag so the update checker and render clientInfo are not stuck on 0.1.0.
sed -i "/^\[package\]/,/^\[/ s/^version = \".*\"/version = \"${VERSION}\"/" server/Cargo.toml
sed -i '/^name = "wfm"$/{n;s/^version = ".*"/version = "'"${VERSION}"'"/}' server/Cargo.lock

if ! grep -q "^version = \"${VERSION}\"" server/Cargo.toml; then
  echo "Error: server/Cargo.toml version not updated" >&2
  exit 1
fi
