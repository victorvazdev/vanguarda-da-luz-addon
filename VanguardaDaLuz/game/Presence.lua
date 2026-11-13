-- Lista de presença no jogo: confirmar e cancelar, sincronizar com a guilda e
-- gerar a string VDLP1 para o site. Regras em logic/Attendance.lua e formato
-- em logic/PresenceCodec.lua.
local _, ns = ...

local L = ns.L

local Attendance = ns.Attendance
local Presence = {}

local response = nil -- resposta agendada a um pedido de presenças

local function Store()
  return ns.db.attendance
end

local function Changed()
  ns.Fire("ATTENDANCE_UPDATED")
end

function Presence.Init()
  ns.db.attendance = ns.db.attendance or {}
  Attendance.Prune(Store(), ns.db.events)
  ns.On("DATA_UPDATED", function()
    Attendance.Prune(Store(), ns.db.events)
    Changed()
  end)
end

-- Personagem do jogador, no formato do roster ("Nome Sobrenome").
function Presence.Me()
  return ns.Guild.PlayerName()
end

function Presence.Status(eventId)
  return Attendance.Status(Store(), eventId, Presence.Me())
end

function Presence.Confirmed(eventId)
  return Attendance.Confirmed(Store(), eventId)
end

function Presence.IsOpen(event)
  return Attendance.IsOpen(event, GetServerTime())
end

-- Confirma ou cancela a presença do jogador. Retorna true ou false e o erro.
function Presence.Toggle(eventId)
  local event = ns.db.events[eventId]
  if not Presence.IsOpen(event) then
    return false, L["Só é possível responder a eventos ativos que ainda não começaram."]
  end
  local status = Presence.Status(eventId) == 1 and 0 or 1
  local at = GetServerTime()
  -- Duas respostas no mesmo segundo: a segunda precisa ser a mais recente.
  local current = Store()[eventId] and Store()[eventId][Presence.Me()]
  if current and current.t >= at then at = current.t + 1 end
  Attendance.Set(Store(), eventId, Presence.Me(), status, at)
  ns.Comm.SendPresence(ns.Protocol.Presence(eventId, status, at), eventId)
  Changed()
  return true
end

-- Presença anunciada pelo próprio remetente.
function Presence.OnPresence(message, sender)
  if Attendance.Set(Store(), message.eventId, sender, message.status, message.at) then Changed() end
end

local function EncodeAll(filter)
  return ns.PresenceCodec.Encode({
    game = ns.Flavor.exportGame,
    generatedAt = GetServerTime(),
    exportNumber = ns.Store.ExportNumber() or 0,
    store = Attendance.Select(Store(), filter),
  })
end

-- Alguém pediu as presenças: responde depois de uma espera aleatória, se
-- ninguém responder antes.
function Presence.OnRequest()
  if response or not next(Store()) then return end
  response = true
  local delay = ns.Protocol.RandomDelay(ns.Config.RESPONSE_DELAY_MIN, ns.Config.RESPONSE_DELAY_MAX)
  C_Timer.After(delay, function()
    if response then
      ns.Comm.SendPresenceList(ns.Protocol.PresenceList(EncodeAll(function() return true end)))
    end
    response = nil
  end)
end

-- Presenças repassadas por outro membro.
function Presence.OnList(message)
  response = nil
  local data = ns.PresenceCodec.Decode(message.encoded)
  if not data then return end
  if Attendance.Merge(Store(), data.store) > 0 then Changed() end
end

-- String VDLP1 para o site: eventos do site que ainda não começaram.
function Presence.ExportString()
  local now = GetServerTime()
  return EncodeAll(function(eventId)
    local event = ns.db.events[eventId]
    return event ~= nil and event.startsAt > now
  end)
end

ns.Presence = Presence
