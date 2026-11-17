-- Eventos criados e alterados no jogo (Grão Lorde e Lordes). Lógica pura.
--
-- Ficam na mesma tabela dos eventos do site (`events`, ver logic/Snapshot.lua),
-- com campos a mais:
--   pending = true      alterado no jogo; aguarda o site (backup VDLB1). Sai
--                       quando o evento volta numa exportação VDL1 com
--                       updatedAt igual ou maior
--   origin  = "jogo"    criado no jogo (o site cria com o mesmo `id`)
--           = "site"    evento do site alterado no jogo
--   max     = vagas     só nos criados no jogo (o addon não sabe as do site)
--   guests  = boolean   aceita visitantes; só nos criados no jogo
--   by      = nome      personagem que fez a última alteração no jogo
--
-- Eventos cancelados excluídos no jogo saem de `events` e ficam em `deleted`
-- ([id] = o evento com status "excluido" e pending = true) até o site também
-- os excluir: o registro impede que uma exportação mais antiga ou a mensagem
-- de outro membro traga o evento de volta. Sai em logic/Snapshot.lua.
--
-- Em cada evento vale a alteração mais recente (updatedAt), venha do jogo ou
-- do site.
local _, ns = ...

local Text = ns.Text

local GameEvents = {}

GameEvents.ID_LENGTH = 20
GameEvents.LIMITS = { title = 80, organizer = 40, description = 2000 } -- iguais aos do site
GameEvents.MAX_ATTENDEES = { min = 1, max = 500, default = 40 }        -- iguais aos do site

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

