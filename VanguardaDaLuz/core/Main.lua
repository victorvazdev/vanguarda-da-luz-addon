-- Inicialização, eventos do jogo e comandos.
local ADDON_NAME, ns = ...

local events = CreateFrame("Frame")
local handlers = {}
local loggedIn = false
local requestPending = false -- pedido à guilda esperando a guilda carregar

-- As informações da guilda chegam depois do login: o pedido só sai quando o
-- jogador aparece como membro da guilda do addon.
local function RequestWhenMember()
  if requestPending and ns.Guild.IsMember() then
    requestPending = false
    ns.Comm.RequestLatest()
  end
end

local function Register(name, fn)
  -- Eventos que não existem nesta versão do jogo são ignorados.
  if pcall(events.RegisterEvent, events, name) then handlers[name] = fn end
end

local function OnLogin()
  if loggedIn then return end
  loggedIn = true
  ns.Guild.RequestRoster()
  -- Pergunta à guilda pela exportação mais recente depois de uma espera
  -- aleatória, para não chegarem muitos pedidos ao mesmo tempo.
  local delay = ns.Protocol.RandomDelay(ns.Config.REQUEST_DELAY_MIN, ns.Config.REQUEST_DELAY_MAX)
  C_Timer.After(delay, function()
    requestPending = true
    RequestWhenMember()
  end)
  -- Reenvia mensagens adiadas se o aviso de fim da restrição não chegar.
  C_Timer.NewTicker(30, ns.Comm.Flush)
end

local function Start()
  ns.Store.Init()
  ns.Comm.Init()
  ns.MinimapButton.Init()

  Register("PLAYER_ENTERING_WORLD", OnLogin)
  Register("GUILD_ROSTER_UPDATE", function(...)
    ns.Guild.OnRosterUpdate(...)
    RequestWhenMember()
  end)
  Register("PLAYER_GUILD_UPDATE", RequestWhenMember)
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
  "/vdl sincronizar  pede à guilda a exportação mais recente",
  "/vdl alerta [texto]  envia um alerta de raide à guilda (Grão Lorde e Lordes)",
  "/vdl minimapa  mostra ou esconde o botão no minimapa",
}

SLASH_VANGUARDADALUZ1 = "/vdl"
SlashCmdList.VANGUARDADALUZ = function(input)
  input = ns.Text.Trim(input or "")
  local word, rest = string.match(input, "^(%S+)%s*(.-)$")
  local command = string.lower(word or "")
  -- Fora da guilda, o addon só mostra o convite (e o botão do minimapa).
  if command ~= "minimapa" and not ns.Guild.IsMember() then
    ns.MainFrame.Hide()
    ns.WelcomeFrame.Toggle()
    return
  end
  if command == "" then
    ns.MainFrame.Toggle()
  elseif command == "importar" then
    ns.ImportDialog.Show()
  elseif command == "sincronizar" then
    ns.Comm.RequestLatest()
  elseif command == "alerta" then
    if rest == "" then
      ns.AlertDialog.Show()
    else
      local ok, err = ns.Warning.Send(rest)
      if not ok then ns.Print(err) end
    end
  elseif command == "minimapa" then
    ns.MinimapButton.Toggle()
  else
    ns.Print("comandos (versão " .. ns.version .. "):")
    for _, line in ipairs(HELP) do print("  " .. line) end
  end
end
