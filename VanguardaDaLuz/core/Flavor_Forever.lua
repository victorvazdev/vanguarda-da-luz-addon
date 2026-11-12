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
      local professions = {}
      for _, name in ipairs({ info.profession1Name or "", info.profession2Name or "" }) do
        if name ~= "" then professions[#professions + 1] = name end
      end
      members[#members + 1] = {
        name = info.name,
        online = state == presence.Online or state == presence.Away or state == presence.Busy,
        professions = professions,
      }
    end
  end
  return members
end

-- Profissões primárias do próprio personagem: { { n, l, m }, ... }.
function Flavor.OwnProfessions()
  if not (GetProfessions and GetProfessionInfo) then return nil end
  local list = {}
  local first, second = GetProfessions()
  for _, index in ipairs({ first or false, second or false }) do
    if index then
      local name, _, level, max = GetProfessionInfo(index)
      if name then list[#list + 1] = { n = name, l = level or 0, m = max or 0 } end
    end
  end
  return list
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
