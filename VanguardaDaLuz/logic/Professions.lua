-- Profissões dos membros da guilda. Lógica pura.
--
-- A lista da guilda do jogo informa quais profissões primárias cada membro tem,
-- mas não o nível (vem sempre 1 no WoW Forever). O nível vem do addon de cada
-- membro, que lê as próprias profissões e anuncia para a guilda.
--
-- `store` = { [personagem] = { t = horário, p = { { n = nome, l = nível, m = máximo, i = id }, ... } } }
--   personagem: nome completo como no roster ("Nome Sobrenome")
--   t: horário da leitura (segundos Unix); vale o registro mais recente
--   i: ID da profissão (igual em todos os idiomas); nil quando veio de uma
--      versão antiga do addon, que só manda o nome. O nível é casado com a
--      lista da guilda pelo ID e, sem ele, pelo nome (que muda com o idioma).
local _, ns = ...

local Professions = {}

local MAX_PROFESSIONS = 2

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

-- Lista de profissões válida? { { n, l, m }, ... }, no máximo 2.
function Professions.IsValidList(list)
  if type(list) ~= "table" or #list > MAX_PROFESSIONS then return false end
  for _, p in ipairs(list) do
    if not ValidName(p.n) or type(p.l) ~= "number" or type(p.m) ~= "number" then return false end
    if p.l < 0 or p.m < 0 then return false end
    if p.i ~= nil and (type(p.i) ~= "number" or p.i <= 0) then return false end
  end
  return true
end

local function CopyList(list)
  local copy = {}
  for i, p in ipairs(list) do copy[i] = { n = p.n, l = p.l, m = p.m, i = p.i } end
  return copy
end

-- A lista traz IDs que a outra (do mesmo horário) não tem?
local function AddsIds(old, new)
  local oldIds, newIds = false, false
  for _, p in ipairs(old) do oldIds = oldIds or p.i ~= nil end
  for _, p in ipairs(new) do newIds = newIds or p.i ~= nil end
  return newIds and not oldIds
end

-- Registra as profissões de um personagem. Retorna true se mudou o estado.
-- No mesmo horário, a versão com IDs substitui a só com nomes (o mesmo anúncio
-- chega nos dois formatos).
function Professions.Set(store, who, list, at)
  if not ValidName(who) or type(at) ~= "number" or not Professions.IsValidList(list) then return false end
  local current = store[who]
  if current and (current.t > at or (current.t == at and not AddsIds(current.p, list))) then return false end
  store[who] = { t = at, p = CopyList(list) }
  return true
end

-- As duas listas têm as mesmas profissões e níveis?
function Professions.SameList(a, b)
  if not a or not b or #a ~= #b then return false end
  for i = 1, #a do
    if a[i].n ~= b[i].n or a[i].l ~= b[i].l or a[i].m ~= b[i].m or a[i].i ~= b[i].i then return false end
  end
  return true
end

-- Mescla outro `store`. Retorna quantos personagens mudaram.
function Professions.Merge(store, other)
  local changed = 0
  for who, record in pairs(other) do
    if Professions.Set(store, who, record.p, record.t) then changed = changed + 1 end
  end
  return changed
end

-- Apaga quem não está mais na guilda. `members` = { [nome] = true }.
function Professions.Prune(store, members)
  for who in pairs(store) do
    if not members[who] then store[who] = nil end
  end
end

---------------------------------------------------------------------------
-- Mensagens
---------------------------------------------------------------------------

