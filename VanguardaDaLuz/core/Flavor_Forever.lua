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

-- Cria o rascunho de um evento de guilda do tipo anúncio.
function Flavor.CreateGuildEventCandidate()
  C_Calendar.CloseEvent()
  C_Calendar.CreateGuildAnnouncementEvent()
end

-- Tipo de evento (ícone). "Outro" serve para todos os eventos do site.
function Flavor.EventTypeOther()
  if Enum and Enum.CalendarEventType and Enum.CalendarEventType.Other then
    return Enum.CalendarEventType.Other
  end
  return 4
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

-- Índices de C_GuildInfo.GuildControlGetRankFlags. O 14 também se chama
-- "Criar evento da guilda", mas a interface da Blizzard o trata como obsoleto.
Flavor.RANK_FLAG_CREATE_EVENT = 17
Flavor.RANK_FLAG_REMOVE_EVENT = 20

ns.Flavor = Flavor
return Flavor
