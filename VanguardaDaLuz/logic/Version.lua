-- Versões do addon ("0.6.0", do .toc): leitura e comparação número por
-- número (0.9.0 < 0.10.0). Cada addon anuncia a própria versão à guilda
-- (mensagem I, logic/Protocol.lua) e avisa quando alguém tem uma mais nova.
-- Lógica pura.
local _, ns = ...

local Version = {}

local MAX_PARTS = 4
local MAX_PART = 9999

-- { 0, 6, 0 } de "0.6.0", ou nil se não for uma versão válida (só números
-- separados por ponto, de 2 a 4 partes).
function Version.Parse(text)
  if type(text) ~= "string" or #text > 24 or not string.match(text, "^%d+[%.%d]*$") then return nil end
  if string.find(text, "%.%.") or string.sub(text, -1) == "." then return nil end
  local parts = {}
  for part in string.gmatch(text, "%d+") do
    local n = tonumber(part)
    if n > MAX_PART then return nil end
    parts[#parts + 1] = n
  end
  if #parts < 2 or #parts > MAX_PARTS then return nil end
  return parts
end

-- -1, 0 ou 1 (a < b, iguais, a > b). Partes que faltam valem 0. nil se uma
-- das duas não for válida.
function Version.Compare(a, b)
  local pa, pb = Version.Parse(a), Version.Parse(b)
  if not (pa and pb) then return nil end
  for i = 1, MAX_PARTS do
    local x, y = pa[i] or 0, pb[i] or 0
    if x ~= y then return x < y and -1 or 1 end
  end
  return 0
end

-- `candidate` é mais nova que `mine`?
function Version.IsNewer(candidate, mine)
  return Version.Compare(candidate, mine) == 1
end

ns.Version = Version
return Version
