-- Alerta de raide: o Grão Lorde ou um Lorde envia um texto que aparece no
-- centro da tela de quem tem o addon e no chat da guilda. Regras em
-- logic/Alert.lua; o aviso na tela em ui/AlertBanner.lua.
local _, ns = ...

local Alert = ns.Alert
local Warning = {}

local LOCKED = "Comunicação restrita no momento (encontro, Mítica+ ou JxJ). O alerta não foi enviado."

local lastSentAt = nil
local received = Alert.NewState()

-- Envia o alerta. Retorna true ou false e a mensagem de erro.
function Warning.Send(text)
  local config = ns.Config
  if not IsInGuild() then return false, "Você não está em uma guilda." end
  if not ns.Guild.IsPlayerTrusted() then
    return false, "Somente o Grão Lorde e os Lordes podem enviar alertas."
  end
  if ns.Flavor.InMessagingLockdown() then return false, LOCKED end
  local clean, code = Alert.Validate(text, config)
  if not clean then return false, Alert.ERRORS[code] end
  local wait = Alert.WaitTime(lastSentAt, GetTime(), config.ALERT_SEND_INTERVAL)
  if wait > 0 then return false, string.format(Alert.ERRORS.wait, wait) end

  local id = Alert.NewId(GetServerTime())
  if not ns.Comm.SendAlert(ns.Protocol.Alert(id, clean)) then
    return false, LOCKED
  end
  lastSentAt = GetTime()
  ns.Flavor.SendGuildChat(Alert.ChatLine(clean, config))
  -- A própria mensagem de addon não volta para quem enviou: mostra aqui.
  ns.AlertBanner.Show(clean, UnitName("player"))
  return true
end

function Warning.OnReceived(message, sender)
  local text = Alert.Validate(message.text, ns.Config)
  if not text then return end
  ns.Guild.CheckSender(sender, function(trusted)
    if not trusted then return end
    local who = Ambiguate(sender, "none")
    if not Alert.Accept(received, who, message.id, GetTime(), ns.Config.ALERT_RECEIVE_INTERVAL) then return end
    ns.AlertBanner.Show(text, Ambiguate(sender, "short"))
  end)
end

ns.Warning = Warning
