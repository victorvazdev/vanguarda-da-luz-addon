-- Bate-papo da guilda na janela do addon: lê as mensagens dos canais da
-- guilda e de oficiais (histórico do clube, C_Club) e envia pelo chat do jogo.
-- Texto das linhas em logic/Chat.lua.
--
-- Uma fonte só: o histórico do clube já inclui as mensagens novas. Os eventos
-- de chat avisam que algo chegou, e o painel relê o histórico.
--
-- O histórico entrega o texto protegido ("|Kw774|k"): o jogo mostra o texto,
-- mas o addon não lê, então não acha links nele. As mensagens que chegam com
-- o jogo aberto vêm em texto normal pelos eventos de chat; esse texto fica
-- guardado nesta sessão e substitui o protegido (mesmo autor e horário).
local _, ns = ...

local L = ns.L

local GuildChat = {}

local REFRESH_DELAY = 0.2 -- espera o clube registrar a mensagem que acabou de chegar
local MATCH_TOLERANCE = 5 -- segundos entre o evento de chat e o horário no clube
local RECENT_MAX = 300
local CHANNELS = { guild = "GUILD", officer = "OFFICER" }
local EVENT_CHANNEL = { CHAT_MSG_GUILD = "guild", CHAT_MSG_OFFICER = "officer" }

local pending = false
local recent = { guild = {}, officer = {} } -- texto normal recebido nesta sessão
local requested = {} -- [stream] = true: histórico já pedido ao servidor
local gaps = {}      -- [stream] = { [ID do buraco] = true, n = pedidos }: buracos já pedidos
local GAP_REQUESTS_MAX = 5 -- pedidos para preencher buracos, por canal e sessão
local HISTORY_COUNT = 100

local function Changed()
  if pending then return end
  pending = true
  C_Timer.After(REFRESH_DELAY, function()
    pending = false
    ns.Fire("CHAT_UPDATED")
  end)
end

-- Mensagem de chat recebida: guarda o texto normal (12º valor = GUID do autor).
function GuildChat.OnEvent(_, event, text, sender, ...)
  local channel = EVENT_CHANNEL[event]
  if channel and type(text) == "string" and not ns.Flavor.IsSecret(text) and not ns.Flavor.IsSecret(sender) then
    local guid = select(10, ...)
    local list = recent[channel]
    list[#list + 1] = { guid = not ns.Flavor.IsSecret(guid) and guid or nil, name = sender,
      time = GetServerTime(), text = text }
    if #list > RECENT_MAX then table.remove(list, 1) end
  end
  Changed()
end

function GuildChat.Init()
  local events = CreateFrame("Frame")
  for _, name in ipairs({ "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CLUB_MESSAGE_ADDED", "CLUB_MESSAGE_UPDATED",
    "CLUB_STREAMS_LOADED", "CLUB_MESSAGE_HISTORY_RECEIVED" }) do
    pcall(events.RegisterEvent, events, name)
  end
  events:SetScript("OnEvent", GuildChat.OnEvent)
end

-- Canais disponíveis: { guild = true, officer = true }. O de oficiais só para
-- o Grão Lorde e os Lordes, e só se o jogo deixa ler.
function GuildChat.Channels()
  local _, streams = ns.Flavor.GuildChatStreams()
  streams = streams or {}
  return { guild = streams.guild ~= nil, officer = streams.officer ~= nil and ns.Guild.IsPlayerTrusted() }
end

-- Mensagens de um canal ("guild" ou "officer") prontas para logic/Chat.Line:
-- nome na cor da classe e main de quem é alt.
function GuildChat.Entries(channel)
  local club, streams = ns.Flavor.GuildChatStreams()
  if not club then return {} end
  local stream = streams[channel]
  local raw, gap = ns.Flavor.GuildChatMessages(club, stream)
  -- Canal sem histórico carregado (o de oficiais, em geral): pede uma vez; a
  -- resposta chega por evento e o painel relê.
  if #raw == 0 and stream and not requested[stream] then
    requested[stream] = true
    ns.Flavor.RequestChatHistory(club, stream, HISTORY_COUNT)
  end
  -- Histórico com buraco: pede as mensagens anteriores ao bloco mais novo,
  -- uma vez por buraco e no máximo GAP_REQUESTS_MAX vezes por canal.
  if gap and stream then
    local asked = gaps[stream] or { n = 0 }
    gaps[stream] = asked
    local key = type(gap) == "table" and ((gap.epoch or 0) .. ":" .. (gap.position or 0)) or tostring(gap)
    if not asked[key] and asked.n < GAP_REQUESTS_MAX then
      asked[key], asked.n = true, asked.n + 1
      ns.Flavor.RequestChatHistory(club, stream, HISTORY_COUNT, gap)
    end
  end
  local byGuid, byName = {}, {}
  for _, entry in ipairs(ns.Flavor.GuildRoster()) do
    if entry.guid then byGuid[entry.guid] = entry end
    byName[entry.name] = entry
  end
  local entries, used = {}, {}
  for _, m in ipairs(raw) do
    local content = m.content
    if not m.secret and ns.Chat.IsProtected(content) then
      content = ns.Chat.MatchRecent(recent[channel] or {}, m.guid, m.name, m.time, MATCH_TOLERANCE, used) or content
    end
    local entry = { id = m.id, clock = ns.Flavor.Clock(m.time), content = content, secret = m.secret,
      name = m.name, time = m.time, epoch = m.epoch }
    if not m.secret then
      local member = (m.guid and byGuid[m.guid]) or (m.name and byName[m.name])
      if member then
        entry.name = member.name
        entry.color = ns.Flavor.ClassColorCode(member.classFile)
      end
      local record = ns.GuildMembers.Get(entry.name)
      if record and record.m and record.m ~= entry.name then entry.main = record.m end
    end
    entries[#entries + 1] = entry
  end
  return entries
end

-- Marcador de leitura do canal ("guild" ou "officer"), ou nil.
function GuildChat.ViewMarker(channel)
  local club, streams = ns.Flavor.GuildChatStreams()
  return club and ns.Flavor.ChatViewMarker(club, streams[channel]) or nil
end

-- Marca o canal como lido.
function GuildChat.MarkRead(channel)
  local club, streams = ns.Flavor.GuildChatStreams()
  if club then ns.Flavor.MarkChatRead(club, streams[channel]) end
end

-- Envia o texto digitado no canal. Retorna true, ou false e a mensagem de erro.
function GuildChat.Send(channel, text)
  local message = ns.Chat.Outgoing(text)
  if not message then return false end
  if ns.Flavor.InMessagingLockdown() then
    return false, L["Comunicação restrita no momento (encontro, Mítica+ ou JxJ). A mensagem não foi enviada."]
  end
  local ok, err = ns.Flavor.SendChat(message, CHANNELS[channel] or "GUILD")
  if not ok then
    return false, L["Não foi possível enviar a mensagem."] .. (err and (" (" .. err .. ")") or "")
  end
  return true
end

ns.GuildChat = GuildChat
