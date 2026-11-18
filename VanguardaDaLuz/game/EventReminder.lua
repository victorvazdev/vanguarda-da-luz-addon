-- Lembrete antes dos eventos: `Config.REMINDER_LEAD` segundos antes de um
-- evento em que o jogador confirmou presença, mostra um aviso no centro da
-- tela (o quadro do aviso de raide, com o som) e uma linha no chat. Cada
-- evento é lembrado uma vez por horário (db.reminded), mesmo depois de /reload.
-- Regras em logic/Reminders.lua.
local _, ns = ...

local L = ns.L

local Reminders = ns.Reminders
local EventReminder = {}

local function Reminded()
  ns.db.reminded = ns.db.reminded or {}
  return ns.db.reminded
end

local function Confirmed(id)
  return ns.Presence.Status(id) == 1
end

-- Texto do lembrete: "Lembrete: Raide começa em 15 min (20:00 de Brasília)."
function EventReminder.Text(event, now)
  local clock = ns.Time.FormatClock(event.startsAt, ns.Config.BRASILIA_OFFSET)
  return string.format(L["Lembrete: %s começa em %d min (%s de Brasília)."], event.title,
    Reminders.MinutesLeft(event, now), clock)
end

-- Confere os eventos e mostra os lembretes que chegaram na hora.
function EventReminder.Check()
  if not (ns.db and ns.Guild.IsMember() and ns.Guild.PlayerName()) then return end
  local now = GetServerTime()
  local reminded = Reminded()
  Reminders.Prune(reminded, ns.db.events, now)
  for _, event in ipairs(Reminders.Due(ns.db.events, Confirmed, reminded, now, ns.Config.REMINDER_LEAD)) do
    reminded[event.id] = event.startsAt
    local text = EventReminder.Text(event, now)
    local gold = ns.Theme.colors.gold
    ns.Flavor.ShowRaidWarning(ns.Text.Escape(text), { r = gold[1], g = gold[2], b = gold[3] })
    ns.Flavor.PlayRaidWarningSound()
    ns.Print(ns.Text.Escape(text))
  end
end

function EventReminder.Start()
  if EventReminder.ticker then return end
  EventReminder.ticker = C_Timer.NewTicker(ns.Config.REMINDER_CHECK, EventReminder.Check)
  EventReminder.Check()
end

ns.EventReminder = EventReminder
