#!/usr/bin/env bash
set -euo pipefail
APP_DIR="/var/www/app"
RELEASE="$(date +%Y%m%d%H%M%S)-${GIT_COMMIT:-local}"
TMP="/tmp/app-release"
rm -rf "$TMP"; mkdir -p "$TMP"
tar -xzf package.tar.gz -C "$TMP"
pushd "$TMP/app" >/dev/null; npm ci --omit=dev || true; popd >/dev/null
sudo mkdir -p "$APP_DIR/releases/$RELEASE"
sudo rsync -a "$TMP/app/" "$APP_DIR/releases/$RELEASE/"
sudo ln -sfn "$APP_DIR/releases/$RELEASE" "$APP_DIR/current"
sudo chown -R www-data:www-data "$APP_DIR"
sudo systemctl restart app
cd "$APP_DIR/releases"; ls -1t | tail -n +6 | xargs -r sudo rm -rf || true
echo "Deploy concluído."
