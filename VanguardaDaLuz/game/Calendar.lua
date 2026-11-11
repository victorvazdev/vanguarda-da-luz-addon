-- Automação do calendário do jogo, uma alteração por clique.
--
-- C_Calendar.AddEvent e C_Calendar.UpdateEvent exigem hardware event, por isso
-- cada alteração é aplicada pelo botão "Aplicar próximo". Antes do clique, o
-- addon localiza o evento no calendário do jogo (abrir eventos e trocar de mês
-- não exige clique); no clique, só grava.
local _, ns = ...

local Calendar = {}

local LOCATE_TIMEOUT = 4  -- segundos esperando o mês carregar
local SAVE_TIMEOUT = 6    -- segundos esperando a confirmação do servidor

-- Estado da operação atual:
--   item    = { id, link, event } (de GamePlan.Next)
--   phase   = "idle" | "locating" | "opening" | "ready" | "saving" | "blocked"
--   message = texto para a janela de pendências
--   where   = { offset, day, index } do evento no calendário do jogo
local current = { phase = "idle" }
local token = 0 -- invalida esperas antigas
local appliedThisSession = 0

local OP_LABELS = { create = "Criar", update = "Editar", cancel = "Cancelar", remove = "Remover" }
Calendar.OP_LABELS = OP_LABELS

local function SetPhase(phase, message)
  current.phase, current.message = phase, message
  ns.Fire("CALENDAR_STATUS")
end

function Calendar.Status()
  return current.phase, current.message, current.item, appliedThisSession
end

local function ServerOffset()
  return ns.Time.ServerOffset(C_DateAndTime.GetCurrentCalendarTime(), GetServerTime())
end
Calendar.ServerOffset = ServerOffset

-- Data e hora do evento no horário do servidor.
local function GameTime(event)
  local f = ns.Time.Fields(event.startsAt, ServerOffset())
  return { year = f.year, month = f.month, day = f.day, hour = f.hour, minute = f.minute }
end

-- Mostra o mês no calendário do jogo e devolve o deslocamento para as funções
-- C_Calendar que pedem offsetMonths.
local function ShowMonth(t)
  C_Calendar.SetAbsMonth(t.month, t.year)
  local info = C_Calendar.GetMonthInfo(0)
  return (t.year - info.year) * 12 + (t.month - info.month)
end

-- Procura o evento num dia. `match(dayEvent)` decide.
local function FindOnDay(t, match)
  local offset = ShowMonth(t)
  for index = 1, C_Calendar.GetNumDayEvents(offset, t.day) do
    local e = C_Calendar.GetDayEvent(offset, t.day, index)
    if e and match(e) then return { offset = offset, day = t.day, index = index, event = e } end
  end
  return nil
end

local function SameTime(e, t)
  return e.startTime and e.startTime.hour == t.hour and e.startTime.minute == t.minute
end

local function IsGuildEvent(e)
  return e.calendarType == "GUILD_ANNOUNCEMENT" or e.calendarType == "GUILD_EVENT"
end

-- Localiza um evento criado pelo addon: pelo eventID ou pelo título e horário.
local function Locate(link, t, title)
  if not t then return nil end
  return FindOnDay(t, function(e)
    if not IsGuildEvent(e) then return false end
    if link and link.gameEventId and link.gameEventId ~= "?" then
      return tostring(e.eventID) == link.gameEventId
    end
    return e.title == title and SameTime(e, t)
  end)
end

local function Blocked()
  if InCombatLockdown() then return "Em combate. Aguarde o fim do combate." end
  local ok, reason = ns.Guild.CanEditCalendar()
  if not ok then return reason end
  if CalendarFrame and CalendarFrame:IsShown() then
    return "Feche o calendário do jogo para o addon aplicar as alterações."
  end
  return nil
end

local function Finish(id, gameEventId, title, t)
  ns.GamePlan.MarkDone(ns.db.game, id, gameEventId, title, t)
  appliedThisSession = appliedThisSession + 1
  ns.Fire("PENDING_UPDATED")
end

local function Fail(id, message)
  ns.GamePlan.MarkFailed(ns.db.game, id, message)
  ns.Fire("PENDING_UPDATED")
end

