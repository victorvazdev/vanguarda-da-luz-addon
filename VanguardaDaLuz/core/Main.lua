-- Inicialização, eventos do jogo e comandos.
local ADDON_NAME, ns = ...

local events = CreateFrame("Frame")
local handlers = {}
local loggedIn = false

local function Register(name, fn)
  -- Eventos que não existem nesta versão do jogo são ignorados.
  if pcall(events.RegisterEvent, events, name) then handlers[name] = fn end
end

local function OnLogin()
  if loggedIn then return end
  loggedIn = true
  ns.Guild.RequestRoster()
  if C_Calendar and C_Calendar.OpenCalendar then C_Calendar.OpenCalendar() end
  -- Pergunta à guilda pela exportação mais recente depois de uma espera
  -- aleatória, para não chegarem muitos pedidos ao mesmo tempo.
  local delay = ns.Protocol.RandomDelay(ns.Config.REQUEST_DELAY_MIN, ns.Config.REQUEST_DELAY_MAX)
  C_Timer.After(delay, function()
    if IsInGuild() then ns.Comm.RequestLatest() end
  end)
  -- Reenvia mensagens adiadas se o aviso de fim da restrição não chegar.
  C_Timer.NewTicker(30, ns.Comm.Flush)
end

local function Start()
  ns.Store.Init()
  ns.Comm.Init()
  ns.MinimapButton.Init()

  Register("PLAYER_ENTERING_WORLD", OnLogin)
  Register("GUILD_ROSTER_UPDATE", ns.Guild.OnRosterUpdate)
  Register("PLAYER_REGEN_DISABLED", ns.Calendar.OnCombatChanged)
  Register("PLAYER_REGEN_ENABLED", ns.Calendar.OnCombatChanged)
  Register("CALENDAR_OPEN_EVENT", ns.Calendar.OnOpenEvent)
  Register("CALENDAR_UPDATE_ERROR", function(_, message) ns.Calendar.OnError(message) end)
  Register("CALENDAR_UPDATE_ERROR_WITH_COUNT", function(_, message) ns.Calendar.OnError(message) end)
  Register("ADDON_RESTRICTION_STATE_CHANGED", ns.Comm.OnRestrictionChanged)
end

events:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... == ADDON_NAME then
      events:UnregisterEvent("ADDON_LOADED")
      Start()
    end
    return
  end
  local fn = handlers[event]
  if fn then fn(event, ...) end
end)
events:RegisterEvent("ADDON_LOADED")

---------------------------------------------------------------------------
-- Comandos
---------------------------------------------------------------------------

local HELP = {
  "/vdl  abre e fecha o calendário",
  "/vdl importar  importa a string do site (Grão Lorde e Lordes)",
  "/vdl pendencias  alterações pendentes no calendário do jogo",
  "/vdl sincronizar  pede à guilda a exportação mais recente",
  "/vdl minimapa  mostra ou esconde o botão no minimapa",
}

SLASH_VANGUARDADALUZ1 = "/vdl"
SlashCmdList.VANGUARDADALUZ = function(input)
  local command = string.lower(ns.Text.Trim(input or ""))
  if command == "" then
    ns.MainFrame.Toggle()
  elseif command == "importar" then
    ns.ImportDialog.Show()
  elseif command == "pendencias" or command == "pendências" then
    ns.PendingFrame.Show()
  elseif command == "sincronizar" then
    ns.Comm.RequestLatest()
  elseif command == "minimapa" then
    ns.MinimapButton.Toggle()
  else
    ns.Print("comandos (versão " .. ns.version .. "):")
    for _, line in ipairs(HELP) do print("  " .. line) end
  end
end