-- Dois formatos de lista: o antigo (F e K), "<nome><nível><máximo>" por
-- profissão, e o com IDs (J e X), "<id><nível><máximo><nome>". `withIds`
-- escolhe o formato.
local function ListFields(parts, list, withIds)
  parts[#parts + 1] = Field(#list)
  for _, p in ipairs(list) do
    if withIds then
      parts[#parts + 1] = Field(p.i or 0) .. Field(p.l) .. Field(p.m) .. Field(p.n)
    else
      parts[#parts + 1] = Field(p.n) .. Field(p.l) .. Field(p.m)
    end
  end
end

-- Lê uma lista a partir de f[i]. Retorna a lista e o próximo índice, ou nil.
local function ReadList(f, i, withIds)
  local count = Int(f[i])
  if not count or count > MAX_PROFESSIONS then return nil end
  local list = {}
  i = i + 1
  for k = 1, count do
    local name, level, max, id
    if withIds then
      id, level, max, name = Int(f[i]), Int(f[i + 1]), Int(f[i + 2]), f[i + 3]
      if not id then return nil end
      i = i + 4
    else
      name, level, max = f[i], Int(f[i + 1]), Int(f[i + 2])
      i = i + 3
    end
    if not ValidName(name) or not level or not max then return nil end
    list[k] = { n = name, l = level, m = max, i = id and id > 0 and id or nil }
  end
  return list, i
end

-- Profissões do próprio remetente: "<quantidade>" e a lista.
function Professions.EncodeOwn(list, withIds)
  local parts = {}
  ListFields(parts, list, withIds)
  return table.concat(parts)
end

function Professions.DecodeOwn(payload, withIds)
  local f = type(payload) == "string" and ns.Codec.ReadFields(payload)
  if not f then return nil end
  local list, i = ReadList(f, 1, withIds)
  if not list or i ~= #f + 1 then return nil end
  return list
end

-- Todos os níveis conhecidos: "<personagens>" e, por personagem,
-- "<nome><horário><lista>", em ordem alfabética.
function Professions.EncodeStore(store, withIds)
  local names = {}
  for who in pairs(store) do names[#names + 1] = who end
  table.sort(names)
  local parts = { Field(#names) }
  for _, who in ipairs(names) do
    parts[#parts + 1] = Field(who) .. Field(store[who].t)
    ListFields(parts, store[who].p, withIds)
  end
  return table.concat(parts)
end

function Professions.DecodeStore(payload, withIds)
  local f = type(payload) == "string" and ns.Codec.ReadFields(payload)
  if not f then return nil end
  local count = Int(f[1])
  if not count then return nil end
  local store, i = {}, 2
  for _ = 1, count do
    local who, at = f[i], Int(f[i + 1])
    if not ValidName(who) or not at or store[who] then return nil end
    local list
    list, i = ReadList(f, i + 2, withIds)
    if not list then return nil end
    store[who] = { t = at, p = list }
  end
  if i ~= #f + 1 then return nil end
  return store
end

---------------------------------------------------------------------------
-- Lista exibida
---------------------------------------------------------------------------

-- Profissão conhecida que corresponde à da guilda: pelo ID quando os dois
-- têm; senão, pelo nome.
local function Find(list, name, id)
  for _, p in ipairs(list or {}) do
    if id and p.i then
      if p.i == id then return p end
    elseif p.n == name then
      return p
    end
  end
  return nil
end

-- Junta os membros da guilda com os níveis conhecidos.
-- `members` = { { name, online, status, professions = { "Ferraria", ... },
--   professionIds = { 164, ... } }, ... }
-- Retorna { { name, online, status, professions = { { name, level, max }, ... } }, ... }.
-- As profissões vêm da guilda; sem elas, das que o addon do membro anunciou.
-- O nível é nil quando o addon do membro ainda não informou.
function Professions.BuildRows(members, store)
  local rows = {}
  for _, member in ipairs(members) do
    local known = store[member.name] and store[member.name].p
    local names, ids = member.professions or {}, member.professionIds or {}
    if #names == 0 and known then
      names, ids = {}, {}
      for i, p in ipairs(known) do names[i], ids[i] = p.n, p.i end
    end
    local professions = {}
    for i, name in ipairs(names) do
      local p = Find(known, name, ids[i])
      professions[i] = { name = name, level = p and p.l, max = p and p.m }
    end
    rows[#rows + 1] = { name = member.name, online = member.online and true or false,
      status = member.status, professions = professions }
  end
  return rows
end

-- Nível do membro numa profissão (nil se não tem ou não se sabe).
local function LevelIn(row, profession)
  for _, p in ipairs(row.professions) do
    if p.name == profession then return p.level or -1 end
  end
  return nil
end

-- Filtra e ordena. `options` = { profession, onlineOnly }.
-- Sem profissão: ordem alfabética. Com profissão: maior nível primeiro, e quem
-- não informou o nível no fim.
function Professions.Filter(rows, options)
  options = options or {}
  local result = {}
  for _, row in ipairs(rows) do
    local keep = not options.onlineOnly or row.online
    if keep and options.profession then keep = LevelIn(row, options.profession) ~= nil end
    if keep then result[#result + 1] = row end
  end
  local profession = options.profession
  table.sort(result, function(a, b)
    if profession then
      local la, lb = LevelIn(a, profession), LevelIn(b, profession)
      if la ~= lb then return la > lb end
    end
    local na, nb = string.lower(a.name), string.lower(b.name)
    if na ~= nb then return na < nb end
    return a.name < b.name
  end)
  return result
end

-- Profissões que aparecem na lista, em ordem alfabética (para o filtro).
function Professions.Names(rows)
  local seen, names = {}, {}
  for _, row in ipairs(rows) do
    for _, p in ipairs(row.professions) do
      if not seen[p.name] then
        seen[p.name] = true
        names[#names + 1] = p.name
      end
    end
  end
  table.sort(names)
  return names
end

ns.Professions = Professions
return Professions
