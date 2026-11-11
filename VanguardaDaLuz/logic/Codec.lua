-- Decodificação e codificação da string de exportação (docs/formato-string-addon.md).
-- Lógica pura: depende só da LibDeflate, recebida em ns.LibDeflate.
local _, ns = ...

local Codec = {}

local HEADER_FIELDS, EVENT_FIELDS = 7, 7
local FORMAT_VERSION = "1"

Codec.HEADER_FIELDS = HEADER_FIELDS
Codec.EVENT_FIELDS = EVENT_FIELDS

-- Mensagens dos códigos de erro de Codec.Decode e Import.Prepare.
Codec.ERRORS = {
  empty = "Cole a string de exportação gerada no site.",
  size = "A string passa do tamanho máximo aceito.",
  prefix = "Isto não é uma string de exportação da Vanguarda da Luz (deve começar com VDL).",
  version = "Esta string usa uma versão do formato que este addon não conhece. Atualize o addon.",
  encoding = "A string tem caracteres inválidos. Copie de novo pelo botão \"Copiar\" do site.",
  compression = "A string está incompleta ou corrompida. Copie de novo pelo botão \"Copiar\" do site.",
  checksum = "A string está corrompida: o checksum não confere. Copie de novo pelo botão \"Copiar\" do site.",
  payload = "O conteúdo da string é inválido.",
  game = "Esta exportação é de outra versão do jogo. Exporte os eventos do WoW Forever no site.",
  old = "Esta exportação é igual ou mais antiga que a última importada.",
}

-- Lê os campos "<bytes>:<valor>" do payload. Retorna a lista ou nil.
function Codec.ReadFields(payload)
  local fields, pos, size = {}, 1, #payload
  while pos <= size do
    local colon = string.find(payload, ":", pos, true)
    if not colon then return nil end
    local digits = string.sub(payload, pos, colon - 1)
    if not string.find(digits, "^%d+$") then return nil end
    local last = colon + tonumber(digits)
    if last > size then return nil end
    fields[#fields + 1] = string.sub(payload, colon + 1, last)
    pos = last + 1
  end
  return fields
end

local function Int(value)
  if not value or not string.find(value, "^%d+$") then return nil end
  return tonumber(value)
end

local function Trim(text)
  text = string.gsub(text, "^[%c ]+", "")
  text = string.gsub(text, "[%c ]+$", "")
  return text
end

-- Decodifica a string. Retorna a exportação ou nil e o código do erro
-- (ver Codec.ERRORS). `maxLength` é opcional.
function Codec.Decode(text, maxLength)
  local LibDeflate = ns.LibDeflate
  if type(text) ~= "string" then return nil, "empty" end
  text = Trim(text)
  if text == "" then return nil, "empty" end
  if maxLength and #text > maxLength then return nil, "size" end

  local version, checksum, data = string.match(text, "^VDL(%d+):(%d+):(.+)$")
  if not version then return nil, "prefix" end
  if version ~= FORMAT_VERSION then return nil, "version" end

  local compressed = LibDeflate:DecodeForPrint(data)
  if not compressed then return nil, "encoding" end
  local payload = LibDeflate:DecompressDeflate(compressed)
  if not payload then return nil, "compression" end
  if LibDeflate:Adler32(payload) ~= tonumber(checksum) then return nil, "checksum" end

  local f = Codec.ReadFields(payload)
  if not f or #f < HEADER_FIELDS or f[1] ~= "VDL" then return nil, "payload" end
  if f[2] ~= FORMAT_VERSION then return nil, "version" end
  local count = Int(f[7])
  if not count or #f ~= HEADER_FIELDS + count * EVENT_FIELDS then return nil, "payload" end

  local result = {
    version = 1,
    game = f[3],
    exportNumber = Int(f[4]),
    windowStart = Int(f[5]),
    windowEnd = Int(f[6]),
    count = count,
    events = {},
  }
  if result.game ~= "forever" and result.game ~= "retail" then return nil, "payload" end
  if not (result.exportNumber and result.windowStart and result.windowEnd) then
    return nil, "payload"
  end
  if result.windowEnd <= result.windowStart then return nil, "payload" end

  local seen = {}
  for i = HEADER_FIELDS + 1, #f, EVENT_FIELDS do
    local event = {
      id = f[i],
      title = f[i + 1],
      startsAt = Int(f[i + 2]),
      description = f[i + 3],
      organizer = f[i + 4],
      status = f[i + 5],
      updatedAt = Int(f[i + 6]),
    }
    if event.id == "" or seen[event.id] or not event.startsAt or not event.updatedAt
      or (event.status ~= "ativo" and event.status ~= "cancelado") then
      return nil, "payload"
    end
    seen[event.id] = true
    result.events[#result.events + 1] = event
  end
  return result
end

local function Field(value)
  value = tostring(value)
  return #value .. ":" .. value
end

-- Monta o payload de uma exportação (mesma ordem de campos do site).
function Codec.BuildPayload(export)
  local parts = {
    Field("VDL"), Field(FORMAT_VERSION), Field(export.game),
    Field(export.exportNumber), Field(export.windowStart), Field(export.windowEnd),
    Field(#export.events),
  }
  for _, e in ipairs(export.events) do
    parts[#parts + 1] = Field(e.id) .. Field(e.title) .. Field(e.startsAt)
      .. Field(e.description) .. Field(e.organizer) .. Field(e.status) .. Field(e.updatedAt)
  end
  return table.concat(parts)
end

-- Gera a string "VDL1:<checksum>:<dados>" (usado nos testes).
function Codec.Encode(export)
  local LibDeflate = ns.LibDeflate
  local payload = Codec.BuildPayload(export)
  local data = LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(payload))
  return "VDL" .. FORMAT_VERSION .. ":" .. LibDeflate:Adler32(payload) .. ":" .. data
end

ns.Codec = Codec
return Codec
