-- Tudo o que depende da versão do jogo (WoW Forever). Um addon do Retail teria
-- um Flavor_Retail.lua com a mesma interface e outro .toc.
local _, ns = ...

local Flavor = {
  id = "forever",
  label = "WoW Forever",
  interface = 16001,
  -- Valor do campo `game` aceito na string de exportação.
  exportGame = "forever",
}

-- Janela "Guilda e comunidades" da interface padrão, onde o addon põe as
-- abas Eventos, Profissões e Administração (ui/GuildTabs.lua). Nomes
-- conferidos no WoW Forever: botões laterais de 32x32, um abaixo do outro
-- com 20 de espaço.
Flavor.guildWindow = {
  addon = "Blizzard_Communities",
  frame = "CommunitiesFrame",
  list = "CommunitiesList",   -- lista de comunidades à esquerda
  lastTab = "GuildInfoTab",   -- as abas do addon ficam abaixo deste botão
  infoTab = "GuildInfoTab",   -- aba Informações, coberta pelo Início do addon
  rosterTab = "RosterTab",    -- aba Membros, coberta pela lista do addon
  chatTab = "ChatTab",        -- aba Bate-papo, coberta pelo bate-papo do addon
  memberList = "MemberList",  -- lista de membros (linhas com SetMember)
  memberEntryMixin = "CommunitiesMemberListEntryMixin",
  -- Botões "Editar" da aba Informações (host.GuildDetailsFrame.Info) e a
  -- janela de edição da Blizzard. Confirmados no jogo: acionados por um botão
  -- seguro do addon (type "click"), gravam; chamados pelo addon, são bloqueados.
  details = { "GuildDetailsFrame", "Info" },
  editButtons = { motd = "EditMOTDButton", info = "EditDetailsButton" },
  textEditFrame = "CommunitiesGuildTextEditFrame",
  -- Botão Guilda do menu do jogo: acionado por um botão seguro, abre a janela
  -- da guilda sem bloquear a edição depois (confirmado no jogo).
  openButton = "GuildMicroButton",
  -- Botão de convite da janela da guilda (filho de CommunitiesFrame; a
  -- Blizzard só o mostra no modo Bate-papo). Acionado por um botão seguro do
  -- addon, mesmo escondido, abre a janela de convite da Blizzard e convida;
  -- convidar pelo código do addon é bloqueado (os dois confirmados no jogo).
  inviteButton = "InviteButton",
  tabs = { "ChatTab", "RosterTab", "GuildBenefitsTab", "GuildInfoTab" },
  tabGap = 20,
  minWidth = 700,             -- largura normal: 814; minimizada é bem menor
  icons = {
    professions = "Interface\\Icons\\Trade_BlackSmithing",
    admin = "Interface\\Icons\\INV_Misc_Key_03",
  },
}

-- As funções abaixo só rodam dentro do jogo.

-- Últimas leituras legíveis, usadas enquanto o jogo entrega os dados como
-- secretos (luta com chefe e outras restrições).
local lastMembers, lastRoster, lastClub, lastStreams
local lastMessages = {}

-- Comunicação de addons bloqueada (encontros de chefe, M+, JxJ)?
function Flavor.InMessagingLockdown()
  if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
    return C_ChatInfo.InChatMessagingLockdown() and true or false
  end
  if InChatMessagingLockdown then
    return InChatMessagingLockdown() and true or false
  end
  return false
end

-- Publica uma linha no chat da guilda. O canal GUILD não exige clique.
function Flavor.SendGuildChat(text)
  if C_ChatInfo and C_ChatInfo.SendChatMessage then
    C_ChatInfo.SendChatMessage(text, "GUILD")
  elseif SendChatMessage then
    SendChatMessage(text, "GUILD")
  else
    return false
  end
  return true
end

-- Envia uma mensagem no chat da guilda ("GUILD") ou de oficiais ("OFFICER").
-- Retorna true, ou false e o erro do jogo.
function Flavor.SendChat(text, channel)
  local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
  if not send then return false, "SendChatMessage" end
  local ok, err = pcall(send, text, channel)
  if ok then return true end
  return false, tostring(err)
end

-- Canais do chat em que o personagem está, como GetChannelList() devolve
-- (id, nome, desativado, ...). Nada se os valores vierem secretos.
function Flavor.ChatChannels()
  if not GetChannelList then return end
  local values = { pcall(GetChannelList) }
  if not table.remove(values, 1) then return end
  for i = 1, #values do
    if Flavor.IsSecret(values[i]) then return end
  end
  return unpack(values)
