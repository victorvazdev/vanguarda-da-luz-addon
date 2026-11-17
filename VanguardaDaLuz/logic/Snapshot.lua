-- Regras do retrato completo: comparar uma exportação com os eventos salvos e
-- aplicá-la. Lógica pura.
--
-- `events` é a tabela salva no addon: [id] = { id, title, startsAt,
-- description, organizer, status, updatedAt }. Eventos criados ou alterados
-- no jogo têm também `pending` e outros campos (logic/GameEvents.lua): eles
-- não são removidos por uma exportação que não os traz, e uma versão do site
-- mais antiga que a alteração do jogo não a desfaz. A exceção é o evento do
-- site alterado no jogo que some de uma exportação gerada depois da alteração:
-- o site o excluiu, e a exclusão vale (DeletedOnSite).
--
-- `deleted` são os registros de exclusões feitas no jogo (logic/GameEvents.lua):
-- a exportação não traz de volta um evento excluído no jogo depois da versão
-- dela, e o registro sai quando uma exportação gerada depois da exclusão já não
-- traz o evento (o site também o excluiu) ou quando o evento já passou.
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

-- Evento alterado no jogo antes de a exportação ser gerada e com início dentro
-- da janela: se ela não o traz, o site não o tem mais. `export` precisa de
-- exportNumber, windowStart e windowEnd.
function Snapshot.GoneFrom(export, e)
  return export.exportNumber ~= nil and export.exportNumber > e.updatedAt and InWindow(export, e.startsAt)
end

-- Evento do site (alterado no jogo) que a exportação não traz e que foi
-- alterado antes de ela ser gerada: o site o excluiu depois da alteração.
function Snapshot.DeletedOnSite(export, e)
  return e.origin == "site" and Snapshot.GoneFrom(export, e)
end

local function ById(a, b)
  if a.event.startsAt ~= b.event.startsAt then return a.event.startsAt < b.event.startsAt end
  return a.id < b.id
end

-- Compara a exportação com os eventos salvos. Não altera nada.
-- `deleted` (opcional) são os registros de exclusão do jogo.
-- Retorna { created, updated, cancelled, removed, unchanged, outside, pending,
-- purged }.
--   created:   eventos ativos que o addon ainda não tem.
--   updated:   eventos com updatedAt maior, que continuam (ou voltam a ser) ativos.
--   cancelled: eventos que passaram a cancelados ou chegaram já cancelados
--              (isNew = true quando o addon não os tinha).
--   removed:   eventos salvos com início dentro da janela que não vieram
--              (os alterados no jogo só quando DeletedOnSite).
--   unchanged: quantidade de eventos sem alteração.
--   outside:   quantidade de eventos salvos fora da janela (não mexidos).
--   pending:   quantidade de alterações do jogo que aguardam o site (mantidas):
--              eventos que não vieram e exclusões mais novas que a exportação.
--   purged:    IDs de registros de exclusão que podem sair.
-- Cada item: { id, event, previous }.
function Snapshot.Diff(events, export, deleted)
  deleted = deleted or {}
  local diff = { created = {}, updated = {}, cancelled = {}, removed = {}, unchanged = 0, outside = 0,
    pending = 0, purged = {} }
  local incoming = {}

  for _, e in ipairs(export.events) do
    incoming[e.id] = true
    local old, gone = events[e.id], deleted[e.id]
    if gone and e.updatedAt <= gone.updatedAt then
      -- Excluído no jogo depois desta versão do site: continua excluído.
      diff.pending = diff.pending + 1
    elseif not old then
      if e.status == "ativo" then
        diff.created[#diff.created + 1] = { id = e.id, event = e }
      else
        diff.cancelled[#diff.cancelled + 1] = { id = e.id, event = e, isNew = true }
      end
    elseif e.updatedAt > old.updatedAt or (old.pending and e.updatedAt == old.updatedAt) then
      -- Mais nova que a do addon (no evento alterado no jogo, a do site com o
      -- mesmo horário também vale: o site aplicou a alteração).
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
      if old.pending and not Snapshot.DeletedOnSite(export, old) then
        diff.pending = diff.pending + 1
      elseif InWindow(export, old.startsAt) then
        diff.removed[#diff.removed + 1] = { id = id, event = old, previous = old }
      else
        diff.outside = diff.outside + 1
      end
    end
  end

  for id, gone in pairs(deleted) do
    if not incoming[id] and (Snapshot.GoneFrom(export, gone) or gone.startsAt < export.windowStart) then
      diff.purged[#diff.purged + 1] = id
    end
  end
  table.sort(diff.purged)

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

-- Aplica um diff (de Snapshot.Diff) aos eventos salvos e aos registros de
-- exclusão (`deleted`, opcional).
function Snapshot.Apply(events, diff, deleted)
  deleted = deleted or {}
  for _, list in ipairs({ diff.created, diff.updated, diff.cancelled }) do
    for _, item in ipairs(list) do
      events[item.id] = Copy(item.event)
      deleted[item.id] = nil -- o site tem uma versão mais nova que a exclusão
    end
  end
  for _, item in ipairs(diff.removed) do
    events[item.id] = nil
  end
  for _, id in ipairs(diff.purged or {}) do
    deleted[id] = nil
  end
  return events
end

ns.Snapshot = Snapshot
return Snapshot
