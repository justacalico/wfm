#!/bin/sh
# Build the Flutter app and stage it for embedding into the server binary.
set -eu
cd "$(dirname "$0")/.."
flutter build web --release --base-href /app/ --no-web-resources-cdn
rm -rf server/web/app
mkdir -p server/web/app
cp -a build/web/. server/web/app/
echo "app bundle staged in server/web/app"