end

-- Envia uma mensagem num canal do chat pelo número (`id`). Só funciona a
-- partir de um clique ou tecla da pessoa. Retorna true, ou false e o erro.
function Flavor.SendChannelMessage(text, id)
  local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
  if not send then return false, "SendChatMessage" end
  local ok, err = pcall(send, text, "CHANNEL", nil, tostring(id))
  if ok then return true end
  return false, tostring(err)
end

-- Canais do bate-papo da guilda no clube da guilda (C_Club): o bate-papo da
-- guilda e o de oficiais são "streams" (tipos 1 e 2, confirmado no jogo).
-- Retorna o clube e { guild = streamId, officer = streamId }, ou nil.
function Flavor.GuildChatStreams()
  if not (C_Club and C_Club.GetGuildClubId and C_Club.GetStreams) then return nil end
  local club = C_Club.GetGuildClubId()
  if Flavor.IsSecret(club) then return lastClub, lastStreams end
  if not club then return nil end
  local streams = C_Club.GetStreams(club)
  if Flavor.IsSecret(streams) then return lastClub, lastStreams end
  for _, stream in ipairs(streams or {}) do
    if Flavor.AnySecret(stream, stream.streamId, stream.streamType) then return lastClub, lastStreams end
  end
  local types = Enum and Enum.ClubStreamType or {}
  lastClub = club
  lastStreams = ns.Chat.Streams(streams, { guild = types.Guild or 1, officer = types.Officer or 2 })
  return lastClub, lastStreams
end

-- Mensagens de um bloco do histórico (C_Club.GetMessagesInRange), ou nil se
-- a lista vier secreta.
local function ReadMessages(messages)
  if Flavor.IsSecret(messages) then return nil end
  local list = {}
  for _, m in ipairs(messages or {}) do
    local id = not Flavor.IsSecret(m) and m.messageId or nil
    -- Mensagem sem identificação legível (restrição do jogo): fica de fora.
    if id and not Flavor.AnySecret(id, id.epoch, id.position, m.destroyed, m.author) and not m.destroyed then
      local author = m.author or {}
      local epoch, position = id.epoch or 0, id.position or 0
      list[#list + 1] = {
        id = epoch .. ":" .. position, epoch = epoch, position = position,
        time = math.floor(epoch / 1000000),
        name = author.name, guid = author.guid,
        content = m.content,
        secret = Flavor.AnySecret(m.content, author.name, author.guid),
      }
    end
  end
  return list
end

