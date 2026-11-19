-- Ouro doado ao banco da guilda: registro próprio do addon, montado com o
-- registro de dinheiro do banco. Lógica pura.
--
-- O banco só guarda as últimas transações, com o tempo aproximado ("há 11
-- dias e 9 horas"). Cada leitura vira depósitos com um horário aproximado
-- (agora menos o tempo decorrido), e um depósito só entra no registro se não
-- casar com um já guardado: mesma pessoa, mesmo valor e horário a até
-- TOLERANCE segundos. Duas doações iguais da mesma pessoa na mesma hora
-- aparecem duas vezes na leitura e casam com dois registros, então contam
-- duas vezes. As listas recebidas de outros membros passam pela mesma regra.
--
-- `store` = lista de { w = quem, a = valor em cobre, t = horário aproximado }
-- Por pessoa: os alts somam no main (logic/Members.lua, campo `m`).
local _, ns = ...

local Donations = {}

Donations.TOLERANCE = 2 * 3600 -- leituras diferentes do mesmo depósito
local HOUR, DAY = 3600, 86400
local MAX_AMOUNT = 10 ^ 12 -- cobre

local function Field(value)
  value = tostring(value)
  return #value .. ":" .. value
end

local function Int(value)
  if not value or not string.find(value, "^%d+$") then return nil end
  return tonumber(value)
end

local function ValidName(name)
  return type(name) == "string" and name ~= "" and not string.find(name, "[|%c]")
end

local function WholeNumber(value, min, max)
  return type(value) == "number" and value == math.floor(value) and value >= min and value <= max
end

-- Depósito válido? { w, a, t }.
function Donations.IsValid(entry)
  return type(entry) == "table" and ValidName(entry.w) and WholeNumber(entry.a, 1, MAX_AMOUNT)
    and WholeNumber(entry.t, 0, 2 ^ 40)
end

-- Depósitos de uma leitura do registro do banco. `log` = lista de
-- { kind, who, amount, years, months, days, hours } como em
-- GetGuildBankMoneyTransaction; `now` = horário do servidor. Só entram os
-- depósitos ("deposit"); saques e a renda automática da guilda
-- ("depositSummary") ficam de fora.
function Donations.FromLog(log, now)
  local entries = {}
  for _, item in ipairs(log or {}) do
    if item.kind == "deposit" then
      local ago = ((item.years or 0) * 365 + (item.months or 0) * 30 + (item.days or 0)) * DAY
        + (item.hours or 0) * HOUR
      local entry = { w = item.who, a = item.amount, t = now - ago }
      if Donations.IsValid(entry) then entries[#entries + 1] = entry end
    end
  end
  return entries
end

local function Key(entry)
  return entry.w .. "\0" .. entry.a
end

-- Junta depósitos ao registro, sem repetir os que já estão. Retorna a lista
-- dos que entraram. Os guardados são agrupados por pessoa e valor, então cada
-- depósito só é comparado com os do mesmo grupo (o registro cresce com o
-- tempo e as listas recebidas trazem todos).
function Donations.Absorb(store, entries)
  local sorted = {}
  for _, entry in ipairs(entries or {}) do
    if Donations.IsValid(entry) then sorted[#sorted + 1] = entry end
  end
  local added = {}
  if #sorted == 0 then return added end
  table.sort(sorted, function(a, b) return a.t < b.t end)
  local groups = {} -- [pessoa e valor] = { registros guardados ainda livres }
  for _, kept in ipairs(store) do
    local key = Key(kept)
    local group = groups[key]
    if not group then
      group = {}
      groups[key] = group
    end
    group[#group + 1] = kept
  end
  for _, entry in ipairs(sorted) do
    -- Casa com o registro guardado mais próximo no tempo ainda não usado.
    local group = groups[Key(entry)]
    local best, bestGap
    if group then
      for i, kept in ipairs(group) do
        local gap = math.abs(kept.t - entry.t)
        if gap <= Donations.TOLERANCE and (not bestGap or gap < bestGap) then best, bestGap = i, gap end
      end
    end
    if best then
      table.remove(group, best)
    else
      local copy = { w = entry.w, a = entry.a, t = entry.t }
      store[#store + 1] = copy
      added[#added + 1] = copy
    end
  end
  return added
end

-- Apaga os depósitos de quem não está mais na guilda. `members` = { [nome] = true }.
function Donations.Prune(store, members)
  local kept = 0
  for i = 1, #store do
    local entry = store[i]
    store[i] = nil
    if members[entry.w] then
      kept = kept + 1
      store[kept] = entry
    end
  end
end

-- Total doado por pessoa, em cobre: { [pessoa] = cobre }.
function Donations.Totals(store, membersStore)
  local totals = {}
  for _, entry in ipairs(store) do
    local person = ns.Together.PersonOf(entry.w, membersStore)
    totals[person] = (totals[person] or 0) + entry.a
  end
  return totals
end

-- As `limit` pessoas que mais doaram: { { name, amount }, ... }.
function Donations.Ranking(totals, limit)
  local list = ns.Together.Ranking(totals, limit)
  for _, item in ipairs(list) do item.amount, item.seconds = item.seconds, nil end
  return list
end

---------------------------------------------------------------------------
-- Mensagens
---------------------------------------------------------------------------

-- Lista de depósitos: "<quantidade>" e "<quem><valor><horário>" de cada um.
function Donations.Encode(entries)
  local parts = { Field(#entries) }
  for _, entry in ipairs(entries) do
    parts[#parts + 1] = Field(entry.w) .. Field(entry.a) .. Field(entry.t)
  end
  return table.concat(parts)
end

function Donations.Decode(payload)
  local f = type(payload) == "string" and ns.Codec.ReadFields(payload)
  if not f then return nil end
  local count = Int(f[1])
  if not count or #f ~= 1 + 3 * count then return nil end
  local entries = {}
  for k = 1, count do
    local base = 3 * k - 1
    local entry = { w = f[base], a = Int(f[base + 1]), t = Int(f[base + 2]) }
    if not Donations.IsValid(entry) then return nil end
    entries[k] = entry
  end
  return entries
end

ns.Donations = Donations
return Donations
