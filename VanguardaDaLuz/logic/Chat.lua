-- Bate-papo da guilda na janela do addon: canais e o texto de cada linha.
-- Lógica pura.
--
-- Uma mensagem (`entry`) vem de game/GuildChat.lua:
--   { id, clock = "20:31", name = "Nome Sobrenome", color = "|cffRRGGBB" ou nil,
--     main = nome do main (só para alts) ou nil, content = texto,
--     secret = true quando o jogo entrega o texto como valor secreto,
--     time = segundos Unix, epoch = horário do jogo (marcador de leitura) }
local _, ns = ...

local Text = ns.Text

local Chat = {}

Chat.PLAYER_LINK = "vdlplayer" -- |Hvdlplayer:<nome>|h: clique no nome
Chat.URL_LINK = "vdlurl"       -- |Hvdlurl:<url>|h: clique num link da mensagem
Chat.MAX_LENGTH = 255          -- limite de uma mensagem no chat do jogo

-- Texto protegido: o histórico do clube entrega o conteúdo como "|Kw774|k", uma
-- referência que o jogo troca pelo texto na hora de desenhar (o addon não lê
-- o texto). Não pode ser escapado nem cortado.
local PROTECTED = "|K[^|]*|k"

-- O texto da mensagem é só uma referência protegida?
function Chat.IsProtected(content)
  return type(content) == "string" and string.find(content, "^" .. PROTECTED .. "$") ~= nil
end

-- Link do jogo como o Shift+clique põe na caixa: "|cff…|Hitem:…|h[Nome]|h|r".
-- A cor pode vir no formato antigo (|cffRRGGBB) ou no novo, por nome
-- (|cnIQ3: = qualidade do item; é o que o WoW Forever usa). O nome pode ter
-- ícones dentro (localização do mapa: "[|A:Waypoint-MapPin-ChatIcon…|a Local…]").
local GAME_LINKS = { "|c[^|]+|H[^|]+|h.-|h|r", "|H[^|]+|h.-|h" }
-- Ícones soltos no texto: atlas (|A…|a) e textura (|T…|t).
local ICONS = { "|A[^|]*|a", "|T[^|]*|t" }

-- O trecho que começa primeiro entre os padrões, a partir de `pos`.
local function NextMatch(text, pos, patterns)
  local first, last
  for _, pattern in ipairs(patterns) do
    local f, l = string.find(text, pattern, pos)
    if f and (not first or f < first) then first, last = f, l end
  end
  return first, last
end

-- Próximo link do jogo a partir de `pos`.
local function NextLink(text, pos)
  return NextMatch(text, pos, GAME_LINKS)
end

-- O que passa como veio nas mensagens recebidas: links, ícones e texto protegido.
local KEEP = { GAME_LINKS[1], GAME_LINKS[2], ICONS[1], ICONS[2], PROTECTED }

