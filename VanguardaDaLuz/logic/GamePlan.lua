-- Plano de alterações no calendário do jogo. Lógica pura.
--
-- `links` guarda a ligação entre o ID do site e o evento criado no jogo:
-- [id] = {
--   gameEventId = string|nil,  -- eventID do jogo, quando já criado
--   gameTitle, gameTime,       -- título e horário (tabela de data) gravados no jogo
--   op = "create"|"update"|"cancel"|"remove"|nil,
--   state = "pending"|"done"|"failed",
--   error = string|nil, attempts = número,
-- }
local _, ns = ...

local GamePlan = {}

-- Ordem de execução das operações.
GamePlan.ORDER = { remove = 1, cancel = 2, update = 3, create = 4 }

-- Decide a operação a partir do que existe no jogo e do estado desejado
-- ("active", "cancelled" ou "absent").
function GamePlan.Resolve(existsInGame, desired)
  if not existsInGame then
    if desired == "active" then return "create" end
    return nil
  end
  if desired == "active" then return "update" end
  if desired == "cancelled" then return "cancel" end
  return "remove"
end

local function Mark(links, id, desired)
  local link = links[id]
  local op = GamePlan.Resolve(link and link.gameEventId ~= nil, desired)
  if not op then
    -- Nada no jogo e nada a fazer: esquecer uma criação pendente.
    if link and not link.gameEventId then links[id] = nil end
    return
  end
  link = link or {}
  link.op, link.state, link.error, link.attempts = op, "pending", nil, 0
  links[id] = link
end

-- Registra em `links` as operações de um diff (de ns.Snapshot.Diff).
-- Operações pendentes anteriores do mesmo evento são substituídas, então
-- aplicar o mesmo diff duas vezes dá o mesmo resultado.
function GamePlan.FromDiff(links, diff)
  for _, item in ipairs(diff.created) do Mark(links, item.id, "active") end
  for _, item in ipairs(diff.updated) do
    Mark(links, item.id, item.event.status == "ativo" and "active" or "cancelled")
  end
  for _, item in ipairs(diff.cancelled) do Mark(links, item.id, "cancelled") end
  for _, item in ipairs(diff.removed) do Mark(links, item.id, "absent") end
  return links
end

-- Lista as operações pendentes ou com falha, em ordem de execução.
-- `events` é usado para ordenar pelo início e mostrar o título.
function GamePlan.Pending(links, events)
  local list = {}
  for id, link in pairs(links) do
    if link.op and link.state ~= "done" then
      list[#list + 1] = { id = id, link = link, event = events[id] }
    end
  end
  table.sort(list, function(a, b)
    local oa, ob = GamePlan.ORDER[a.link.op], GamePlan.ORDER[b.link.op]
    if oa ~= ob then return oa < ob end
    local sa = a.event and a.event.startsAt or 0
    local sb = b.event and b.event.startsAt or 0
    if sa ~= sb then return sa < sb end
    return a.id < b.id
  end)
  return list
end

-- Próxima operação a aplicar (pendente; falhas só depois de "tentar de novo").
function GamePlan.Next(links, events)
  for _, item in ipairs(GamePlan.Pending(links, events)) do
    if item.link.state == "pending" then return item end
  end
  return nil
end

-- Resultado de uma operação aplicada no jogo.
function GamePlan.MarkDone(links, id, gameEventId, gameTitle, gameTime)
  local link = links[id]
  if not link then return end
  if link.op == "remove" then
    links[id] = nil
    return
  end
  link.gameEventId = gameEventId or link.gameEventId
  link.gameTitle = gameTitle or link.gameTitle
  link.gameTime = gameTime or link.gameTime
  link.state, link.error, link.op = "done", nil, nil
end

function GamePlan.MarkFailed(links, id, message)
  local link = links[id]
  if not link then return end
  link.state = "failed"
  link.error = message
  link.attempts = (link.attempts or 0) + 1
end

-- Volta as falhas para pendentes.
function GamePlan.Retry(links, id)
  for linkId, link in pairs(links) do
    if (not id or linkId == id) and link.state == "failed" then
      link.state, link.error = "pending", nil
    end
  end
end

-- Título e descrição gravados no calendário do jogo.
function GamePlan.GameTitle(event, config)
  local Text = ns.Text
  local title = Text.ForGame(event.title)
  if event.status == "cancelado" then title = config.GAME_CANCELLED_PREFIX .. title end
  return Text.Truncate(title, config.GAME_TITLE_MAX_BYTES)
end

-- Marca no fim da descrição, para identificar os eventos criados pelo addon.
function GamePlan.Tag(id)
  return "[VDL:" .. id .. "]"
end

function GamePlan.GameDescription(event, config)
  local Text = ns.Text
  local tag = "\n" .. GamePlan.Tag(event.id)
  local body = "Organizador: " .. event.organizer .. "\n" .. event.description
  body = Text.Truncate(Text.ForGame(body), config.GAME_DESCRIPTION_MAX_BYTES - #tag)
  return body .. tag
end

ns.GamePlan = GamePlan
return GamePlan
