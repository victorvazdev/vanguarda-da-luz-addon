-- Item level e main/alt dos membros da guilda. Lógica pura.
--
-- O jogo só informa o item level do próprio personagem, então cada addon
-- anuncia o seu. O main é definido uma vez por conta; os outros personagens da
-- conta na guilda viram alts dele ao logar.
--
-- `store` = { [personagem] = { t = horário, i = item level, m = main } }
--   personagem: nome completo como no roster ("Nome Sobrenome")
--   t: horário da leitura (segundos Unix); vale o registro mais recente
--   i: item level equipado, arredondado
--   m: nome do main da conta (igual ao personagem = é o main; nil = não definido)
local _, ns = ...

local Members = {}

local MAX_ITEM_LEVEL = 9999

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

-- Registro válido? { i, m }.
function Members.IsValid(record)
  if type(record) ~= "table" or type(record.i) ~= "number" then return false end
  if record.i < 0 or record.i > MAX_ITEM_LEVEL or record.i ~= math.floor(record.i) then return false end
  return record.m == nil or ValidName(record.m)
end

-- Registra os dados de um personagem. Retorna true se mudou o estado.
function Members.Set(store, who, record, at)
  if not ValidName(who) or type(at) ~= "number" or not Members.IsValid(record) then return false end
  local current = store[who]
  if current and current.t >= at then return false end
  store[who] = { t = at, i = record.i, m = record.m }
  return true
end

-- Mesmo item level e mesmo main?
function Members.Same(a, b)
  return a ~= nil and b ~= nil and a.i == b.i and a.m == b.m
end

-- Mescla outro `store`. Retorna quantos personagens mudaram.
function Members.Merge(store, other)
  local changed = 0
  for who, record in pairs(other) do
    if Members.Set(store, who, record, record.t) then changed = changed + 1 end
  end
  return changed
end

-- Apaga quem não está mais na guilda. `members` = { [nome] = true }.
function Members.Prune(store, members)
  for who in pairs(store) do
    if not members[who] then store[who] = nil end
  end
end

-- Main de um personagem, a partir do main da conta. Só vale se o main ainda
-- está na guilda (`members` = { [nome] = true }).
function Members.MainFor(accountMain, members)
  if ValidName(accountMain) and members[accountMain] then return accountMain end
  return nil
end

---------------------------------------------------------------------------
-- Mensagens
---------------------------------------------------------------------------

local function RecordFields(record)
  return Field(record.i) .. Field(record.m or "")
end

-- Lê um registro a partir de f[i]. Retorna o registro e o próximo índice, ou nil.
local function ReadRecord(f, i)
  local level, main = Int(f[i]), f[i + 1]
  if not level or not main then return nil end
  local record = { i = level, m = main ~= "" and main or nil }
  if not Members.IsValid(record) then return nil end
  return record, i + 2
end

-- Dados do próprio remetente: "<item level><main ou vazio>".
function Members.EncodeOwn(record)
  return RecordFields(record)
end

function Members.DecodeOwn(payload)
  local f = type(payload) == "string" and ns.Codec.ReadFields(payload)
  if not f then return nil end
  local record, i = ReadRecord(f, 1)
  if not record or i ~= #f + 1 then return nil end
  return record
end

-- Todos os dados conhecidos: "<personagens>" e, por personagem,
-- "<nome><horário><item level><main>", em ordem alfabética.
function Members.EncodeStore(store)
  local names = {}
  for who in pairs(store) do names[#names + 1] = who end
  table.sort(names)
  local parts = { Field(#names) }
  for _, who in ipairs(names) do
    parts[#parts + 1] = Field(who) .. Field(store[who].t) .. RecordFields(store[who])
  end
  return table.concat(parts)
end

function Members.DecodeStore(payload)
  local f = type(payload) == "string" and ns.Codec.ReadFields(payload)
  if not f then return nil end
  local count = Int(f[1])
  if not count then return nil end
  local store, i = {}, 2
  for _ = 1, count do
    local who, at = f[i], Int(f[i + 1])
    if not ValidName(who) or not at or store[who] then return nil end
    local record
    record, i = ReadRecord(f, i + 2)
    if not record then return nil end
    record.t = at
    store[who] = record
  end
  if i ~= #f + 1 then return nil end
  return store
end

---------------------------------------------------------------------------
-- Exibição
---------------------------------------------------------------------------

-- Texto curto para a linha da lista de membros: "231 · Main", "231 · Alt",
-- "231", ou nil sem dados.
function Members.Short(who, record)
  if not record then return nil end
  if record.m == who then return record.i .. " · " .. ns.L["Main"] end
  if record.m then return record.i .. " · " .. ns.L["Alt"] end
  return tostring(record.i)
end

-- Texto completo para o tooltip: "Item level 231 · Alt de Victor Vaz".
function Members.Detail(who, record)
  if not record then return nil end
  local text = string.format(ns.L["Item level %d"], record.i)
  if record.m == who then return text .. " · " .. ns.L["Main"] end
  if record.m then return text .. " · " .. string.format(ns.L["Alt de %s"], record.m) end
  return text
end

ns.Members = Members
return Members
