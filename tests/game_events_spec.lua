local addon = require("helpers.addon")

describe("GameEvents", function()
  local ns, G

  before_each(function()
    ns = addon.Load()
    G = ns.GameEvents
  end)

  local NOW = 1794400000

  local function Fields(extra)
    local f = { title = "Raide", organizer = "Victor Vaz", description = "", startsAt = NOW + 3600, max = 40,
      guests = true }
    for k, v in pairs(extra or {}) do f[k] = v end
    return f
  end

  it("gera IDs de 20 letras e dígitos", function()
    local id = G.NewId()
    assert.are.equal(20, #id)
    assert.is_truthy(id:find("^%w+$"))
    assert.are.equal(string.rep("A", 20), G.NewId(function() return 1 end))
  end)

  it("lê data e hora", function()
    assert.are.same({ 2026, 11, 20 }, { G.ParseDate(" 20/11/2026 ") })
    assert.is_nil(G.ParseDate("31/02/2026"))
    assert.is_nil(G.ParseDate("2026-11-20"))
    assert.are.same({ 9, 5 }, { G.ParseClock("9:05") })
    assert.is_nil(G.ParseClock("24:00"))
    assert.is_nil(G.ParseClock("10:60"))
  end)

  it("valida o formulário", function()
    local clean = G.Validate(Fields({ title = "  Raide  " }), NOW, true)
    assert.are.equal("Raide", clean.title)
    assert.are.equal(40, clean.max)
    assert.is_true(clean.guests)
    assert.is_nil(G.Validate(Fields({ title = "" }), NOW, true))
    assert.are.same({ nil, "title" }, { G.Validate(Fields({ title = string.rep("á", 81) }), NOW, true) })
    assert.are.same({ nil, "organizer" }, { G.Validate(Fields({ organizer = " " }), NOW, true) })
    assert.are.same({ nil, "description" }, { G.Validate(Fields({ description = string.rep("x", 2001) }), NOW) })
    assert.are.same({ nil, "past" }, { G.Validate(Fields({ startsAt = NOW }), NOW, true) })
    assert.are.same({ nil, "max" }, { G.Validate(Fields({ max = 0 }), NOW, true) })
    assert.are.same({ nil, "max" }, { G.Validate(Fields({ max = 501 }), NOW, true) })
    -- Sem vagas e visitantes (evento do site): não são conferidos nem copiados.
    local site = G.Validate(Fields({ max = 0 }), NOW, false)
    assert.is_nil(site.max)
  end)

  it("cria, edita e cancela", function()
    local events = {}
    local e = G.Create(events, G.Validate(Fields(), NOW, true), { id = "abc", now = NOW, by = "Victor Vaz" })
    assert.are.same({ id = "abc", origin = "jogo", status = "ativo", pending = true, by = "Victor Vaz",
      title = "Raide", startsAt = NOW + 3600, description = "", organizer = "Victor Vaz", max = 40, guests = true,
      updatedAt = NOW }, events.abc)
    assert.are.equal(e, events.abc)

    -- Duas alterações no mesmo segundo: a segunda é mais nova.
    G.Edit(events, "abc", G.Validate(Fields({ title = "Raide 2", max = 10, guests = false }), NOW, true),
      { now = NOW, by = "Maren Luz" })
    assert.are.equal("Raide 2", events.abc.title)
    assert.are.equal(10, events.abc.max)
    assert.is_false(events.abc.guests)
    assert.are.equal(NOW + 1, events.abc.updatedAt)
    assert.are.equal("Maren Luz", events.abc.by)

    G.Cancel(events, "abc", { now = NOW + 5, by = "Victor Vaz" })
    assert.are.equal("cancelado", events.abc.status)
    assert.are.equal("Raide 2", events.abc.title)
    -- Cancelado não muda mais.
    assert.is_nil(G.Edit(events, "abc", G.Validate(Fields(), NOW, true), { now = NOW + 6, by = "X Y" }))
    assert.is_nil(G.Cancel(events, "abc", { now = NOW + 6, by = "X Y" }))
  end)

  it("edita evento do site sem mexer em vagas e visitantes", function()
    local events = { site1 = { id = "site1", title = "Site", startsAt = NOW + 100, description = "d",
      organizer = "Tavia", status = "ativo", updatedAt = NOW - 50 } }
    G.Edit(events, "site1", G.Validate(Fields({ max = 3 }), NOW, false), { now = NOW, by = "Victor Vaz" })
    local e = events.site1
    assert.are.equal("site", e.origin)
    assert.is_true(e.pending)
    assert.is_nil(e.max)
    assert.is_nil(e.guests)
    -- Evento que já começou não é alterado.
    events.past = { id = "past", title = "P", startsAt = NOW - 1, description = "", organizer = "",
      status = "ativo", updatedAt = 1 }
    assert.is_nil(G.Cancel(events, "past", { now = NOW, by = "Victor Vaz" }))
  end)

  it("mescla só alterações mais novas e válidas", function()
    local events = {}
    local change = { id = "abc", origin = "jogo", status = "ativo", title = "T", startsAt = NOW + 10,
      description = "", organizer = "O", updatedAt = NOW, by = "Victor Vaz", max = 5, guests = false }
    assert.is_true(G.Merge(events, change))
    assert.is_true(events.abc.pending)
    assert.is_false(G.Merge(events, change))
    local newer = addon.Copy(change)
    newer.updatedAt, newer.title = NOW + 1, "T2"
    assert.is_true(G.Merge(events, newer))
    assert.are.equal("T2", events.abc.title)
    local bad = addon.Copy(newer)
    bad.updatedAt, bad.id = NOW + 2, "a|b"
    assert.is_false(G.Merge(events, bad))
  end)

  describe("exclusão", function()
    local function Cancelled()
      local events, deleted = {}, {}
      G.Create(events, G.Validate(Fields(), NOW, true), { id = "abc", now = NOW, by = "Victor Vaz" })
      G.Cancel(events, "abc", { now = NOW, by = "Victor Vaz" })
      return events, deleted
    end

    it("só exclui evento cancelado e guarda o registro", function()
      local events, deleted = {}, {}
      G.Create(events, G.Validate(Fields(), NOW, true), { id = "abc", now = NOW, by = "Victor Vaz" })
      assert.is_nil(G.Delete(events, deleted, "abc", { now = NOW, by = "Victor Vaz" }))
      assert.is_nil(G.Delete(events, deleted, "nada", { now = NOW, by = "Victor Vaz" }))
      G.Cancel(events, "abc", { now = NOW, by = "Victor Vaz" })
      local record = G.Delete(events, deleted, "abc", { now = NOW, by = "Maren" })
      assert.is_nil(events.abc)
      assert.are.equal("excluido", deleted.abc.status)
      assert.are.equal("Maren", record.by)
      assert.are.equal(NOW + 2, record.updatedAt) -- depois do cancelamento, no mesmo segundo
      assert.is_true(G.IsValid(record))
      assert.are.equal(1, #G.Pending(events, deleted))
    end)

    it("a exclusão recebida remove o evento, e alterações mais antigas não o trazem de volta", function()
      local events, deleted = Cancelled()
      local record = G.Delete(addon.Copy(events), {}, "abc", { now = NOW + 10, by = "Maren" })
      local older = addon.Copy(events.abc)
      assert.is_true(G.Merge(events, record, nil, deleted))
      assert.is_nil(events.abc)
      assert.are.equal("excluido", deleted.abc.status)
      assert.is_false(G.Merge(events, older, nil, deleted))
      assert.is_nil(events.abc)
      -- Uma versão mais nova (reativada) volta e tira o registro.
      local newer = addon.Copy(older)
      newer.status, newer.updatedAt = "ativo", NOW + 20
      assert.is_true(G.Merge(events, newer, nil, deleted))
      assert.are.equal("ativo", events.abc.status)
      assert.is_nil(deleted.abc)
    end)

    it("segue as exportações do site", function()
      local window = { windowStart = NOW - 86400, windowEnd = NOW + 86400 * 60 }
      local function Export(list, number)
        return { windowStart = window.windowStart, windowEnd = window.windowEnd, exportNumber = number, events = list }
      end
      local site = { id = "s", title = "Raide", startsAt = NOW + 100, description = "", organizer = "T",
        status = "cancelado", updatedAt = NOW - 100 }
      local events, deleted = { s = addon.Copy(site) }, {}
      G.Delete(events, deleted, "s", { now = NOW, by = "Victor Vaz" })
      -- Exportação anterior à exclusão ainda traz o evento: continua excluído.
      local diff = ns.Snapshot.Diff(events, Export({ addon.Copy(site) }, NOW - 50), deleted)
      assert.are.equal(0, #diff.created + #diff.cancelled)
      assert.are.equal(1, diff.pending)
      ns.Snapshot.Apply(events, diff, deleted)
      assert.is_nil(events.s)
      assert.is_not_nil(deleted.s)
      -- Exportação anterior sem o evento: o registro fica.
      diff = ns.Snapshot.Diff(events, Export({}, NOW - 50), deleted)
      assert.are.equal(0, #diff.purged)
      -- O site aplicou a exclusão: a exportação seguinte não o traz e o registro sai.
      diff = ns.Snapshot.Diff(events, Export({}, NOW + 60), deleted)
      assert.are.same({ "s" }, diff.purged)
      ns.Snapshot.Apply(events, diff, deleted)
      assert.is_nil(deleted.s)
    end)

    it("o site reativou o evento depois da exclusão: ele volta", function()
      local site = { id = "s", title = "Raide", startsAt = NOW + 100, description = "", organizer = "T",
        status = "cancelado", updatedAt = NOW - 100 }
      local events, deleted = { s = addon.Copy(site) }, {}
      G.Delete(events, deleted, "s", { now = NOW, by = "Victor Vaz" })
      local newer = addon.Copy(site)
      newer.status, newer.updatedAt = "ativo", NOW + 30
      local export = { windowStart = NOW - 86400, windowEnd = NOW + 86400, exportNumber = NOW + 60, events = { newer } }
      ns.Snapshot.Apply(events, ns.Snapshot.Diff(events, export, deleted), deleted)
      assert.are.equal("ativo", events.s.status)
      assert.is_nil(deleted.s)
    end)

    it("o registro de um evento que já passou sai na importação", function()
      local events, deleted = Cancelled()
      G.Delete(events, deleted, "abc", { now = NOW, by = "Victor Vaz" })
      local export = { windowStart = NOW + 86400, windowEnd = NOW + 86400 * 60, exportNumber = NOW - 10, events = {} }
      assert.are.same({ "abc" }, ns.Snapshot.Diff(events, export, deleted).purged)
    end)

    it("não aceita por mensagem a exclusão que o site já aplicou", function()
      local events, deleted = Cancelled()
      local record = G.Delete(addon.Copy(events), {}, "abc", { now = NOW, by = "Victor Vaz" })
      events.abc = nil
      local export = { windowStart = NOW - 86400, windowEnd = NOW + 86400, exportNumber = NOW + 60, events = {} }
      assert.is_false(G.Merge(events, record, export, deleted))
      assert.is_nil(deleted.abc)
    end)

    it("viaja na string de backup", function()
      local events, deleted = Cancelled()
      G.Delete(events, deleted, "abc", { now = NOW, by = "Victor Vaz" })
      local data = { game = "forever", generatedAt = NOW, exportNumber = 0, generatedBy = "Victor Vaz",
        events = G.Pending(events, deleted), attendance = {}, professions = {}, members = {}, together = {} }
      local back = ns.BackupCodec.Decode(ns.BackupCodec.Encode(data))
      assert.are.equal("excluido", back.events[1].status)
    end)
  end)

  it("lista os pendentes por ID", function()
    local events = { b = { id = "b", pending = true }, a = { id = "a", pending = true }, c = { id = "c" } }
    local list = G.Pending(events)
    assert.are.equal(2, #list)
    assert.are.equal("a", list[1].id)
    assert.are.equal("b", list[2].id)
  end)

  describe("com a exportação do site", function()
    local function Export(events, exportNumber)
      return { windowStart = NOW - 86400, windowEnd = NOW + 86400 * 60, events = events,
        exportNumber = exportNumber or NOW - 3600 }
    end

    -- Evento do site editado no jogo em NOW.
    local function EditedSiteEvent()
      local events = { s = { id = "s", title = "Velho", startsAt = NOW + 100, description = "", organizer = "T",
        status = "ativo", updatedAt = NOW - 100 } }
      G.Edit(events, "s", G.Validate(Fields({ title = "Novo" }), NOW, false), { now = NOW, by = "Victor Vaz" })
      return events
    end

    it("remove o evento do site alterado no jogo que some de uma exportação mais nova", function()
      local events = EditedSiteEvent()
      local diff = ns.Snapshot.Diff(events, Export({}, NOW + 60))
      assert.are.equal(1, #diff.removed)
      assert.are.equal(0, diff.pending)
      ns.Snapshot.Apply(events, diff)
      assert.is_nil(events.s)
    end)

    it("mantém o evento do site alterado no jogo quando a exportação é anterior à alteração", function()
      local events = EditedSiteEvent()
      local diff = ns.Snapshot.Diff(events, Export({}, NOW))
      assert.are.equal(0, #diff.removed)
      assert.are.equal(1, diff.pending)
    end)

    it("não remove o criado no jogo por uma exportação mais nova", function()
      local events = {}
      G.Create(events, G.Validate(Fields(), NOW, true), { id = "abc", now = NOW, by = "Victor Vaz" })
      local diff = ns.Snapshot.Diff(events, Export({}, NOW + 60))
      assert.are.equal(0, #diff.removed)
      assert.are.equal(1, diff.pending)
    end)

    it("não traz de volta, por mensagem, o evento que o site excluiu", function()
      local change = EditedSiteEvent().s
      local export = Export({}, NOW + 60)
      local events = {}
      assert.is_false(G.Merge(events, change, export))
      assert.is_nil(events.s)
      -- Exportação anterior à alteração, ou evento criado no jogo: entra.
      assert.is_true(G.Merge(events, change, Export({}, NOW)))
      local created = addon.Copy(change)
      created.id, created.origin = "abc", "jogo"
      assert.is_true(G.Merge(events, created, export))
    end)

    it("mantém o evento criado no jogo que ainda não veio", function()
      local events = {}
      G.Create(events, G.Validate(Fields(), NOW, true), { id = "abc", now = NOW, by = "Victor Vaz" })
      local diff = ns.Snapshot.Diff(events, Export({}))
      assert.are.equal(0, #diff.removed)
      assert.are.equal(1, diff.pending)
      ns.Snapshot.Apply(events, diff)
      assert.is_not_nil(events.abc)
    end)

    it("não desfaz a alteração do jogo com uma versão mais antiga do site", function()
      local events = { s = { id = "s", title = "Velho", startsAt = NOW + 100, description = "", organizer = "T",
        status = "ativo", updatedAt = NOW - 100 } }
      G.Edit(events, "s", G.Validate(Fields({ title = "Novo" }), NOW, false), { now = NOW, by = "Victor Vaz" })
      local site = { id = "s", title = "Velho", startsAt = NOW + 100, description = "", organizer = "T",
        status = "ativo", updatedAt = NOW - 100 }
      local diff = ns.Snapshot.Diff(events, Export({ site }))
      ns.Snapshot.Apply(events, diff)
      assert.are.equal("Novo", events.s.title)
      assert.is_true(events.s.pending)
    end)

    it("segue o site quando ele aplica a alteração ou muda depois", function()
      local events = {}
      G.Create(events, G.Validate(Fields(), NOW, true), { id = "abc", now = NOW, by = "Victor Vaz" })
      local site = { id = "abc", title = "Raide", startsAt = NOW + 3600, description = "", organizer = "Victor Vaz",
        status = "ativo", updatedAt = NOW }
      ns.Snapshot.Apply(events, ns.Snapshot.Diff(events, Export({ site })))
      assert.is_nil(events.abc.pending)
      assert.is_nil(events.abc.origin)
      -- Depois disso, sumir da exportação remove como qualquer evento do site.
      local diff = ns.Snapshot.Diff(events, Export({}))
      assert.are.equal(1, #diff.removed)
    end)
  end)
end)
