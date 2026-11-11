-- Carrega a lógica pura do addon fora do jogo, como o .toc faria, num
-- namespace novo a cada chamada.
local M = {}

M.ROOT = "VanguardaDaLuz/"
M.DOCS = "docs/exemplos-addon/"

local FILES = {
  "core/Config.lua",
  "core/Flavor_Forever.lua",
  "logic/Text.lua",
  "logic/Codec.lua",
  "logic/Snapshot.lua",
  "logic/Import.lua",
  "logic/GamePlan.lua",
  "logic/Time.lua",
  "logic/Protocol.lua",
  "logic/Trust.lua",
}

local LibDeflate

function M.Load()
  LibDeflate = LibDeflate or dofile(M.ROOT .. "libs/LibDeflate/LibDeflate.lua")
  local ns = { LibDeflate = LibDeflate }
  for _, file in ipairs(FILES) do
    local chunk = assert(loadfile(M.ROOT .. file))
    chunk("VanguardaDaLuz", ns)
  end
  return ns
end

function M.Read(name)
  local f = assert(io.open(M.DOCS .. name, "rb"))
  local content = f:read("*a")
  f:close()
  return content
end

function M.Expected()
  return dofile(M.DOCS .. "esperado.lua")
end

-- Cópia profunda.
function M.Copy(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = M.Copy(v) end
  return c
end

return M
