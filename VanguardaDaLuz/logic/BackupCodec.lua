-- String de backup VDLB1 (docs/formato-string-backup.md): os dados do addon
-- para o site guardar e, de volta, para restaurar no jogo. Também leva as
-- alterações de eventos entre os membros (logic/Protocol.lua, E e C).
-- Lógica pura: depende só da LibDeflate, recebida em ns.LibDeflate.
--
--   VDLB1:<adler32>:<EncodeForPrint(deflate(payload))>
--
-- Payload com a mesma codificação de campos "<bytes>:<valor>" da string VDL1,
-- em seções, cada uma começando pela quantidade de itens:
--   cabeçalho (6): VDLB, 1, game, generatedAt, exportNumber, generatedBy
--   eventos:       id, origin, title, startsAt, description, organizer,
--                  status, updatedAt, maxAttendees, guestsAllowed, changedBy
--   presenças:     id do evento, registros; por registro: personagem,
--                  situação, updatedAt (como na VDLP1)
--   profissões:    personagem, updatedAt, quantidade; por profissão: id,
--                  nível, máximo, nome
--   membros:       personagem, updatedAt, item level, main
--   tempo junto:   personagem, segundos
local _, ns = ...

local BackupCodec = {}

local MARKER, FORMAT_VERSION = "VDLB", "1"
local HEADER_FIELDS = 6
local EVENT_FIELDS = 11
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

