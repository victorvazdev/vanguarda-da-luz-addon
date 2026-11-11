#!/usr/bin/env bash
# Roda o luacheck e os testes (busted, Lua 5.1).
set -euo pipefail
cd "$(dirname "$0")/.."

BIN=".lua/bin"
if [ ! -x "$BIN/busted" ]; then BIN="$(dirname "$(command -v busted)")"; fi

"$BIN/luacheck" VanguardaDaLuz tests
"$BIN/busted"
