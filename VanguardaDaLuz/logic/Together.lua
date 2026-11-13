-- Tempo de jogo com a guilda: quanto tempo cada personagem passou em grupo
-- com outro membro da guilda, na mesma zona, sem nenhum dos dois ausente.
-- Lógica pura.
--
-- Cada addon conta só o próprio tempo. O total só cresce, então ao receber
-- dados de outro membro vale o maior valor (não precisa de horário).
--
-- `store` = { [personagem] = segundos }
-- Por pessoa: os alts somam no main (logic/Members.lua, campo `m`).
local _, ns = ...

local Together = {}

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

local function ValidSeconds(seconds)
  return type(seconds) == "number" and seconds >= 0 and seconds == math.floor(seconds)
end

-- Soma segundos ao próprio personagem.
function Together.Add(store, who, seconds)
  if not ValidName(who) or not ValidSeconds(seconds) then return end
  store[who] = (store[who] or 0) + seconds
end

-- Registra o total recebido de outro membro, se for maior. Retorna true se mudou.
function Together.Set(store, who, seconds)
  if not ValidName(who) or not ValidSeconds(seconds) then return false end
  if store[who] and store[who] >= seconds then return false end
  store[who] = seconds
  return true
end

function Together.Merge(store, other)
  local changed = 0
  for who, seconds in pairs(other) do
    if Together.Set(store, who, seconds) then changed = changed + 1 end
  end
  return changed
end

function Together.Prune(store, members)
  for who in pairs(store) do
    if not members[who] then store[who] = nil end
  end
end

-- Este minuto conta? `me` = { afk, zone }; `group` = lista de quem está no
-- grupo: { { guild, connected, afk, zone }, ... }. Conta se o jogador não está
-- ausente e há pelo menos um membro da guilda conectado, não ausente e na
-- mesma zona.
function Together.Counts(me, group)
  if not me or me.afk or not me.zone or me.zone == "" then return false end
  for _, other in ipairs(group or {}) do
    if other.guild and other.connected and not other.afk and other.zone == me.zone then return true end
  end
  return false
end

---------------------------------------------------------------------------
-- Mensagens
---------------------------------------------------------------------------

-- Total do próprio remetente: "<segundos>".
function Together.EncodeOwn(seconds)
  return Field(seconds)
end

function Together.DecodeOwn(payload)
  local f = type(payload) == "string" and ns.Codec.ReadFields(payload)
  if not f or #f ~= 1 then return nil end
  return Int(f[1])
end

-- Todos os totais conhecidos: "<personagens>" e "<nome><segundos>" em ordem.
function Together.EncodeStore(store)
  local names = {}
  for who in pairs(store) do names[#names + 1] = who end
  table.sort(names)
  local parts = { Field(#names) }
  for _, who in ipairs(names) do parts[#parts + 1] = Field(who) .. Field(store[who]) end
  return table.concat(parts)
end

function Together.DecodeStore(payload)
  local f = type(payload) == "string" and ns.Codec.ReadFields(payload)
  if not f then return nil end
  local count = Int(f[1])
  if not count or #f ~= 1 + 2 * count then return nil end
  local store = {}
  for k = 1, count do
    local who, seconds = f[2 * k], Int(f[2 * k + 1])
    if not ValidName(who) or not seconds or store[who] then return nil end
    store[who] = seconds
  end
  return store
end

---------------------------------------------------------------------------
-- Por pessoa
---------------------------------------------------------------------------

-- Pessoa de um personagem: o main dele, se definido; senão o próprio nome.
function Together.PersonOf(who, membersStore)
  local record = membersStore and membersStore[who]
  return record and record.m or who
end

-- Total por pessoa: { [pessoa] = segundos }.
function Together.Totals(store, membersStore)
  local totals = {}
  for who, seconds in pairs(store) do
    local person = Together.PersonOf(who, membersStore)
    totals[person] = (totals[person] or 0) + seconds
  end
  return totals
end

-- As `limit` pessoas com mais tempo: { { name, seconds }, ... }, sem quem tem 0.
function Together.Ranking(totals, limit)
  local list = {}
  for name, seconds in pairs(totals) do
    if seconds > 0 then list[#list + 1] = { name = name, seconds = seconds } end
  end
  table.sort(list, function(a, b)
    if a.seconds ~= b.seconds then return a.seconds > b.seconds end
    return a.name < b.name
  end)
  for i = #list, (limit or #list) + 1, -1 do list[i] = nil end
  return list
end

-- "12h 40min", "35min" ou "0min".
function Together.Format(seconds)
  local minutes = math.floor((seconds or 0) / 60)
  local hours = math.floor(minutes / 60)
  minutes = minutes % 60
  if hours > 0 then return string.format("%dh %02dmin", hours, minutes) end
  return minutes .. "min"
end

ns.Together = Together
return Together
