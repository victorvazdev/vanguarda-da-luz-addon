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
  memberList = "MemberList",  -- lista de membros (linhas com SetMember)
  memberEntryMixin = "CommunitiesMemberListEntryMixin",
  tabs = { "ChatTab", "RosterTab", "GuildBenefitsTab", "GuildInfoTab" },
  tabGap = 20,
  minWidth = 700,             -- largura normal: 814; minimizada é bem menor
  icons = {
    professions = "Interface\\Icons\\Trade_BlackSmithing",
    admin = "Interface\\Icons\\INV_Misc_Key_03",
  },
}

-- As funções abaixo só rodam dentro do jogo.

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
  if not club then return nil end
  local ids = C_Club.GetClubMembers(club)
  if not ids or #ids == 0 then return nil end
  local presence = Enum and Enum.ClubMemberPresence or {}
  local members = {}
  for _, id in ipairs(ids) do
    local info = C_Club.GetMemberInfo(club, id)
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

-- Roster da guilda para a lista de membros: { { name, rank, rankIndex, level,
-- class, classFile, zone, online, status, guid }, ... }. Conferido no WoW
-- Forever: o nome vem como "Nome Sobrenome" e classFile como "ROGUE".
function Flavor.GuildRoster()
  local entries = {}
  if not (GetNumGuildMembers and GetGuildRosterInfo) then return entries end
  for i = 1, GetNumGuildMembers() do
    local name, rank, rankIndex, level, class, zone, _, _, online, status, classFile =
      GetGuildRosterInfo(i)
    if name then
      entries[#entries + 1] = { name = name, rank = rank, rankIndex = rankIndex, level = level,
        class = class, classFile = classFile, zone = zone, online = online and true or false,
        status = RosterStatus(status), guid = select(17, GetGuildRosterInfo(i)) }
    end
  end
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
      local entry = byGuid[UnitGUID(unit)]
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
function Flavor.IsGuildClubSelected(host)
  if not (host and host.GetSelectedClubId and C_Club and C_Club.GetGuildClubId) then return false end
  local guild = C_Club.GetGuildClubId()
  return guild ~= nil and host:GetSelectedClubId() == guild
end

-- Convida para o grupo.
function Flavor.InviteToGroup(name)
  if C_PartyInfo and C_PartyInfo.InviteUnit then
    C_PartyInfo.InviteUnit(name)
  elseif InviteUnit then
    InviteUnit(name)
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