-- ID novo, no mesmo formato dos IDs do site (20 letras e dígitos). `random` é
-- math.random ou outra com a mesma assinatura (para os testes).
function GameEvents.NewId(random)
  random = random or math.random
  local chars = {}
  for i = 1, GameEvents.ID_LENGTH do
    local k = random(1, #ALPHABET)
    chars[i] = string.sub(ALPHABET, k, k)
  end
  return table.concat(chars)
end

local function ValidId(id)
  return type(id) == "string" and string.find(id, "^%w+$") ~= nil and #id <= 64
end

local function ValidName(name)
  return type(name) == "string" and name ~= "" and not string.find(name, "[|%c]")
end

-- "dd/mm/aaaa" -> ano, mês, dia (ou nil).
function GameEvents.ParseDate(text)
  local d, m, y = string.match(Text.Trim(text or ""), "^(%d%d?)/(%d%d?)/(%d%d%d%d)$")
  d, m, y = tonumber(d), tonumber(m), tonumber(y)
  if not d or m < 1 or m > 12 or d < 1 then return nil end
  if d > ns.Time.DaysInMonth(y, m) then return nil end
  return y, m, d
end

-- "hh:mm" -> hora, minuto (ou nil).
function GameEvents.ParseClock(text)
  local h, mi = string.match(Text.Trim(text or ""), "^(%d%d?):(%d%d)$")
  h, mi = tonumber(h), tonumber(mi)
  if not h or h > 23 or mi > 59 then return nil end
  return h, mi
end

-- Valida o formulário. `input` = { title, description, organizer, startsAt,
-- max, guests }; `max` e `guests` só contam em eventos criados no jogo
-- (`withLimits`). Retorna os campos limpos ou nil e o código do erro:
-- "title", "organizer", "description", "past" ou "max".
function GameEvents.Validate(input, now, withLimits)
  local title = Text.Trim(input.title or "")
  local organizer = Text.Trim(input.organizer or "")
  local description = Text.Trim(input.description or "")
  local L = GameEvents.LIMITS
  if title == "" or Text.Length(title) > L.title then return nil, "title" end
  if organizer == "" or Text.Length(organizer) > L.organizer then return nil, "organizer" end
  if Text.Length(description) > L.description then return nil, "description" end
  if type(input.startsAt) ~= "number" or input.startsAt <= now then return nil, "past" end
  local clean = { title = title, organizer = organizer, description = description, startsAt = input.startsAt }
  if withLimits then
    local max, range = input.max, GameEvents.MAX_ATTENDEES
    if type(max) ~= "number" or max ~= math.floor(max) or max < range.min or max > range.max then
      return nil, "max"
    end
    clean.max, clean.guests = max, input.guests and true or false
  end
  return clean
end

-- Pode ser editado ou cancelado: ativo e ainda não começou (a regra do site).
function GameEvents.IsChangeable(event, now)
  return event ~= nil and event.status == "ativo" and event.startsAt > now
end

-- Horário da alteração: o atual, ou um segundo depois da anterior (duas
-- alterações no mesmo segundo).
local function NextTime(old, now)
  return math.max(now, (old and old.updatedAt or 0) + 1)
end

-- Cria um evento. `meta` = { id, now, by }. Retorna o evento.
function GameEvents.Create(events, fields, meta)
  local event = {
    id = meta.id, origin = "jogo", status = "ativo", pending = true, by = meta.by,
    title = fields.title, startsAt = fields.startsAt, description = fields.description,
    organizer = fields.organizer, max = fields.max, guests = fields.guests,
    updatedAt = meta.now,
  }
  events[event.id] = event
  return event
end

-- Edita um evento (do jogo ou do site). Vagas e visitantes só mudam nos
-- criados no jogo. Retorna o evento ou nil se não pode ser alterado.
function GameEvents.Edit(events, id, fields, meta)
  local old = events[id]
  if not GameEvents.IsChangeable(old, meta.now) then return nil end
  local event = {
    id = id, origin = old.origin or "site", status = "ativo", pending = true, by = meta.by,
    title = fields.title, startsAt = fields.startsAt, description = fields.description,
    organizer = fields.organizer, max = old.max, guests = old.guests,
    updatedAt = NextTime(old, meta.now),
  }
  if event.origin == "jogo" and fields.max then event.max, event.guests = fields.max, fields.guests end
  events[id] = event
  return event
end

-- Cancela um evento. Retorna o evento ou nil se não pode ser alterado.
function GameEvents.Cancel(events, id, meta)
  local old = events[id]
  if not GameEvents.IsChangeable(old, meta.now) then return nil end
  local event = {}
  for k, v in pairs(old) do event[k] = v end
  event.origin, event.status, event.pending, event.by = old.origin or "site", "cancelado", true, meta.by
  event.updatedAt = NextTime(old, meta.now)
  events[id] = event
  return event
end

-- Pode ser excluído: cancelado (a regra do site).
function GameEvents.IsDeletable(event)
  return event ~= nil and event.status == "cancelado"
end

-- Exclui um evento cancelado: sai de `events` e fica registrado em `deleted`.
-- Retorna o registro ou nil se não pode ser excluído.
function GameEvents.Delete(events, deleted, id, meta)
  local old = events[id]
  if not GameEvents.IsDeletable(old) then return nil end
  local record = {
    id = id, origin = old.origin or "site", status = "excluido", pending = true, by = meta.by,
    title = old.title, startsAt = old.startsAt, description = old.description or "",
    organizer = old.organizer or "", max = old.max, guests = old.guests,
    updatedAt = NextTime(old, meta.now),
  }
  events[id] = nil
  deleted[id] = record
  return record
end

-- Alteração válida (recebida de outro membro ou de um backup)?
function GameEvents.IsValid(e)
  if type(e) ~= "table" or not ValidId(e.id) then return false end
  if e.origin ~= "jogo" and e.origin ~= "site" then return false end
  if e.status ~= "ativo" and e.status ~= "cancelado" and e.status ~= "excluido" then return false end
  if type(e.title) ~= "string" or e.title == "" or type(e.organizer) ~= "string" then return false end
  if type(e.description) ~= "string" or not ValidName(e.by) then return false end
  if type(e.startsAt) ~= "number" or type(e.updatedAt) ~= "number" then return false end
  if e.max ~= nil and (type(e.max) ~= "number" or e.max < 1) then return false end
  if e.guests ~= nil and type(e.guests) ~= "boolean" then return false end
  return true
end

-- Aplica uma alteração recebida, se for mais nova que a que o addon tem.
-- `export` é a última exportação importada (ou nil); `deleted`, os registros
-- de exclusão. Retorna true se mudou o estado.
function GameEvents.Merge(events, e, export, deleted)
  deleted = deleted or {}
  if not GameEvents.IsValid(e) then return false end
  local old = events[e.id] or deleted[e.id]
  if old and old.updatedAt >= e.updatedAt then return false end
  -- Evento que a última exportação importada já não trazia e que foi alterado
  -- antes dela: o site o excluiu (ou já aplicou a exclusão), então a
  -- alteração não o traz de volta.
  if not old and export and (e.origin == "site" or e.status == "excluido")
    and ns.Snapshot.GoneFrom(export, e) then
    return false
  end
  local record = {
    id = e.id, origin = e.origin, status = e.status, pending = true, by = e.by,
    title = e.title, startsAt = e.startsAt, description = e.description, organizer = e.organizer,
    max = e.max, guests = e.guests, updatedAt = e.updatedAt,
  }
  if e.status == "excluido" then
    events[e.id], deleted[e.id] = nil, record
  else
    events[e.id], deleted[e.id] = record, nil
  end
  return true
end

-- Alterações do jogo que aguardam o site (com as exclusões), por ID.
function GameEvents.Pending(events, deleted)
  local list = {}
  for _, source in ipairs({ events, deleted or {} }) do
    for _, e in pairs(source) do
      if e.pending then list[#list + 1] = e end
    end
  end
  table.sort(list, function(a, b) return a.id < b.id end)
  return list
end

ns.GameEvents = GameEvents
return GameEvents