-- Mensagens já carregadas de um canal, da mais antiga para a mais nova:
-- { { id, epoch, position, time, name, guid, content, secret }, ... }. Inclui
-- as de antes do login (histórico do clube, confirmado no jogo: as últimas
-- 100). O histórico pode vir em vários blocos, com buracos entre eles (o
-- separador "Mensagens não lidas" da Blizzard fica no começo do mais novo);
-- todos entram. O segundo retorno, quando há buraco, é o ID (do jogo) da
-- mensagem mais antiga do bloco mais novo, para pedir as anteriores a ela.
function Flavor.GuildChatMessages(club, stream)
  local list = {}
  if not (club and stream and C_Club.GetMessageRanges and C_Club.GetMessagesInRange) then return list end
  local ranges = C_Club.GetMessageRanges(club, stream)
  if Flavor.IsSecret(ranges) then return lastMessages[stream] or list end
  local blocks, used = {}, {}
  for _, range in ipairs(ranges or {}) do
    if Flavor.IsSecret(range) or Flavor.AnySecret(range.oldestMessageId, range.newestMessageId) then
      return lastMessages[stream] or list
    end
    local block = ReadMessages(C_Club.GetMessagesInRange(club, stream, range.oldestMessageId,
      range.newestMessageId))
    if not block then return lastMessages[stream] or list end
    blocks[#blocks + 1], used[#blocks + 1] = block, range
  end
  local newest
  list, newest = ns.Chat.MergeRanges(blocks)
  lastMessages[stream] = list
  local gap = #blocks > 1 and newest and used[newest].oldestMessageId or nil
  return list, gap
end

-- Valor secreto (Midnight: em encontros, alguns textos chegam ilegíveis para
-- addons; dá para exibir, mas não ler nem comparar)?
--
-- Em lutas com chefe (e outras restrições) o jogo também entrega tabelas
-- secretas: a lista de membros do clube, por exemplo. Ler o tamanho ou os
-- campos delas dá erro.
function Flavor.IsSecret(value)
  if value == nil then return false end
  if issecretvalue and issecretvalue(value) then return true end
  if type(value) == "table" then
    if issecrettable and issecrettable(value) then return true end
    if canaccesstable and not canaccesstable(value) then return true end
  end
  return false
end

-- Algum dos valores é secreto?
function Flavor.AnySecret(...)
  for i = 1, select("#", ...) do
    if Flavor.IsSecret((select(i, ...))) then return true end
  end
  return false
end

-- Clique num link do jogo (item, missão, feitiço, conquista...): faz o mesmo
-- que no chat da Blizzard (SetItemRef abre o tooltip do item ou da missão;
-- com Shift, põe o link na caixa do chat).
function Flavor.OpenGameLink(link, text, button, owner)
  if not SetItemRef then return false end
  return pcall(SetItemRef, link, text, button, owner) and true or false
end

-- Tooltip de um link do jogo (item, missão, feitiço...) junto do mouse.
-- Links que o tooltip não conhece não mostram nada.
function Flavor.ShowLinkTooltip(owner, link)
  GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
  if pcall(GameTooltip.SetHyperlink, GameTooltip, link) then
    GameTooltip:Show()
  else
    GameTooltip:Hide()
  end
end

-- Shift+clique num item, missão etc. chama a função do jogo que põe o link na
-- caixa do chat aberta. `callback(link)` é chamado depois dela, para o addon
-- pôr o link na própria caixa quando ela está com o foco. Observa os dois
-- nomes da função (o antigo pode só repassar para o novo): o mesmo link no
-- mesmo instante só conta uma vez.
function Flavor.OnChatLinkInsert(callback)
  local lastLink, lastTime
  local function Hook(link)
    local now = GetTime()
    if link == lastLink and now == lastTime then return end
    lastLink, lastTime = link, now
    callback(link)
  end
  if ChatFrameUtil and ChatFrameUtil.InsertLink then hooksecurefunc(ChatFrameUtil, "InsertLink", Hook) end
  if ChatEdit_InsertLink then hooksecurefunc("ChatEdit_InsertLink", Hook) end
end

-- Pede ao servidor o histórico de um canal do clube: as `count` mensagens
-- anteriores a `before` (ID do jogo), ou as mais recentes se `before` for nil.
-- O jogo só carrega o histórico de um canal quando alguém pede: o da guilda
-- já vem pelo chat da Blizzard, o de oficiais não. A resposta chega no evento
-- CLUB_MESSAGE_HISTORY_RECEIVED.
function Flavor.RequestChatHistory(club, stream, count, before)
  if not (club and stream and C_Club and C_Club.RequestMoreMessagesBefore) then return false end
  return pcall(C_Club.RequestMoreMessagesBefore, club, stream, before, count) and true or false
end

-- Hora local ("20:31") de um horário Unix.
function Flavor.Clock(seconds)
  return date("%H:%M", seconds)
end

-- Fuso do computador em segundos (o mesmo de Flavor.Clock), para separar as
-- mensagens do bate-papo por dia.
function Flavor.LocalOffset(seconds)
  seconds = seconds or time()
  -- Os campos UTC lidos como horário local, com o mesmo horário de verão.
  local utc = date("!*t", seconds)
  utc.isdst = date("*t", seconds).isdst
  return seconds - time(utc)
end

-- Marcador de leitura de um canal do clube (o que a Blizzard usa para o
-- separador "Mensagens não lidas"), no formato do `epoch` das mensagens. nil
-- se o jogo não informa ou entrega secreto.
function Flavor.ChatViewMarker(club, stream)
  if not (club and stream and C_Club and C_Club.GetStreamViewMarker) then return nil end
  local ok, marker = pcall(C_Club.GetStreamViewMarker, club, stream)
  if not ok or Flavor.IsSecret(marker) or type(marker) ~= "number" then return nil end
  return marker
end

-- Marca o canal como lido (a Blizzard faz o mesmo ao mostrar o canal).
function Flavor.MarkChatRead(club, stream)
  if not (club and stream and C_Club and C_Club.AdvanceStreamViewMarker) then return end
  pcall(C_Club.AdvanceStreamViewMarker, club, stream)
end

-- Mostra o texto no quadro do aviso de raide da interface padrão.
-- Retorna false se o quadro não existir (o addon usa a faixa própria).
function Flavor.ShowRaidWarning(text, color)
  if not (RaidNotice_AddMessage and RaidWarningFrame) then return false end
  return pcall(RaidNotice_AddMessage, RaidWarningFrame, text, color) and true or false
end

-- Som padrão do aviso de raide.
function Flavor.PlayRaidWarningSound()
  if not PlaySound then return end
  PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959)
