local addon = require("helpers.addon")

describe("GamePlan", function()
  local ns, GamePlan, Import, Codec, Config
  local A, B, C = "3kTq9ZcV1bWfX7rLm2Pa", "Hq2mB8xY4nRcT0vKs9Ue", "pL5wE1dN7sA3gF6hJ0Ko"

  before_each(function()
    ns = addon.Load()
    GamePlan, Import, Codec, Config = ns.GamePlan, ns.Import, ns.Codec, ns.Config
  end)

  local function Step(data, links, raw)
    local prepared = assert(Import.Prepare(data, raw))
    local diff = Import.Commit(data, prepared, { source = "import", receivedAt = 1 })
    GamePlan.FromDiff(links, diff)
    return diff
  end

  local function Ops(links, events)
    local ops = {}
    for _, item in ipairs(GamePlan.Pending(links, events)) do
      ops[#ops + 1] = item.link.op .. ":" .. item.id
    end
    return ops
  end

  local function Later(seconds, change)
    local export = addon.Expected()
    export.exportNumber = export.exportNumber + seconds
    if change then change(export) end
    export.count = #export.events
    return Codec.Encode(export)
  end

  it("cria os ativos e ignora cancelados que nunca foram criados", function()
    local data, links = { events = {} }, {}
    Step(data, links, addon.Read("valida.txt"))
    assert.are.same({ "create:" .. A, "create:" .. C }, Ops(links, data.events))
  end)

  it("edita, cancela e remove só eventos criados pelo addon", function()
    local data, links = { events = {} }, {}
    Step(data, links, addon.Read("valida.txt"))
    GamePlan.MarkDone(links, A, "101", "Raid", {})
    GamePlan.MarkDone(links, C, "103", "Encontro", {})
    assert.are.same({}, Ops(links, data.events))

    Step(data, links, Later(60, function(e)
      e.events[1].status = "cancelado"
      e.events[1].updatedAt = e.events[1].updatedAt + 1
      table.remove(e.events, 3)
    end))
    assert.are.same({ "remove:" .. C, "cancel:" .. A }, Ops(links, data.events))

    GamePlan.MarkDone(links, C)
    assert.is_nil(links[C])
  end)

  it("esquece a criação pendente de um evento que foi removido", function()
    local data, links = { events = {} }, {}
    Step(data, links, addon.Read("valida.txt"))
    Step(data, links, Later(60, function(e) table.remove(e.events, 3) end))
    assert.are.same({ "create:" .. A }, Ops(links, data.events))
  end)

  it("mantém criar quando um evento ainda não criado é alterado", function()
    local data, links = { events = {} }, {}
    Step(data, links, addon.Read("valida.txt"))
    Step(data, links, Later(60, function(e) e.events[1].updatedAt = e.events[1].updatedAt + 1 end))
    assert.are.same({ "create:" .. A, "create:" .. C }, Ops(links, data.events))
  end)

  it("cria um evento cancelado que foi reativado", function()
    local data, links = { events = {} }, {}
    Step(data, links, addon.Read("valida.txt"))
    Step(data, links, Later(60, function(e)
      e.events[2].status = "ativo"
      e.events[2].updatedAt = e.events[2].updatedAt + 1
    end))
    assert.are.same({ "create:" .. A, "create:" .. B, "create:" .. C }, Ops(links, data.events))
  end)

  it("registra falhas e permite tentar de novo", function()
    local data, links = { events = {} }, {}
    Step(data, links, addon.Read("valida.txt"))
    assert.are.equal(A, GamePlan.Next(links, data.events).id)
    GamePlan.MarkFailed(links, A, "sem permissão")
    assert.are.equal("failed", links[A].state)
    assert.are.equal(1, links[A].attempts)
    assert.are.equal(C, GamePlan.Next(links, data.events).id)
    GamePlan.Retry(links)
    assert.are.equal("pending", links[A].state)
    assert.are.equal(A, GamePlan.Next(links, data.events).id)
  end)

  it("monta título curto, sem | e com prefixo de cancelado", function()
    local event = { id = B, title = "Masmorras em grupo | Iniciantes", status = "cancelado" }
    local title = GamePlan.GameTitle(event, Config)
    assert.is_true(#title <= Config.GAME_TITLE_MAX_BYTES)
    assert.is_nil(string.find(title, "|", 1, true))
    assert.are.equal(1, string.find(title, Config.GAME_CANCELLED_PREFIX, 1, true))
  end)

  it("monta descrição com organizador e marca do evento dentro do limite", function()
    local event = {
      id = A, organizer = "Maren", status = "ativo",
      description = string.rep("Poções de resistência ao fogo. ", 40),
    }
    local description = GamePlan.GameDescription(event, Config)
    assert.is_true(#description <= Config.GAME_DESCRIPTION_MAX_BYTES)
    assert.are.equal(1, string.find(description, "Organizador: Maren", 1, true))
    assert.is_truthy(string.find(description, "[VDL:" .. A .. "]", 1, true))
  end)
end)
