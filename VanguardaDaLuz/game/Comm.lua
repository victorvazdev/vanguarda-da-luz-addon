-- Sincronização com a guilda pelo canal GUILD (AceComm + ChatThrottleLib).
-- O protocolo está em logic/Protocol.lua.
local _, ns = ...

local Comm = {}
LibStub("AceComm-3.0"):Embed(Comm)

local queue = {}          -- mensagens adiadas: [kind] = { message, prio }
local response = nil      -- resposta agendada: { number }
local sendingData = nil   -- envio de dados em andamento: { number }
local status = "Aguardando."

local function SetStatus(text)
  status = text
  ns.Fire("SYNC_STATUS")
end

function Comm.Status()
  return status
end

local function Locked()
  return ns.Flavor.InMessagingLockdown()
end

local function RawSend(message, prio, callback)
  Comm:SendCommMessage(ns.Config.COMM_PREFIX, message, "GUILD", nil, prio, callback)
end

-- Envia agora ou guarda até a comunicação ser liberada. Só a última mensagem
-- de cada tipo fica na fila.
local function Send(kind, message, prio)
  if not IsInGuild() then return end
  if Locked() then
    queue[kind] = { message = message, prio = prio }
    SetStatus("Comunicação restrita no momento. O envio será feito quando for permitido.")
    return
  end
  if kind == "data" then
    local number = ns.Store.ExportNumber()
    sendingData = { number = number, message = message, startedAt = GetTime() }
    SetStatus("Enviando a exportação para a guilda…")
    RawSend(message, prio, function(_, sent, total)
      if sent >= total and sendingData and sendingData.message == message then
        sendingData = nil
        SetStatus("Exportação enviada para a guilda.")
      end
    end)
  else
    RawSend(message, prio)
  end
end

-- Envia o que ficou na fila. Chamado quando a restrição termina.
function Comm.Flush()
  if Locked() or not next(queue) then return end
  local pending = queue
  queue = {}
  for _, kind in ipairs({ "query", "have", "data" }) do
    if pending[kind] then Send(kind, pending[kind].message, pending[kind].prio) end
  end
end

function Comm.OnRestrictionChanged()
  if Locked() then
    -- A restrição começou no meio de um envio: as partes perdidas invalidam a
    -- mensagem, que é enviada de novo quando a restrição terminar.
    if sendingData then
      queue.data = { message = sendingData.message, prio = "BULK" }
      sendingData = nil
    end
  else
    Comm.Flush()
  end
end

-- Pergunta à guilda se há exportação mais nova.
function Comm.RequestLatest()
  if not IsInGuild() then return end
  SetStatus("Perguntando à guilda pela exportação mais recente…")
  Send("query", ns.Protocol.Query(ns.Store.ExportNumber()), "NORMAL")
end

-- Envia a exportação atual para a guilda (oficiais).
function Comm.Broadcast()
  local export = ns.db.export
  if not export or not export.raw or not ns.Guild.IsPlayerTrusted() then return end
  response = nil
  Send("have", ns.Protocol.Have(export.exportNumber), "NORMAL")
  Send("data", ns.Protocol.Data(export.exportNumber, export.raw), "BULK")
end

local function CancelResponseIfCovered(number)
  if response and ns.Protocol.ShouldCancel(response.number, number) then
    response = nil
  end
end

local function OnQuery(message)
  local mine = ns.Store.ExportNumber()
  if not ns.Protocol.ShouldRespond(mine, message.number, ns.Guild.IsPlayerTrusted()) then return end
  -- Um envio sem confirmação há mais de 5 minutos é considerado encerrado.
  if sendingData and GetTime() - sendingData.startedAt > 300 then sendingData = nil end
  if response or sendingData then return end
  response = { number = mine }
  local delay = ns.Protocol.RandomDelay(ns.Config.RESPONSE_DELAY_MIN, ns.Config.RESPONSE_DELAY_MAX)
  C_Timer.After(delay, function()
    if response and response.number == ns.Store.ExportNumber() then Comm.Broadcast() end
    response = nil
  end)
end

local function OnData(message, sender)
  if not ns.Protocol.IsNewer(message.number, ns.Store.ExportNumber()) then return end
  ns.Guild.CheckSender(sender, function(trusted)
    if not trusted then return end
    local prepared = ns.Store.Prepare(message.raw)
    if not prepared or prepared.export.exportNumber ~= message.number then return end
    local diff = ns.Store.Commit(prepared, "guild", sender)
    local changes = ns.Snapshot.CountChanges(diff)
    SetStatus("Eventos atualizados por " .. Ambiguate(sender, "short") .. ".")
    if changes > 0 then
      ns.Print(string.format("Calendário atualizado por %s: %d alteração(ões).",
        Ambiguate(sender, "short"), changes))
    end
  end)
end

function Comm.OnCommReceived(_, prefix, text, distribution, sender)
  if prefix ~= ns.Config.COMM_PREFIX or distribution ~= "GUILD" then return end
  if ns.Trust.SameName(sender, UnitName("player")) then return end
  local message = ns.Protocol.Parse(text)
  if not message then return end
  if message.kind == "query" then
    OnQuery(message)
  elseif message.kind == "have" then
    CancelResponseIfCovered(message.number)
    if ns.Protocol.IsNewer(message.number, ns.Store.ExportNumber()) then
      SetStatus("Recebendo eventos de " .. Ambiguate(sender, "short") .. "…")
    end
  elseif message.kind == "data" then
    CancelResponseIfCovered(message.number)
    OnData(message, sender)
  end
end

function Comm.Init()
  Comm:RegisterComm(ns.Config.COMM_PREFIX, "OnCommReceived")
end

ns.Comm = Comm
