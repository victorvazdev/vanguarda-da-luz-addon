-- Lista de membros do addon: junta o roster da guilda com o item level e o
-- main/alt sincronizados, filtra e ordena. Lógica pura.
--
-- Entrada (Flavor.GuildRoster): { { name, rank, rankIndex, level, class,
--   classFile, zone, online }, ... }
-- Linha: os mesmos campos mais `ilvl` (nil sem o addon), `main` (nil sem main)
-- e `together` (tempo da pessoa com a guilda, em segundos; nil sem dados).
local _, ns = ...

local Roster = {}

-- Colunas que podem ordenar a lista.
Roster.SORT_KEYS = { name = true, level = true, ilvl = true, main = true, zone = true, rank = true,
  time = true }

-- `togetherTotals` = { [pessoa] = segundos } (logic/Together.lua Totals).
function Roster.BuildRows(entries, store, togetherTotals)
  local rows = {}
  for _, e in ipairs(entries) do
    local record = store and store[e.name]
    rows[#rows + 1] = {
      name = e.name, rank = e.rank, rankIndex = e.rankIndex or 99, level = e.level or 0,
      class = e.class, classFile = e.classFile, zone = e.zone, online = e.online and true or false,
      status = e.status,
      ilvl = record and record.i, main = record and record.m,
      together = togetherTotals and togetherTotals[(record and record.m) or e.name],
    }
  end
  return rows
end

-- "Main", "Alt de Fulano" ou nil.
function Roster.MainText(row)
  if not row.main then return nil end
  if row.main == row.name then return ns.L["Main"] end
  return string.format(ns.L["Alt de %s"], row.main)
end

-- `options` = { onlineOnly }.
function Roster.Filter(rows, options)
  local result = {}
  for _, row in ipairs(rows) do
    if not (options and options.onlineOnly) or row.online then result[#result + 1] = row end
  end
  return result
end

local function Lower(value)
  return string.lower(value or "")
end

local function ByName(a, b)
  local na, nb = Lower(a.name), Lower(b.name)
  if na ~= nb then return na < nb end
  return a.name < b.name
end

-- Valor de comparação de uma coluna (nil = sem valor, sempre no fim).
local function Value(row, key)
  if key == "name" then return Lower(row.name) end
  if key == "level" then return row.level end
  if key == "ilvl" then return row.ilvl end
  if key == "main" then
    local text = Roster.MainText(row)
    return text and Lower(text) or nil
  end
  if key == "zone" then return row.zone and row.zone ~= "" and Lower(row.zone) or nil end
  if key == "rank" then return row.rankIndex end
  if key == "time" then return row.together end
  return nil
end

-- Ordena a lista (cópia). Sem `key`: online primeiro, depois o posto (Grão
-- Lorde primeiro), o nível (maior primeiro) e o nome. Com `key`: a coluna,
-- crescente ou `descending`; quem não tem valor fica no fim; empate, pelo nome.
function Roster.Sort(rows, key, descending)
  local sorted = {}
  for i, row in ipairs(rows) do sorted[i] = row end
  table.sort(sorted, function(a, b)
    if not key then
      if a.online ~= b.online then return a.online end
      if a.rankIndex ~= b.rankIndex then return a.rankIndex < b.rankIndex end
      if a.level ~= b.level then return a.level > b.level end
      return ByName(a, b)
    end
    local va, vb = Value(a, key), Value(b, key)
    if va ~= vb then
      if va == nil then return false end
      if vb == nil then return true end
      if descending then return va > vb end
      return va < vb
    end
    return ByName(a, b)
  end)
  return sorted
end

ns.Roster = Roster
return Roster
