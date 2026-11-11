#!/usr/bin/env bash
# Instala as ferramentas de desenvolvimento dentro do projeto:
# Lua 5.1 + LuaRocks (em .lua/), busted e luacheck. Requer Python 3.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -x .venv/bin/hererocks ]; then
  python3 -m venv .venv
  .venv/bin/pip install --quiet hererocks
fi
if [ ! -x .lua/bin/lua ]; then
  .venv/bin/hererocks .lua -l5.1 -rlatest
fi
.lua/bin/luarocks install busted
.lua/bin/luarocks install luacheck
echo "Pronto. Rode scripts/check.sh"
