-- Eventos criados, editados, cancelados e excluídos no jogo pelo Grão Lorde e pelos
-- Lordes: grava, envia para a guilda e recebe dos outros. Regras em
-- logic/GameEvents.lua; as alterações viajam numa string VDLB1 só com eventos
-- (logic/BackupCodec.lua) e chegam ao site no backup (game/Backup.lua).
local _, ns = ...

local L = ns.L

local GameEvents = ns.GameEvents
local GuildEvents = {}

local response = nil -- resposta agendada a um pedido de eventos do jogo

-- Erros de validação (traduzidos onde aparecem).
GuildEvents.ERRORS = {
  title = "Informe um título com até 80 caracteres.",
  organizer = "Informe o organizador com até 40 caracteres.",
  description = "A descrição pode ter até 2000 caracteres.",
  past = "Escolha uma data e hora que ainda não passaram.",
  max = "As vagas devem ser um número de 1 a 500.",
  date = "Data inválida. Use dd/mm/aaaa.",
  clock = "Hora inválida. Use hh:mm.",
}

local function Events()
  return ns.db.events
end

local function Deleted()
  return ns.db.deleted
end

-- Presenças de um evento excluído não servem mais.
local function DropAttendance(id)
  if ns.db.attendance and ns.db.attendance[id] then
    ns.db.attendance[id] = nil
    ns.Fire("ATTENDANCE_UPDATED")
  end
end

local function Changed()
  ns.Fire("DATA_UPDATED")
end

-- String VDLB1 só com os eventos.
local function Encode(list)
  return ns.BackupCodec.Encode({
    game = ns.Flavor.exportGame, generatedAt = GetServerTime(), exportNumber = ns.Store.ExportNumber() or 0,
    generatedBy = ns.Guild.PlayerName() or "", events = list,
  })
end

-- O jogador pode criar e alterar eventos?
function GuildEvents.CanEdit()
  return ns.Guild.IsMember() and ns.Guild.IsPlayerTrusted()
end

function GuildEvents.IsChangeable(event)
  return GameEvents.IsChangeable(event, GetServerTime())
end

function GuildEvents.IsDeletable(event)
  return GameEvents.IsDeletable(event)
end

-- Mensagem do erro de validação.
function GuildEvents.ErrorText(code)
  local text = GuildEvents.ERRORS[code]
  return text and L[text] or code
end

-- Horário (Brasília) a partir dos textos do formulário. Retorna o timestamp ou
-- nil e o código do erro.
function GuildEvents.StartsAt(dateText, clockText)
  local y, m, d = GameEvents.ParseDate(dateText)
  if not y then return nil, "date" end
  local h, mi = GameEvents.ParseClock(clockText)
  if not h then return nil, "clock" end
  return ns.Time.FromFields(y, m, d, h, mi, ns.Config.BRASILIA_OFFSET)
end

local function Announce(event)
  ns.Comm.SendGameEvent(ns.Protocol.GameEvents(Encode({ event })), event.id)
end

-- Cria (`id` nil) ou edita um evento. `input` = { title, description,
-- organizer, startsAt, max, guests }. Retorna o evento ou nil e o erro.
function GuildEvents.Save(id, input)
  if not GuildEvents.CanEdit() then
    return nil, L["Somente o Grão Lorde e os Lordes podem criar e alterar eventos."]
  end
  local now = GetServerTime()
  local old = id and Events()[id]
  if id and not GameEvents.IsChangeable(old, now) then
    return nil, L["Este evento não pode mais ser alterado (cancelado ou já começou)."]
  end
  local withLimits = not old or old.origin == "jogo"
  local fields, code = GameEvents.Validate(input, now, withLimits)
  if not fields then return nil, GuildEvents.ErrorText(code) end
  local meta = { now = now, by = ns.Guild.PlayerName() or UnitName("player") }
  local event
  if old then
    event = GameEvents.Edit(Events(), id, fields, meta)
  else
    repeat meta.id = GameEvents.NewId() until not Events()[meta.id]
    event = GameEvents.Create(Events(), fields, meta)
  end
  Announce(event)
  Changed()
  return event
end

-- Cancela um evento. Retorna true ou false e o erro.
function GuildEvents.Cancel(id)
  if not GuildEvents.CanEdit() then
    return false, L["Somente o Grão Lorde e os Lordes podem criar e alterar eventos."]
  end
  local by = ns.Guild.PlayerName() or UnitName("player")
  local event = GameEvents.Cancel(Events(), id, { now = GetServerTime(), by = by })
  if not event then return false, L["Este evento não pode mais ser alterado (cancelado ou já começou)."] end
  Announce(event)
  Changed()
  return true
end

-- Exclui um evento cancelado. Retorna true ou false e o erro.
function GuildEvents.Delete(id)
  if not GuildEvents.CanEdit() then
    return false, L["Somente o Grão Lorde e os Lordes podem criar e alterar eventos."]
  end
  local by = ns.Guild.PlayerName() or UnitName("player")
  local record = GameEvents.Delete(Events(), Deleted(), id, { now = GetServerTime(), by = by })
  if not record then return false, L["Só eventos cancelados podem ser excluídos."] end
  DropAttendance(id)
  Announce(record)
  Changed()
  return true
end

-- Aplica alterações recebidas (de outro membro ou de um backup). Retorna
-- quantos eventos mudaram.
function GuildEvents.Merge(list)
  local changed = 0
  for _, e in ipairs(list) do
    if GameEvents.Merge(Events(), e, ns.db.export, Deleted()) then
      changed = changed + 1
      if e.status == "excluido" then DropAttendance(e.id) end
    end
  end
  if changed > 0 then Changed() end
  return changed
end

-- Alterações enviadas por outro membro: só valem de quem tem cargo aceito.
function GuildEvents.OnReceived(message, sender)
  if message.list then response = nil end
  local data = ns.BackupCodec.Decode(message.encoded)
  if not data or data.game ~= ns.Flavor.exportGame or #data.events == 0 then return end
  ns.Guild.CheckSender(sender, function(trusted)
    if not trusted then return end
    local changed = GuildEvents.Merge(data.events)
    if changed > 0 and not message.list then
      ns.Print(string.format(L["Calendário alterado no jogo por %s."], Ambiguate(sender, "short")))
    end
  end)
end

-- Alguém pediu os eventos do jogo que aguardam o site: o Grão Lorde ou um
-- Lorde responde depois de uma espera aleatória, se ninguém responder antes.
function GuildEvents.OnRequest()
  if response or not ns.Guild.IsPlayerTrusted() or #GameEvents.Pending(Events(), Deleted()) == 0 then return end
  response = true
  local delay = ns.Protocol.RandomDelay(ns.Config.RESPONSE_DELAY_MIN, ns.Config.RESPONSE_DELAY_MAX)
  C_Timer.After(delay, function()
    local pending = GameEvents.Pending(Events(), Deleted())
    if response and #pending > 0 then
      ns.Comm.SendGameEventsList(ns.Protocol.GameEventsList(Encode(pending)))
    end
    response = nil
  end)
end

function GuildEvents.Pending()
  return GameEvents.Pending(Events(), Deleted())
end

ns.GuildEvents = GuildEvents
