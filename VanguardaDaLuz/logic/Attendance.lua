-- Lista de presença do jogo. Lógica pura.
--
-- `store` = { [eventId] = { [personagem] = { s = 1|0, t = horário } } }
--   personagem: nome completo como no roster ("Nome Sobrenome")
--   s: 1 confirmado, 0 cancelado; t: horário da resposta (segundos Unix)
--
-- Em cada personagem e evento vale o registro mais recente, então receber a
-- mesma informação de várias fontes, em qualquer ordem, dá o mesmo resultado.
local _, ns = ...

local Attendance = {}

-- O evento aceita respostas? Só eventos ativos que ainda não começaram.
function Attendance.IsOpen(event, now)
  return event ~= nil and event.status == "ativo" and event.startsAt > now
end

-- Registra uma resposta. Retorna true se mudou o estado.
function Attendance.Set(store, eventId, who, status, at)
  if type(eventId) ~= "string" or eventId == "" or type(who) ~= "string" or who == "" then return false end
  if status ~= 0 and status ~= 1 then return false end
  if type(at) ~= "number" then return false end
  local list = store[eventId]
  local current = list and list[who]
  if current and current.t >= at then return false end
  list = list or {}
  list[who] = { s = status, t = at }
  store[eventId] = list
  return true
end

-- Situação de um personagem: 1, 0 ou nil.
function Attendance.Status(store, eventId, who)
  local record = store[eventId] and store[eventId][who]
  return record and record.s or nil
end

-- Nomes confirmados no evento, em ordem alfabética.
function Attendance.Confirmed(store, eventId)
  local names = {}
  for who, record in pairs(store[eventId] or {}) do
    if record.s == 1 then names[#names + 1] = who end
  end
  table.sort(names)
  return names
end

-- Apaga as respostas de eventos que o addon não tem mais.
function Attendance.Prune(store, events)
  for eventId in pairs(store) do
    if not events[eventId] then store[eventId] = nil end
  end
end

-- Mescla outro `store` (recebido de outro membro). Retorna quantos registros mudaram.
function Attendance.Merge(store, other)
  local changed = 0
  for eventId, list in pairs(other) do
    for who, record in pairs(list) do
      if Attendance.Set(store, eventId, who, record.s, record.t) then changed = changed + 1 end
    end
  end
  return changed
end

-- Copia só os eventos aceitos por `filter(eventId)`.
function Attendance.Select(store, filter)
  local result = {}
  for eventId, list in pairs(store) do
    if filter(eventId) then
      local copy = {}
      for who, record in pairs(list) do copy[who] = { s = record.s, t = record.t } end
      if next(copy) then result[eventId] = copy end
    end
  end
  return result
end

ns.Attendance = Attendance
return Attendance