local function SortedKeys(t)
  local keys = {}
  for k in pairs(t or {}) do keys[#keys + 1] = k end
  table.sort(keys)
  return keys
end

---------------------------------------------------------------------------
-- Montagem
---------------------------------------------------------------------------

local function EventFields(parts, e)
  local guests = ""
  if e.guests ~= nil then guests = e.guests and "1" or "0" end
  parts[#parts + 1] = Field(e.id) .. Field(e.origin or "site") .. Field(e.title) .. Field(e.startsAt)
    .. Field(e.description or "") .. Field(e.organizer or "") .. Field(e.status) .. Field(e.updatedAt)
    .. Field(e.max or 0) .. Field(guests) .. Field(e.by or "")
end

-- Monta o payload. `data` = { game, generatedAt, exportNumber, generatedBy,
-- events = lista, attendance, professions, members, together } (stores nos
-- formatos de logic/Attendance, Professions, Members e Together). Tudo em
-- ordem alfabética, para a mesma entrada gerar sempre a mesma string.
function BackupCodec.BuildPayload(data)
  local parts = {
    Field(MARKER), Field(FORMAT_VERSION), Field(data.game), Field(data.generatedAt),
    Field(data.exportNumber or 0), Field(data.generatedBy or ""),
  }

  local events = {}
  for _, e in ipairs(data.events or {}) do events[#events + 1] = e end
  table.sort(events, function(a, b) return a.id < b.id end)
  parts[#parts + 1] = Field(#events)
  for _, e in ipairs(events) do EventFields(parts, e) end

  local attendance = data.attendance or {}
  local ids = SortedKeys(attendance)
  parts[#parts + 1] = Field(#ids)
  for _, id in ipairs(ids) do
    local names = SortedKeys(attendance[id])
    parts[#parts + 1] = Field(id) .. Field(#names)
    for _, who in ipairs(names) do
      local r = attendance[id][who]
      parts[#parts + 1] = Field(who) .. Field(r.s) .. Field(r.t)
    end
  end

  local professions = data.professions or {}
  local names = SortedKeys(professions)
  parts[#parts + 1] = Field(#names)
  for _, who in ipairs(names) do
    local record = professions[who]
    parts[#parts + 1] = Field(who) .. Field(record.t) .. Field(#record.p)
    for _, p in ipairs(record.p) do
      parts[#parts + 1] = Field(p.i or 0) .. Field(p.l) .. Field(p.m) .. Field(p.n)
    end
  end

  local members = data.members or {}
  names = SortedKeys(members)
  parts[#parts + 1] = Field(#names)
  for _, who in ipairs(names) do
    local r = members[who]
    parts[#parts + 1] = Field(who) .. Field(r.t) .. Field(r.i) .. Field(r.m or "")
  end

  local together = data.together or {}
  names = SortedKeys(together)
  parts[#parts + 1] = Field(#names)
  for _, who in ipairs(names) do parts[#parts + 1] = Field(who) .. Field(together[who]) end

  return table.concat(parts)
end

function BackupCodec.Encode(data)
  local LibDeflate = ns.LibDeflate
  local payload = BackupCodec.BuildPayload(data)
  local encoded = LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(payload))
  return MARKER .. FORMAT_VERSION .. ":" .. LibDeflate:Adler32(payload) .. ":" .. encoded
end

---------------------------------------------------------------------------
-- Leitura
---------------------------------------------------------------------------

-- Cada leitor recebe os campos e o índice atual, preenche `result` e retorna
-- o próximo índice, ou nil se a seção é inválida.

local function ReadEvents(f, i, result)
  local count = Int(f[i])
  if not count then return nil end
  i = i + 1
  local seen = {}
  for _ = 1, count do
    if i + EVENT_FIELDS - 1 > #f then return nil end
    local max, guests = Int(f[i + 8]), f[i + 9]
    if not max or (guests ~= "" and guests ~= "1" and guests ~= "0") then return nil end
    local e = {
      id = f[i], origin = f[i + 1], title = f[i + 2], startsAt = Int(f[i + 3]),
      description = f[i + 4], organizer = f[i + 5], status = f[i + 6], updatedAt = Int(f[i + 7]),
      max = max > 0 and max or nil, by = f[i + 10],
    }
    if guests ~= "" then e.guests = guests == "1" end
    if not ns.GameEvents.IsValid(e) or seen[e.id] then return nil end
    seen[e.id] = true
    result.events[#result.events + 1] = e
    i = i + EVENT_FIELDS
  end
  return i
end

local function ReadAttendance(f, i, result)
  local count = Int(f[i])
  if not count then return nil end
  i = i + 1
  for _ = 1, count do
    local id, records = f[i], Int(f[i + 1])
    if not id or id == "" or not records or result.attendance[id] then return nil end
    local list = {}
    i = i + 2
    for _ = 1, records do
      local who, status, at = f[i], Int(f[i + 1]), Int(f[i + 2])
      if not ValidName(who) or list[who] or (status ~= 0 and status ~= 1) or not at then return nil end
      list[who] = { s = status, t = at }
      i = i + 3
    end
    result.attendance[id] = list
  end
  return i
end

local function ReadProfessions(f, i, result)
  local count = Int(f[i])
  if not count then return nil end
  i = i + 1
  for _ = 1, count do
    local who, at, n = f[i], Int(f[i + 1]), Int(f[i + 2])
    if not ValidName(who) or result.professions[who] or not at or not n or n > MAX_PROFESSIONS then return nil end
    local list = {}
    i = i + 3
    for k = 1, n do
      local id, level, max, name = Int(f[i]), Int(f[i + 1]), Int(f[i + 2]), f[i + 3]
      if not id or not level or not max or not ValidName(name) then return nil end
      list[k] = { n = name, l = level, m = max, i = id > 0 and id or nil }
      i = i + 4
    end
    result.professions[who] = { t = at, p = list }
  end
  return i
end

local function ReadMembers(f, i, result)
  local count = Int(f[i])
  if not count then return nil end
  i = i + 1
  for _ = 1, count do
    local who, at, level, main = f[i], Int(f[i + 1]), Int(f[i + 2]), f[i + 3]
    if not ValidName(who) or result.members[who] or not at or not level or not main then return nil end
    local record = { t = at, i = level, m = main ~= "" and main or nil }
    if not ns.Members.IsValid(record) then return nil end
    result.members[who] = record
    i = i + 4
  end
  return i
end

local function ReadTogether(f, i, result)
  local count = Int(f[i])
  if not count then return nil end
  i = i + 1
  for _ = 1, count do
    local who, seconds = f[i], Int(f[i + 1])
    if not ValidName(who) or result.together[who] or not seconds then return nil end
    result.together[who] = seconds
    i = i + 2
  end
  return i
end

-- Decodifica. Retorna { game, generatedAt, exportNumber, generatedBy, events,
-- attendance, professions, members, together } ou nil e o código do erro (os
-- mesmos de ns.Codec.ERRORS).
function BackupCodec.Decode(text)
  local LibDeflate = ns.LibDeflate
  if type(text) ~= "string" then return nil, "empty" end
  text = ns.Text.Trim(text)
  if text == "" then return nil, "empty" end
  local version, checksum, encoded = string.match(text, "^VDLB(%d+):(%d+):(.+)$")
  if not version then return nil, "prefix" end
  if version ~= FORMAT_VERSION then return nil, "version" end
  local compressed = LibDeflate:DecodeForPrint(encoded)
  if not compressed then return nil, "encoding" end
  local payload = LibDeflate:DecompressDeflate(compressed)
  if not payload then return nil, "compression" end
  if LibDeflate:Adler32(payload) ~= tonumber(checksum) then return nil, "checksum" end

  local f = ns.Codec.ReadFields(payload)
  if not f or #f < HEADER_FIELDS or f[1] ~= MARKER then return nil, "payload" end
  if f[2] ~= FORMAT_VERSION then return nil, "version" end
  local result = {
    game = f[3], generatedAt = Int(f[4]), exportNumber = Int(f[5]), generatedBy = f[6],
    events = {}, attendance = {}, professions = {}, members = {}, together = {},
  }
  if not (result.generatedAt and result.exportNumber) then return nil, "payload" end

  local i = HEADER_FIELDS + 1
  for _, read in ipairs({ ReadEvents, ReadAttendance, ReadProfessions, ReadMembers, ReadTogether }) do
    i = read(f, i, result)
    if not i then return nil, "payload" end
  end
  if i ~= #f + 1 then return nil, "payload" end
  return result
end

-- Quantidades de cada seção (resumo na tela).
function BackupCodec.Counts(data)
  local counts = { events = #data.events, attendance = 0, professions = 0, members = 0, together = 0 }
  for _, list in pairs(data.attendance) do
    for _ in pairs(list) do counts.attendance = counts.attendance + 1 end
  end
  for _, key in ipairs({ "professions", "members", "together" }) do
    for _ in pairs(data[key]) do counts[key] = counts[key] + 1 end
  end
  return counts
end

ns.BackupCodec = BackupCodec
return BackupCodec
