local addon = require("helpers.addon")

describe("Import e retrato completo", function()
  local ns, Import, Codec
  local base -- exportação de esperado.lua
  local DAY = 86400

  before_each(function()
    ns = addon.Load()
    Import, Codec = ns.Import, ns.Codec
    base = addon.Expected()
  end)

  local function NewData()
    return { events = {} }
  end

  local function Commit(data, raw)
    local prepared, code = Import.Prepare(data, raw)
    assert.is_table(prepared, code)
    return Import.Commit(data, prepared, { source = "import", receivedAt = 100 })
  end

  -- Exportação seguinte, gerada `seconds` depois da base.
  local function Later(seconds)
    local export = addon.Copy(base)
    export.exportNumber = base.exportNumber + seconds
    return export
  end

  local function Ids(list)
    local ids = {}
    for _, item in ipairs(list) do ids[#ids + 1] = item.id end
    return ids
  end

  local A, B, C = "3kTq9ZcV1bWfX7rLm2Pa", "Hq2mB8xY4nRcT0vKs9Ue", "pL5wE1dN7sA3gF6hJ0Ko"

  it("importa valida.txt pela primeira vez", function()
    local data = NewData()
    local diff = Commit(data, addon.Read("valida.txt"))
    assert.are.same({ A, C }, Ids(diff.created))
    assert.are.same({ B }, Ids(diff.cancelled))
    assert.is_true(diff.cancelled[1].isNew)
    assert.are.same({}, diff.removed)
    assert.are.equal("cancelado", data.events[B].status)
    assert.are.equal(base.exportNumber, data.export.exportNumber)
    assert.are.equal(ns.Text.Trim(addon.Read("valida.txt")), data.export.raw)
  end)

  it("recusa string corrompida sem alterar os dados", function()
    local data = NewData()
    Commit(data, addon.Read("valida.txt"))
    local before = addon.Copy(data)
    assert.are.same({ nil, "compression" }, { Import.Prepare(data, addon.Read("corrompida.txt")) })
    assert.are.same(before, data)
  end)

  it("recusa exportação de outro jogo", function()
    local export = Later(60)
    export.game = "retail"
    assert.are.same({ nil, "game" }, { Import.Prepare(NewData(), Codec.Encode(export)) })
  end)

  it("recusa exportação igual ou mais antiga que a última", function()
    local data = NewData()
    Commit(data, addon.Read("valida.txt"))
    assert.are.same({ nil, "old" }, { Import.Prepare(data, addon.Read("valida.txt")) })
    assert.are.same({ nil, "old" }, { Import.Prepare(data, Codec.Encode(Later(-60))) })
  end)

  it("recusa string maior que o limite", function()
    local raw = addon.Read("valida.txt")
    assert.are.same({ nil, "size" }, { Import.Prepare(NewData(), raw, { maxLength = 100 }) })
  end)

  it("atualiza só eventos com updatedAt maior", function()
    local data = NewData()
    Commit(data, addon.Read("valida.txt"))
    local export = Later(60)
    export.events[1].title = "Raid: Núcleo Derretido (nova data)"
    export.events[1].updatedAt = export.events[1].updatedAt + 10
    export.events[3].title = "Título mudado sem updatedAt"
    local diff = Commit(data, Codec.Encode(export))
    assert.are.same({ A }, Ids(diff.updated))
    assert.are.equal(2, diff.unchanged)
    assert.are.equal("Raid: Núcleo Derretido (nova data)", data.events[A].title)
    assert.are.equal("Encontro da guilda", data.events[C].title)
  end)

  it("marca como cancelado um evento ativo que foi cancelado", function()
    local data = NewData()
    Commit(data, addon.Read("valida.txt"))
    local export = Later(60)
    export.events[3].status = "cancelado"
    export.events[3].updatedAt = export.events[3].updatedAt + 10
    local diff = Commit(data, Codec.Encode(export))
    assert.are.same({ C }, Ids(diff.cancelled))
    assert.is_nil(diff.cancelled[1].isNew)
    assert.are.equal("cancelado", data.events[C].status)
  end)

  it("remove evento dentro da janela que não veio na exportação", function()
    local data = NewData()
    Commit(data, addon.Read("valida.txt"))
    local export = Later(60)
    table.remove(export.events, 3)
    export.count = 2
    local diff = Commit(data, Codec.Encode(export))
    assert.are.same({ C }, Ids(diff.removed))
    assert.is_nil(data.events[C])
  end)

  it("não mexe em eventos fora da janela", function()
    local data = NewData()
    Commit(data, addon.Read("valida.txt"))
    -- Nova janela começa 1 dia depois do primeiro evento e termina antes do último.
    local export = Later(3 * DAY)
    export.windowStart = base.events[1].startsAt + DAY
    export.windowEnd = base.events[3].startsAt - DAY
    export.events = { export.events[2] }
    export.count = 1
    local diff = Commit(data, Codec.Encode(export))
    assert.are.same({}, diff.removed)
    assert.are.equal(2, diff.outside)
    assert.are.same(base.events[1], data.events[A])
    assert.are.same(base.events[3], data.events[C])
  end)

  it("reativa um evento cancelado", function()
    local data = NewData()
    Commit(data, addon.Read("valida.txt"))
    local export = Later(60)
    export.events[2].status = "ativo"
    export.events[2].updatedAt = export.events[2].updatedAt + 10
    local diff = Commit(data, Codec.Encode(export))
    assert.are.same({ B }, Ids(diff.updated))
    assert.are.equal("ativo", data.events[B].status)
  end)

  it("é idempotente: o mesmo retrato aplicado de novo não muda nada", function()
    local data = NewData()
    local prepared = Import.Prepare(data, addon.Read("valida.txt"))
    Import.Commit(data, prepared, { source = "import", receivedAt = 1 })
    local snapshot = addon.Copy(data.events)
    local again = ns.Snapshot.Diff(data.events, prepared.export)
    assert.are.equal(0, ns.Snapshot.CountChanges(again))
    ns.Snapshot.Apply(data.events, again)
    assert.are.same(snapshot, data.events)
  end)
end)
