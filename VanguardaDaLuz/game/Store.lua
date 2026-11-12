-- SavedVariables (VanguardaDaLuzDB, por conta).
--
-- VanguardaDaLuzDB = {
--   schema = 1,
--   export = { raw, exportNumber, windowStart, windowEnd, count,
--              receivedAt, source = "import"|"guild", sender },
--   events = { [siteId] = { id, title, startsAt, description, organizer, status, updatedAt } },
--   attendance = { [siteId] = { [personagem] = { s, t } } },     -- logic/Attendance.lua
--   professions = { [personagem] = { t, p = { { n, l, m } } } }, -- logic/Professions.lua
--   settings = { minimap = { angle, hide } },
-- }
local _, ns = ...

local Store = {}
local SCHEMA = 1

function Store.Init()
  VanguardaDaLuzDB = VanguardaDaLuzDB or {}
  local db = VanguardaDaLuzDB
  db.schema = db.schema or SCHEMA
  db.events = db.events or {}
  -- Versões anteriores guardavam aqui a ligação com o calendário do jogo.
  db.game = nil
  db.settings = db.settings or {}
  db.settings.minimap = db.settings.minimap or { angle = 210, hide = false }
  ns.db = db
end

function Store.ExportNumber()
  return ns.db.export and ns.db.export.exportNumber or nil
end

-- Valida uma string sem alterar nada. Retorna a importação preparada ou
-- nil e a mensagem do erro.
function Store.Prepare(raw)
  local prepared, code = ns.Import.Prepare(ns.db, raw)
  if not prepared then return nil, ns.Codec.ERRORS[code] or code, code end
  return prepared
end

-- Aplica uma importação preparada. `source` é "import" ou "guild".
function Store.Commit(prepared, source, sender)
  local diff = ns.Import.Commit(ns.db, prepared, {
    source = source, sender = sender, receivedAt = GetServerTime(),
  })
  ns.Fire("DATA_UPDATED")
  return diff
end

-- Eventos de um dia (no horário de Brasília), ordenados pelo início.
function Store.EventsOn(year, month, day)
  local list, offset = {}, ns.Config.BRASILIA_OFFSET
  for _, event in pairs(ns.db.events) do
    local f = ns.Time.Fields(event.startsAt, offset)
    if f.year == year and f.month == month and f.day == day then list[#list + 1] = event end
  end
  table.sort(list, function(a, b)
    if a.startsAt ~= b.startsAt then return a.startsAt < b.startsAt end
    return a.id < b.id
  end)
  return list
end

-- Próximo evento ativo que ainda não começou (ou nil).
function Store.NextEvent(now)
  local best
  for _, event in pairs(ns.db.events) do
    if event.status == "ativo" and event.startsAt > now
      and (not best or event.startsAt < best.startsAt
        or (event.startsAt == best.startsAt and event.id < best.id)) then
      best = event
    end
  end
  return best
end

ns.Store = Store
