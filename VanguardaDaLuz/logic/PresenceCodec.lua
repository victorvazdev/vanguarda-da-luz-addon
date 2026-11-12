-- String de presenças do jogo para o site (docs/formato-string-presencas.md).
-- Lógica pura: depende só da LibDeflate, recebida em ns.LibDeflate.
--
--   VDLP1:<adler32>:<EncodeForPrint(deflate(payload))>
--
-- Payload com a mesma codificação de campos "<bytes>:<valor>" da string VDL1:
--   cabeçalho (6): VDLP, 1, game, generatedAt, exportNumber, eventCount
--   por evento:    id, recordCount
--   por registro:  personagem, situação (1 ou 0), updatedAt
local _, ns = ...

local PresenceCodec = {}

local MARKER, FORMAT_VERSION = "VDLP", "1"
local HEADER_FIELDS = 6

local function Field(value)
  value = tostring(value)
  return #value .. ":" .. value
end

local function Int(value)
  if not value or not string.find(value, "^%d+$") then return nil end
  return tonumber(value)
end

local function SortedKeys(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys)
  return keys
end

-- Monta o payload. `data` = { game, generatedAt, exportNumber, store } (store
-- no formato de logic/Attendance.lua). Eventos e personagens em ordem
-- alfabética, para a mesma entrada gerar sempre a mesma string.
function PresenceCodec.BuildPayload(data)
  local ids = SortedKeys(data.store)
  local parts = {
    Field(MARKER), Field(FORMAT_VERSION), Field(data.game),
    Field(data.generatedAt), Field(data.exportNumber or 0), Field(#ids),
  }
  for _, id in ipairs(ids) do
    local list = data.store[id]
    local names = SortedKeys(list)
    parts[#parts + 1] = Field(id) .. Field(#names)
    for _, who in ipairs(names) do
      local record = list[who]
      parts[#parts + 1] = Field(who) .. Field(record.s) .. Field(record.t)
    end
  end
  return table.concat(parts)
end

function PresenceCodec.Encode(data)
  local LibDeflate = ns.LibDeflate
  local payload = PresenceCodec.BuildPayload(data)
  local encoded = LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(payload))
  return MARKER .. FORMAT_VERSION .. ":" .. LibDeflate:Adler32(payload) .. ":" .. encoded
end

-- Decodifica. Retorna { game, generatedAt, exportNumber, store } ou nil e o
-- código do erro (os mesmos de ns.Codec.ERRORS).
function PresenceCodec.Decode(text)
  local LibDeflate = ns.LibDeflate
  if type(text) ~= "string" then return nil, "empty" end
  text = ns.Text.Trim(text)
  if text == "" then return nil, "empty" end
  local version, checksum, encoded = string.match(text, "^VDLP(%d+):(%d+):(.+)$")
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
    game = f[3], generatedAt = Int(f[4]), exportNumber = Int(f[5]), store = {},
  }
  local eventCount = Int(f[6])
  if not (result.generatedAt and result.exportNumber and eventCount) then return nil, "payload" end

  local i = HEADER_FIELDS + 1
  for _ = 1, eventCount do
    local id, count = f[i], Int(f[i + 1])
    if not id or id == "" or not count or result.store[id] then return nil, "payload" end
    local list = {}
    i = i + 2
    for _ = 1, count do
      local who, status, at = f[i], Int(f[i + 1]), Int(f[i + 2])
      if not who or who == "" or list[who] or (status ~= 0 and status ~= 1) or not at then
        return nil, "payload"
      end
      list[who] = { s = status, t = at }
      i = i + 3
    end
    result.store[id] = list
  end
  if i ~= #f + 1 then return nil, "payload" end
  return result
end

ns.PresenceCodec = PresenceCodec
return PresenceCodec
