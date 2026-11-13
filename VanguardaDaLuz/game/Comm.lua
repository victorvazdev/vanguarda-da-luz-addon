-- Sincronização com a guilda pelo canal GUILD (AceComm + ChatThrottleLib).
-- O protocolo está em logic/Protocol.lua.
local _, ns = ...

local L = ns.L

local Comm = {}
LibStub("AceComm-3.0"):Embed(Comm)

local queue = {}          -- mensagens adiadas: [kind] = { message, prio }
local response = nil      -- resposta agendada: { number }
local sendingData = nil   -- envio de dados em andamento: { number }
local status = L["Aguardando."]

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
  if not ns.Guild.IsMember() then return end
  if Locked() then
    queue[kind] = { message = message, prio = prio }
    SetStatus(L["Comunicação restrita no momento. O envio será feito quando for permitido."])
    return
  end
  if kind == "data" then
    local number = ns.Store.ExportNumber()
    sendingData = { number = number, message = message, startedAt = GetTime() }
    SetStatus(L["Enviando a exportação para a guilda…"])
    RawSend(message, prio, function(_, sent, total)
      if sent >= total and sendingData and sendingData.message == message then
        sendingData = nil
        SetStatus(L["Exportação enviada para a guilda."])
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
    pending[kind] = nil
  end
  -- Presenças (uma por evento) e outros tipos.
  for kind, item in pairs(pending) do Send(kind, item.message, item.prio) end
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
  if not ns.Guild.IsMember() then return end
  SetStatus(L["Perguntando à guilda pela exportação mais recente…"])
  Send("query", ns.Protocol.Query(ns.Store.ExportNumber()), "NORMAL")
  Send("presenceRequest", ns.Protocol.PresenceRequest(), "NORMAL")
  Send("professionsRequest", ns.Protocol.ProfessionIdsRequest(), "NORMAL")
  Send("membersRequest", ns.Protocol.MembersRequest(), "NORMAL")
  Send("togetherRequest", ns.Protocol.TogetherRequest(), "NORMAL")
end

-- Presença do próprio jogador num evento (só a última de cada evento fica na
-- fila durante a restrição).
function Comm.SendPresence(message, eventId)
  Send("presence:" .. eventId, message, "NORMAL")
end

function Comm.SendPresenceList(message)
  Send("presenceList", message, "BULK")
end

-- Profissões do próprio jogador e níveis conhecidos repassados. `kind`
-- separa os formatos na fila (com e sem IDs).
function Comm.SendProfessions(message, kind)
  Send(kind or "professions", message, "NORMAL")
end

function Comm.SendProfessionsList(message, kind)
  Send(kind or "professionsList", message, "BULK")
end

-- Item level e main do próprio jogador e dados conhecidos repassados.
function Comm.SendMember(message)
  Send("member", message, "NORMAL")
end

function Comm.SendMembersList(message)
  Send("membersList", message, "BULK")
end

-- Tempo com a guilda do próprio jogador e totais conhecidos repassados.
function Comm.SendTogether(message)
  Send("together", message, "NORMAL")
end

function Comm.SendTogetherList(message)
  Send("togetherList", message, "BULK")
end

-- Envia a exportação atual para a guilda (cargos aceitos).
function Comm.Broadcast()
  local export = ns.db.export
  if not export or not export.raw or not ns.Guild.IsPlayerTrusted() then return end
  response = nil
  Send("have", ns.Protocol.Have(export.exportNumber), "NORMAL")
  Send("data", ns.Protocol.Data(export.exportNumber, export.raw), "BULK")
end

-- Envia um alerta de raide na hora, sem fila: um alerta atrasado perde o
-- sentido. Retorna false durante a restrição de comunicação.
function Comm.SendAlert(message)
  if not ns.Guild.IsMember() or Locked() then return false end
  RawSend(message, "ALERT")
  return true
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
    SetStatus(string.format(L["Eventos atualizados por %s."], Ambiguate(sender, "short")))
    if changes > 0 then
      ns.Print(string.format(L["Calendário atualizado por %s: %d alteração(ões)."],
        Ambiguate(sender, "short"), changes))
    end
  end)
end

function Comm.OnCommReceived(_, prefix, text, distribution, sender)
  if prefix ~= ns.Config.COMM_PREFIX or distribution ~= "GUILD" then return end
  if not ns.Guild.IsMember() then return end
  if ns.Guild.IsPlayer(sender) then return end
  local message = ns.Protocol.Parse(text)
  if not message then return end
  if message.kind == "query" then
    OnQuery(message)
  elseif message.kind == "have" then
    CancelResponseIfCovered(message.number)
    if ns.Protocol.IsNewer(message.number, ns.Store.ExportNumber()) then
      SetStatus(string.format(L["Recebendo eventos de %s…"], Ambiguate(sender, "short")))
    end
  elseif message.kind == "data" then
    CancelResponseIfCovered(message.number)
    OnData(message, sender)
  elseif message.kind == "alert" then
    ns.Warning.OnReceived(message, sender)
  elseif message.kind == "presence" then
    ns.Presence.OnPresence(message, sender)
  elseif message.kind == "presenceRequest" then
    ns.Presence.OnRequest()
  elseif message.kind == "presenceList" then
    ns.Presence.OnList(message)
  elseif message.kind == "professions" then
    ns.GuildProfessions.OnOwn(message, sender)
  elseif message.kind == "professionsRequest" then
    ns.GuildProfessions.OnRequest(message.withIds)
  elseif message.kind == "professionsList" then
    ns.GuildProfessions.OnList(message)
  elseif message.kind == "member" then
    ns.GuildMembers.OnOwn(message, sender)
  elseif message.kind == "membersRequest" then
    ns.GuildMembers.OnRequest()
  elseif message.kind == "membersList" then
    ns.GuildMembers.OnList(message)
  elseif message.kind == "together" then
    ns.GuildTogether.OnOwn(message, sender)
  elseif message.kind == "togetherRequest" then
    ns.GuildTogether.OnRequest()
  elseif message.kind == "togetherList" then
    ns.GuildTogether.OnList(message)
  end
end

function Comm.Init()
  Comm:RegisterComm(ns.Config.COMM_PREFIX, "OnCommReceived")
end

ns.Comm = Comm
