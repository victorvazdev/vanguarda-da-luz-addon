-- Lembrete antes dos eventos em que o jogador confirmou presença. Lógica pura.
--
-- `reminded` = { [eventId] = startsAt }: eventos já lembrados, com o horário
-- que tinham. Se o evento mudar de horário, o lembrete vale de novo.
local _, ns = ...

local Reminders = {}

-- Eventos a lembrar agora: ativos, confirmados (`isConfirmed(id)`), que
-- começam em até `lead` segundos e ainda não foram lembrados nesse horário.
-- Em ordem de início.
function Reminders.Due(events, isConfirmed, reminded, now, lead)
  local due = {}
  for id, event in pairs(events) do
    local left = event.startsAt - now
    if event.status == "ativo" and left > 0 and left <= lead and reminded[id] ~= event.startsAt
      and isConfirmed(id) then
      due[#due + 1] = event
    end
  end
  table.sort(due, function(a, b)
    if a.startsAt ~= b.startsAt then return a.startsAt < b.startsAt end
    return a.id < b.id
  end)
  return due
end

-- Minutos que faltam, arredondados para cima (no mínimo 1).
function Reminders.MinutesLeft(event, now)
  return math.max(1, math.ceil((event.startsAt - now) / 60))
end

-- Esquece os eventos que já começaram ou que o addon não tem mais.
function Reminders.Prune(reminded, events, now)
  for id, startsAt in pairs(reminded) do
    if not events[id] or startsAt <= now then reminded[id] = nil end
  end
end

ns.Reminders = Reminders
return Reminders