-- Prepara a próxima operação: localiza e abre o evento, sem gravar nada.
function Calendar.Prepare()
  token = token + 1
  local myToken = token
  current.item, current.where = nil, nil

  local item = ns.GamePlan.Next(ns.db.game, ns.db.events)
  if not item then
    SetPhase("idle", "Nenhuma alteração pendente.")
    return
  end
  current.item = item

  local blocked = Blocked()
  if blocked then
    SetPhase("blocked", blocked)
    return
  end

  SetPhase("locating", "Localizando o evento no calendário do jogo…")
  C_Calendar.OpenCalendar()
  local link, op = item.link, item.link.op

  -- Espera o mês carregar (CALENDAR_UPDATE_EVENT_LIST ou tempo limite).
  local where
  if op == "create" then
    where = { time = GameTime(item.event), title = ns.GamePlan.GameTitle(item.event, ns.Config) }
    ShowMonth(where.time)
  else
    where = { time = link.gameTime, title = link.gameTitle }
    if where.time then ShowMonth(where.time) end
  end

  C_Timer.After(LOCATE_TIMEOUT, function()
    if myToken ~= token then return end
    local found = Locate(op ~= "create" and link or nil, where.time, where.title)

    if op == "create" then
      if found then
        -- Já existe (por exemplo, criado por outro administrador): só ligar.
        Finish(item.id, tostring(found.event.eventID), where.title, where.time)
        Calendar.Prepare()
        return
      end
      current.where = where
      SetPhase("ready", "Pronto para criar.")
      return
    end

    if not found then
      -- Removido à mão no jogo.
      link.gameEventId = nil
      if op == "remove" or op == "cancel" then
        Finish(item.id)
      else
        link.op, link.state = "create", "pending"
        ns.Fire("PENDING_UPDATED")
      end
      Calendar.Prepare()
      return
    end

    current.where = found
    if op == "remove" then
      C_Calendar.ContextMenuSelectEvent(found.offset, found.day, found.index)
      SetPhase("ready", "Pronto para remover.")
    else
      SetPhase("opening", "Abrindo o evento…")
      C_Calendar.OpenEvent(found.offset, found.day, found.index)
      C_Timer.After(LOCATE_TIMEOUT, function()
        if myToken == token and current.phase == "opening" then
          SetPhase("blocked", "O evento não abriu. Clique em \"Preparar de novo\".")
        end
      end)
    end
  end)
end

-- CALENDAR_OPEN_EVENT: o evento aberto está pronto para edição.
function Calendar.OnOpenEvent()
  if current.phase ~= "opening" then return end
  if C_Calendar.EventCanEdit and not C_Calendar.EventCanEdit() then
    Fail(current.item.id, "Sem permissão para editar este evento.")
    Calendar.Prepare()
    return
  end
  SetPhase("ready", current.item.link.op == "cancel" and "Pronto para cancelar." or "Pronto para editar.")
end

local function SetFields(event, t)
  C_Calendar.EventSetTitle(ns.GamePlan.GameTitle(event, ns.Config))
  C_Calendar.EventSetDescription(ns.GamePlan.GameDescription(event, ns.Config))
  C_Calendar.EventSetType(ns.Flavor.EventTypeOther())
  C_Calendar.EventSetDate(t.month, t.day, t.year)
  C_Calendar.EventSetTime(t.hour, t.minute)
end

-- Espera a confirmação do servidor e localiza o evento gravado.
local function AwaitSave(item, title, t)
  local myToken = token
  current.saveFailed = nil
  C_Timer.After(SAVE_TIMEOUT, function()
    if myToken ~= token then return end
    if current.saveFailed then
      Fail(item.id, current.saveFailed)
    elseif item.link.op == "remove" then
      Finish(item.id)
    else
      local found = Locate(nil, t, title)
      local id = found and tostring(found.event.eventID) or item.link.gameEventId or "?"
      Finish(item.id, id, title, t)
    end
    Calendar.Prepare()
  end)
end

-- Aplica a operação preparada. Chamar só a partir de um clique.
function Calendar.ApplyNext()
  if current.phase ~= "ready" or not current.item then return end
  local blocked = Blocked()
  if blocked then
    SetPhase("blocked", blocked)
    return
  end

  local item = current.item
  local op = item.link.op
  local title = item.event and ns.GamePlan.GameTitle(item.event, ns.Config)
  local t = item.event and GameTime(item.event)

  local ok, err = pcall(function()
    if op == "create" then
      ns.Flavor.CreateGuildEventCandidate()
      SetFields(item.event, t)
      C_Calendar.AddEvent()
    elseif op == "update" or op == "cancel" then
      SetFields(item.event, t)
      C_Calendar.UpdateEvent()
    elseif op == "remove" then
      C_Calendar.ContextMenuEventRemove()
    end
  end)

  if not ok then
    Fail(item.id, tostring(err))
    Calendar.Prepare()
    return
  end
  SetPhase("saving", "Gravando no calendário do jogo…")
  AwaitSave(item, title, t)
end

-- CALENDAR_UPDATE_ERROR: o servidor recusou a gravação.
function Calendar.OnError(message)
  if current.phase == "saving" then
    current.saveFailed = message or "O calendário do jogo recusou a alteração."
  end
end

function Calendar.Retry(id)
  ns.GamePlan.Retry(ns.db.game, id)
  ns.Fire("PENDING_UPDATED")
  Calendar.Prepare()
end

-- Recalcula o bloqueio quando o combate começa ou termina.
function Calendar.OnCombatChanged()
  if current.phase == "ready" or current.phase == "blocked" then Calendar.Prepare() end
end

-- Registra as operações de uma importação feita pelo próprio jogador.
function Calendar.Plan(diff)
  ns.GamePlan.FromDiff(ns.db.game, diff)
  ns.Fire("PENDING_UPDATED")
end

function Calendar.PendingList()
  return ns.GamePlan.Pending(ns.db.game, ns.db.events)
end

ns.Calendar = Calendar
