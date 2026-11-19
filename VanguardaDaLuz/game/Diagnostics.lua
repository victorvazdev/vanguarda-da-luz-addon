-- Diagnóstico (/vdl status): versão, personagem e posto, calendário,
-- sincronização, restrição da comunicação, membros online com o addon e mapa.
-- Ajuda quando alguém diz que algo não chegou.
local _, ns = ...

local L = ns.L

local Diagnostics = {}

local function YesNo(value)
  return value and L["sim"] or L["não"]
end

-- Linha do roster do próprio personagem, ou nil.
local function Me()
  local me = ns.Guild.PlayerName()
  for _, entry in ipairs(ns.Flavor.GuildRoster()) do
    if entry.name == me then return entry end
  end
  return nil
end

-- Linhas do diagnóstico, na ordem em que aparecem no chat.
function Diagnostics.Lines()
  local lines = {}
  local function Add(text) lines[#lines + 1] = text end

  local newest = ns.VersionCheck.Newest()
  Add(string.format(L["Versão: %s"], ns.version)
    .. (newest and string.format(L[" (mais nova vista na guilda: %s)"], newest) or ""))

  local me = Me()
  Add(string.format(L["Personagem: %s · posto: %s · Grão Lorde ou Lorde: %s"], ns.Guild.PlayerName() or "?",
    me and me.rank or "?", YesNo(ns.Guild.IsPlayerTrusted())))

  local count = 0
  for _ in pairs(ns.db.events) do count = count + 1 end
  Add(string.format(L["Calendário: %d evento(s) · %s"], count, ns.CalendarPanel.InfoLine()))
  Add(string.format(L["Sincronização: %s"], ns.Comm.Status()))

  local locked = ns.Flavor.InMessagingLockdown()
  Add(string.format(L["Comunicação restrita: %s · mensagens na fila: %d"], YesNo(locked), ns.Comm.QueueSize()))

  local online, withAddon = 0, 0
  for _, entry in ipairs(ns.Flavor.GuildRoster()) do
    if entry.online and not ns.Guild.IsPlayer(entry.name) then
      online = online + 1
      if ns.Comm.HasSeen(entry.name) then withAddon = withAddon + 1 end
    end
  end
  Add(string.format(L["Membros online com o addon (vistos nesta sessão): %d de %d"], withAddon, online))

  Add(string.format(L["Mapa: compartilhando %s · mostrando %s · no minimapa %s · membros no mapa: %d"],
    YesNo(ns.GuildMap.IsSharing()), YesNo(ns.GuildMap.IsShown()), YesNo(ns.GuildMap.IsOnMinimap()),
    #ns.GuildMap.Visible()))
  return lines
end

function Diagnostics.Print()
  ns.Print(L["Diagnóstico:"])
  for _, line in ipairs(Diagnostics.Lines()) do print("  " .. line) end
end

ns.Diagnostics = Diagnostics
