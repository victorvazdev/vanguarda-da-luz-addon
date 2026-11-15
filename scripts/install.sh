#!/usr/bin/env bash
# Gera o pacote (scripts/package.sh) e instala no jogo: apaga a pasta antiga
# do addon em Interface/AddOns e extrai o zip novo no lugar.
#
# A pasta AddOns vem de VDL_ADDONS_DIR ou do arquivo scripts/.addons-dir
# (uma linha, fora do git), por exemplo:
#   .../World of Warcraft/_forever_/Interface/AddOns
set -euo pipefail
cd "$(dirname "$0")/.."

ADDON="VanguardaDaLuz"
DIR="${VDL_ADDONS_DIR:-}"
if [ -z "$DIR" ] && [ -f scripts/.addons-dir ]; then
  DIR="$(head -n 1 scripts/.addons-dir | tr -d '\r')"
fi
if [ -z "$DIR" ]; then
  echo "Defina VDL_ADDONS_DIR ou crie scripts/.addons-dir com a pasta Interface/AddOns do jogo." >&2
  exit 1
fi
if [ ! -d "$DIR" ] || [ "$(basename "$DIR")" != "AddOns" ]; then
  echo "Pasta AddOns não encontrada: $DIR" >&2
  exit 1
fi

ZIP="$(scripts/package.sh)"
# O zip precisa ter só a pasta do addon na raiz.
if unzip -Z1 "$ZIP" | grep -qv "^$ADDON/"; then
  echo "O pacote $ZIP tem arquivos fora de $ADDON/." >&2
  exit 1
fi

rm -rf "${DIR:?}/$ADDON"
unzip -q "$ZIP" -d "$DIR"
echo "$ZIP instalado em $DIR/$ADDON"
