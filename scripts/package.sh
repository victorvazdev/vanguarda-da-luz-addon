#!/usr/bin/env bash
# Gera dist/VanguardaDaLuz-<versão>.zip, pronto para extrair na pasta
# _forever_/Interface/AddOns do jogo.
set -euo pipefail
cd "$(dirname "$0")/.."

ADDON="VanguardaDaLuz"
TOC="$ADDON/${ADDON}_Forever.toc"
VERSION="$(sed -n 's/^## Version: *//p' "$TOC" | tr -d '\r')"
OUT="dist/$ADDON-$VERSION.zip"

mkdir -p dist
rm -f "$OUT"
zip -qr "$OUT" "$ADDON" -x "*.DS_Store"
echo "$OUT"
