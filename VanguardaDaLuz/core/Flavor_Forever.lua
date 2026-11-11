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

-- Índices de C_GuildInfo.GuildControlGetRankFlags.
Flavor.RANK_FLAG_CREATE_EVENT = 14
Flavor.RANK_FLAG_REMOVE_EVENT = 20

ns.Flavor = Flavor
return Flavor