end

-- Membros da guilda pela lista de comunidades (C_Club): nome como no roster,
-- online e nomes das profissões primárias. O nível que vem aqui é sempre 1 no
-- WoW Forever e não é usado. Retorna nil se a lista ainda não carregou.
function Flavor.GuildMembers()
  if not (C_Club and C_Club.GetGuildClubId) then return nil end
  local club = C_Club.GetGuildClubId()
  if Flavor.IsSecret(club) then return lastMembers end
  if not club then return nil end
  local ids = C_Club.GetClubMembers(club)
  -- Em luta com chefe a lista vem secreta: vale a última lida.
  if Flavor.IsSecret(ids) then return lastMembers end
  if not ids or #ids == 0 then return nil end
  local presence = Enum and Enum.ClubMemberPresence or {}
  local members = {}
  for _, id in ipairs(ids) do
    local info = C_Club.GetMemberInfo(club, id)
    if Flavor.IsSecret(info) or (info and Flavor.AnySecret(info.name, info.presence, info.profession1Name,
      info.profession1ID, info.profession2Name, info.profession2ID)) then
      return lastMembers
    end
    if info and info.name then
      local state = info.presence
      local professions, professionIds = {}, {}
      local pairsOf = { { info.profession1Name, info.profession1ID }, { info.profession2Name, info.profession2ID } }
      for _, p in ipairs(pairsOf) do
        if p[1] and p[1] ~= "" then
          professions[#professions + 1] = p[1]
          professionIds[#professions] = p[2]
        end
      end
      members[#members + 1] = {
        name = info.name,
        online = state == presence.Online or state == presence.Away or state == presence.Busy,
        status = (state == presence.Away and "away") or (state == presence.Busy and "busy") or nil,
        professions = professions,
        professionIds = professionIds,
      }
    end
  end
  lastMembers = members
  return members
end

-- Profissões primárias do próprio personagem: { { n, l, m, i }, ... }. `i` é o
-- ID da profissão (sétimo valor de GetProfessionInfo; 164 = Ferraria), igual
-- em todos os idiomas e igual ao profession1ID/profession2ID do C_Club.
function Flavor.OwnProfessions()
  if not (GetProfessions and GetProfessionInfo) then return nil end
  local list = {}
  local first, second = GetProfessions()
  for _, index in ipairs({ first or false, second or false }) do
    if index then
      local name, _, level, max, _, _, id = GetProfessionInfo(index)
      if name then list[#list + 1] = { n = name, l = level or 0, m = max or 0, i = id } end
    end
  end
  return list
end

-- Item level equipado do próprio personagem, arredondado (nil se o jogo não
-- informar).
function Flavor.OwnItemLevel()
  if not GetAverageItemLevel then return nil end
  local _, equipped = GetAverageItemLevel()
  if type(equipped) ~= "number" then return nil end
  return math.floor(equipped + 0.5)
end

-- Ausente/ocupado no roster: número (1 ausente, 2 ocupado) ou texto ("<AFK>").
local function RosterStatus(status)
  if status == 1 or status == "<AFK>" or status == "<Ausente>" then return "away" end
  if status == 2 or status == "<DND>" or status == "<Ocupado>" then return "busy" end
  return nil
end

-- Horas desde a última entrada do membro `i` do roster (offline), ou nil.
local function LastOnline(i)
  if not GetGuildRosterLastOnline then return nil end
  local ok, years, months, days, hours = pcall(GetGuildRosterLastOnline, i)
  if not ok or Flavor.AnySecret(years, months, days, hours) then return nil end
  if type(years) ~= "number" then return nil end
  return (((years * 12 + (months or 0)) * 30 + (days or 0)) * 24) + (hours or 0)
end

-- Roster da guilda para a lista de membros: { { name, rank, rankIndex, level,
-- class, classFile, zone, online, status, guid, lastOnline }, ... }
-- (lastOnline = horas desde a última entrada, só de quem está offline). Conferido no WoW
-- Forever: o nome vem como "Nome Sobrenome" e classFile como "ROGUE".
--
-- Com o roster secreto (restrição do jogo, como em luta com chefe), vale o
-- último lido.
function Flavor.GuildRoster()
  local entries = {}
  if not (GetNumGuildMembers and GetGuildRosterInfo) then return entries end
  local count = GetNumGuildMembers()
  if Flavor.IsSecret(count) then return lastRoster or entries end
  for i = 1, count or 0 do
    local name, rank, rankIndex, level, class, zone, _, _, online, status, classFile =
      GetGuildRosterInfo(i)
    local guid = select(17, GetGuildRosterInfo(i))
    if Flavor.AnySecret(name, rank, rankIndex, level, class, zone, online, status, classFile, guid) then
      return lastRoster or {}
    end
    if name then
      entries[#entries + 1] = { name = name, rank = rank, rankIndex = rankIndex, level = level,
        class = class, classFile = classFile, zone = zone, online = online and true or false,
        status = RosterStatus(status), guid = guid, lastOnline = not online and LastOnline(i) or nil }
    end
  end
  lastRoster = entries
  return entries
end

-- Código de cor da classe ("|cffrrggbb"), ou nil.
function Flavor.ClassColorCode(classFile)
  local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
  if color and color.colorStr then return "|c" .. color.colorStr end
  return nil
end

-- Estado do grupo para o tempo com a guilda: o jogador ({ afk, zone }) e
-- quem está no grupo ({ guild, connected, afk, zone }). Os membros são
-- achados no roster pelo GUID, porque UnitName("party1") traz só o primeiro
-- nome no WoW Forever; a zona vem do roster.
function Flavor.GroupState()
  local byGuid = {}
  for _, entry in ipairs(Flavor.GuildRoster()) do
    if entry.guid then byGuid[entry.guid] = entry end
  end
  local player = { afk = UnitIsAFK("player") and true or false, zone = GetZoneText() }
  local group = {}
  local count = GetNumGroupMembers() or 0
  local raid = IsInRaid()
  for i = 1, raid and count or count - 1 do
    local unit = (raid and "raid" or "party") .. i
    if UnitExists(unit) and not UnitIsUnit(unit, "player") then
      local guid = UnitGUID(unit)
      local entry = not Flavor.IsSecret(guid) and byGuid[guid] or nil
      group[#group + 1] = {
        guild = entry ~= nil,
        connected = UnitIsConnected(unit) and true or false,
        afk = (UnitIsAFK(unit) or (entry and entry.status == "away")) and true or false,
        zone = entry and entry.zone,
      }
    end
  end
  return player, group
end

-- O clube selecionado na janela da guilda é a guilda do jogador?
-- Botão "Editar" da Blizzard para a mensagem do dia ("motd") ou as
-- informações ("info"), ou nil se a janela da guilda não carregou.
function Flavor.GuildTextEditButton(kind)
  local spec = Flavor.guildWindow
  local frame = _G[spec.frame]
  for _, key in ipairs(spec.details) do frame = frame and frame[key] end
  return frame and frame[spec.editButtons[kind]] or nil
end

-- Botão de convite da Blizzard na janela da guilda, ou nil se ela não carregou.
function Flavor.GuildInviteButton()
  local frame = _G[Flavor.guildWindow.frame]
  return frame and frame[Flavor.guildWindow.inviteButton] or nil
end

-- Botão Guilda do menu do jogo (abre a janela da guilda), ou nil.
function Flavor.GuildOpenButton()
  return _G[Flavor.guildWindow.openButton]
end

-- A janela da guilda está aberta?
function Flavor.IsGuildWindowShown()
  local frame = _G[Flavor.guildWindow.frame]
  return frame ~= nil and frame:IsShown() and true or false
end

-- O jogo deixa este personagem editar a mensagem do dia ou as informações?
function Flavor.CanEditGuildText(kind)
  local fn = kind == "motd" and CanEditMOTD or CanEditGuildInfo
  return fn ~= nil and fn() and true or false
end

function Flavor.IsGuildClubSelected(host)
  if not (host and host.GetSelectedClubId and C_Club and C_Club.GetGuildClubId) then return false end
  local guild, selected = C_Club.GetGuildClubId(), host:GetSelectedClubId()
  if Flavor.AnySecret(guild, selected) then return false end
  return guild ~= nil and selected == guild
end

-- O posto deste personagem tem a permissão "Convidar membros" da guilda?
-- Segue a configuração dos postos no jogo, não os nomes dos postos. Em luta
-- com chefe o valor pode vir secreto: vale o último lido.
local lastCanInvite = false
function Flavor.CanGuildInvite()
  if not CanGuildInvite then return false end
  local can = CanGuildInvite()
  if Flavor.IsSecret(can) then return lastCanInvite end
  lastCanInvite = can and true or false
  return lastCanInvite
end

-- Mapa-múndi da Blizzard (o addon desenha os membros por cima dele).
Flavor.worldMap = { addon = "Blizzard_WorldMap", frame = "WorldMapFrame" }

function Flavor.WorldMap()
  return _G[Flavor.worldMap.frame]
end

-- Posição do próprio personagem: { map, x, y, taxi }, ou nil quando o jogo não
-- a dá (instâncias) ou a esconde (valores secretos).
function Flavor.PlayerMapPosition()
  if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
  local ok, map, x, y = pcall(function()
    local id = C_Map.GetBestMapForUnit("player")
    if Flavor.IsSecret(id) or type(id) ~= "number" then return nil end
    local position = C_Map.GetPlayerMapPosition(id, "player")
    if not position or Flavor.IsSecret(position) then return nil end
    local px, py = position:GetXY()
    if Flavor.AnySecret(px, py) then return nil end
    return id, px, py
  end)
  if not (ok and map and type(x) == "number" and type(y) == "number") then return nil end
  local taxi = UnitOnTaxi and UnitOnTaxi("player")
  if Flavor.IsSecret(taxi) then taxi = false end
  return { map = map, x = x, y = y, taxi = taxi and true or false }
end

-- Retângulo (minX, maxX, minY, maxY) do mapa `a` dentro do mapa `b`, ou nil.
function Flavor.MapRect(a, b)
  if not (C_Map and C_Map.GetMapRectOnMap) then return nil end
  local ok, minX, maxX, minY, maxY = pcall(C_Map.GetMapRectOnMap, a, b)
  if not ok or Flavor.AnySecret(minX, maxX, minY, maxY) then return nil end
  if type(minX) ~= "number" or type(maxX) ~= "number" or type(minY) ~= "number" or type(maxY) ~= "number" then
    return nil
  end
  return minX, maxX, minY, maxY
end

-- Convida para o grupo.
function Flavor.InviteToGroup(name)
  if C_PartyInfo and C_PartyInfo.InviteUnit then
    C_PartyInfo.InviteUnit(name)
  elseif InviteUnit then
    InviteUnit(name)
  end
end

-- Qual convite de grupo o menu do membro mostra: "INVITE" (convidar),
-- "SUGGEST_INVITE" (sugerir ao líder, quando estou num grupo sem ser líder
-- nem assistente) ou "REQUEST_INVITE" (pedir para entrar, quando estou sem
-- grupo e a pessoa está num). Usa a função do próprio jogo, a mesma do menu
-- da Blizzard (Blizzard_LFGUtil); sem ela, ou com valor secreto, "INVITE".
local INVITE_TYPES = { INVITE = true, SUGGEST_INVITE = true, REQUEST_INVITE = true }
function Flavor.GroupInviteType(guid)
  if type(GetDisplayedInviteType) ~= "function" or Flavor.IsSecret(guid) then return "INVITE" end
  local ok, kind = pcall(GetDisplayedInviteType, guid)
  if not ok or Flavor.IsSecret(kind) or not INVITE_TYPES[kind] then return "INVITE" end
  return kind
end

-- A pessoa já está no meu grupo ou raide?
function Flavor.InGroupWith(name)
  local ok, party, raid = pcall(function() return UnitInParty(name), UnitInRaid(name) end)
  if not ok or Flavor.AnySecret(party, raid) then return false end
  return (party and true or false) or raid ~= nil
end

-- Pede para entrar no grupo da pessoa (C_PartyInfo.RequestInviteFromUnit,
-- como o menu da Blizzard).
function Flavor.RequestGroupInvite(name)
  if C_PartyInfo and C_PartyInfo.RequestInviteFromUnit then
    C_PartyInfo.RequestInviteFromUnit(name)
  end
end

-- Abre o chat com "/w <nome> ".
function Flavor.Whisper(name)
  if ChatFrameUtil and ChatFrameUtil.SendTell then
    ChatFrameUtil.SendTell(name)
  elseif ChatFrame_SendTell then
    ChatFrame_SendTell(name)
  end
end

ns.Flavor = Flavor
return Flavor