-- Corpo da mensagem: links clicáveis e "|" escapado, menos nas referências
-- protegidas, nos links do jogo (item, missão, mapa...) e nos ícones, que
-- passam como vieram.
local function Body(content, linkColor)
  local parts, pos = {}, 1
  while true do
    local first, last = NextMatch(content, pos, KEEP)
    if not first then break end
    parts[#parts + 1] = Text.Linkify(string.sub(content, pos, first - 1), Chat.URL_LINK, linkColor)
    parts[#parts + 1] = string.sub(content, first, last)
    pos = last + 1
  end
  parts[#parts + 1] = Text.Linkify(string.sub(content, pos), Chat.URL_LINK, linkColor)
  return table.concat(parts)
end

-- Canais da guilda a partir dos streams do clube: { guild = id, officer = id }.
-- `types` = { guild = Enum.ClubStreamType.Guild, officer = ...Officer }.
function Chat.Streams(streams, types)
  local found = {}
  for _, stream in ipairs(streams or {}) do
    if stream.streamType == types.guild and not found.guild then found.guild = stream.streamId end
    if stream.streamType == types.officer and not found.officer then found.officer = stream.streamId end
  end
  return found
end

-- Linha pronta para o quadro de mensagens:
-- "20:31  Nome (alt de Main): texto com links".
-- `muted` e `linkColor` são códigos de cor; `altLabel` é o texto "alt de %s".
function Chat.Line(entry, muted, linkColor, altLabel)
  -- Texto secreto (nome ou mensagem) não pode ser lido nem alterado, só
  -- exibido como veio: sem link no nome e sem links na mensagem.
  if entry.secret then
    return muted .. (entry.clock or "") .. "|r  " .. (entry.name or "?") .. ": " .. entry.content
  end
  local name = Text.Escape(entry.name or "?")
  local shown = entry.color and (entry.color .. name .. "|r") or name
  local parts = {
    muted, entry.clock or "", "|r  ",
    "|H", Chat.PLAYER_LINK, ":", name, "|h", shown, "|h",
  }
  if entry.main then
    parts[#parts + 1] = muted .. " (" .. string.format(altLabel, Text.Escape(entry.main)) .. ")|r"
  end
  parts[#parts + 1] = ": "
  return table.concat(parts) .. Body(entry.content or "", linkColor)
end

-- Texto normal de uma mensagem do histórico, achado entre as mensagens
-- recebidas pelo chat ao vivo (`recent` = { { guid, name, time, text }, ... }):
-- mesmo autor e horário com até `tolerance` segundos de diferença. `used`
-- marca as já usadas, para duas mensagens iguais não pegarem o mesmo texto.
function Chat.MatchRecent(recent, guid, name, time, tolerance, used)
  for i, item in ipairs(recent) do
    if not used[i] and ((guid and item.guid == guid) or (not guid and item.name == name))
      and math.abs(item.time - time) <= tolerance then
      used[i] = true
      return item.text
    end
  end
  return nil
end

-- Junta os blocos de mensagens que o jogo tem carregados de um canal. O
-- histórico pode ter buracos (mensagens de quando o jogador estava offline
-- formam um bloco à parte); cada bloco é uma lista de { id, epoch, position,
-- ... }. Retorna as mensagens da mais antiga para a mais nova, sem repetir, e
-- o índice do bloco mais novo.
local function Before(a, b)
  if a.epoch ~= b.epoch then return a.epoch < b.epoch end
  return a.position < b.position
end

function Chat.MergeRanges(blocks)
  local list, seen, newest, newestLast = {}, {}, nil, nil
  for i, block in ipairs(blocks) do
    for _, m in ipairs(block) do
      if not seen[m.id] then
        seen[m.id] = true
        list[#list + 1] = m
      end
      if not newestLast or Before(newestLast, m) then newest, newestLast = i, m end
    end
  end
  table.sort(list, Before)
  return list, newest
end

-- Linhas do quadro com os separadores, como no chat da Blizzard:
--   { entry = mensagem }
--   { separator = "day", day = "today"|"yesterday"|"date", time = horário }
--     antes da primeira mensagem de cada dia;
--   { separator = "unread" } antes da primeira mensagem mais nova que o
--     marcador de leitura do canal (`marker`, no mesmo formato de `epoch`; nil
--     = sem separador).
-- Cada mensagem precisa de `time` (segundos Unix) e `epoch`. `now` e
-- `offset` (fuso local em segundos) definem hoje e ontem.
local function DayKey(ts, offset)
  local f = ns.Time.Fields(ts, offset)
  return f.year * 10000 + f.month * 100 + f.day
end

function Chat.Rows(entries, now, offset, marker)
  local rows = {}
  local today, yesterday = DayKey(now, offset), DayKey(now - 86400, offset)
  local lastDay, unread = nil, marker == nil
  for _, entry in ipairs(entries) do
    local key = DayKey(entry.time or 0, offset)
    if key ~= lastDay then
      lastDay = key
      local day = key == today and "today" or key == yesterday and "yesterday" or "date"
      rows[#rows + 1] = { separator = "day", day = day, time = entry.time or 0 }
    end
    if not unread and (entry.epoch or 0) > marker then
      unread = true
      rows[#rows + 1] = { separator = "unread" }
    end
    rows[#rows + 1] = { entry = entry }
  end
  return rows
end

-- Lê o destino de um link clicado: ("player", nome) ou ("url", endereço).
function Chat.ParseLink(link)
  if type(link) ~= "string" then return nil end
  local kind, value = string.match(link, "^(%w+):(.+)$")
  if kind == Chat.PLAYER_LINK then return "player", value end
  if kind == Chat.URL_LINK then return "url", value end
  return nil
end

-- Texto digitado comum: uma linha só e sem "|" (o chat do jogo recusa códigos
-- de escape; vira "/", como no alerta).
local function Plain(text)
  return (string.gsub(Text.ForGame(text), "\n", " "))
end

-- Texto digitado pronto para enviar, ou nil se vazio. Links do jogo (item,
-- missão...) passam inteiros; no resto, "|" vira "/". Respeita o limite do
-- chat: o texto comum é cortado sem quebrar caracteres, e um link que não
-- cabe inteiro fica de fora.
function Chat.Outgoing(text)
  if type(text) ~= "string" then return nil end
  local parts, pos = {}, 1
  while true do
    local first, last = NextLink(text, pos)
    if not first then break end
    parts[#parts + 1] = { plain = Plain(string.sub(text, pos, first - 1)) }
    parts[#parts + 1] = { link = string.sub(text, first, last) }
    pos = last + 1
  end
  parts[#parts + 1] = { plain = Plain(string.sub(text, pos)) }
  -- Espaços nas pontas saem antes de medir.
  parts[1].plain = string.gsub(parts[1].plain or "", "^[%c ]+", "")
  parts[#parts].plain = string.gsub(parts[#parts].plain or "", "[%c ]+$", "")

  local out, size = {}, 0
  for _, part in ipairs(parts) do
    local piece = part.link or part.plain
    if size + #piece > Chat.MAX_LENGTH then
      if part.plain then out[#out + 1] = Text.Truncate(piece, Chat.MAX_LENGTH - size) end
      break
    end
    out[#out + 1] = piece
    size = size + #piece
  end
  local message = Text.Trim(table.concat(out))
  if message == "" then return nil end
  return message
end

ns.Chat = Chat
return Chat
