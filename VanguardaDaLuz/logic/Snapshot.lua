-- Regras do retrato completo: comparar uma exportação com os eventos salvos e
-- aplicá-la. Lógica pura.
--
-- `events` é a tabela salva no addon: [id] = { id, title, startsAt,
-- description, organizer, status, updatedAt }.
local _, ns = ...

local Snapshot = {}

local function Copy(e)
  return {
    id = e.id, title = e.title, startsAt = e.startsAt, description = e.description,
    organizer = e.organizer, status = e.status, updatedAt = e.updatedAt,
  }
end

local function InWindow(export, startsAt)
  return startsAt >= export.windowStart and startsAt < export.windowEnd
end
Snapshot.InWindow = InWindow

local function ById(a, b)
  if a.event.startsAt ~= b.event.startsAt then return a.event.startsAt < b.event.startsAt end
  return a.id < b.id
end

-- Compara a exportação com os eventos salvos. Não altera nada.
-- Retorna { created, updated, cancelled, removed, unchanged, outside }.
--   created:   eventos ativos que o addon ainda não tem.
--   updated:   eventos com updatedAt maior, que continuam (ou voltam a ser) ativos.
--   cancelled: eventos que passaram a cancelados ou chegaram já cancelados
--              (isNew = true quando o addon não os tinha).
--   removed:   eventos salvos com início dentro da janela que não vieram.
--   unchanged: quantidade de eventos sem alteração.
--   outside:   quantidade de eventos salvos fora da janela (não mexidos).
-- Cada item: { id, event, previous }.
function Snapshot.Diff(events, export)
  local diff = { created = {}, updated = {}, cancelled = {}, removed = {}, unchanged = 0, outside = 0 }
  local incoming = {}

  for _, e in ipairs(export.events) do
    incoming[e.id] = true
    local old = events[e.id]
    if not old then
      if e.status == "ativo" then
        diff.created[#diff.created + 1] = { id = e.id, event = e }
      else
        diff.cancelled[#diff.cancelled + 1] = { id = e.id, event = e, isNew = true }
      end
    elseif e.updatedAt > old.updatedAt then
      if e.status == "cancelado" and old.status ~= "cancelado" then
        diff.cancelled[#diff.cancelled + 1] = { id = e.id, event = e, previous = old }
      else
        diff.updated[#diff.updated + 1] = { id = e.id, event = e, previous = old }
      end
    else
      diff.unchanged = diff.unchanged + 1
    end
  end

  for id, old in pairs(events) do
    if not incoming[id] then
      if InWindow(export, old.startsAt) then
        diff.removed[#diff.removed + 1] = { id = id, event = old, previous = old }
      else
        diff.outside = diff.outside + 1
      end
    end
  end

  table.sort(diff.created, ById)
  table.sort(diff.updated, ById)
  table.sort(diff.cancelled, ById)
  table.sort(diff.removed, ById)
  return diff
end

-- Quantidade de alterações de um diff.
function Snapshot.CountChanges(diff)
  return #diff.created + #diff.updated + #diff.cancelled + #diff.removed
end

-- Aplica um diff (de Snapshot.Diff) aos eventos salvos.
function Snapshot.Apply(events, diff)
  for _, list in ipairs({ diff.created, diff.updated, diff.cancelled }) do
    for _, item in ipairs(list) do
      events[item.id] = Copy(item.event)
    end
  end
  for _, item in ipairs(diff.removed) do
    events[item.id] = nil
  end
  return events
end

ns.Snapshot = Snapshot
return Snapshot
