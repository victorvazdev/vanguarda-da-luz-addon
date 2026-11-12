local addon = require("helpers.addon")

describe("Attendance", function()
  local A

  before_each(function()
    A = addon.Load().Attendance
  end)

  it("aceita respostas só em eventos ativos que não começaram", function()
    assert.is_true(A.IsOpen({ status = "ativo", startsAt = 200 }, 100))
    assert.is_false(A.IsOpen({ status = "ativo", startsAt = 100 }, 100))
    assert.is_false(A.IsOpen({ status = "cancelado", startsAt = 200 }, 100))
    assert.is_false(A.IsOpen(nil, 100))
  end)

  it("guarda a resposta mais recente de cada personagem", function()
    local store = {}
    assert.is_true(A.Set(store, "ev1", "Victor Vaz", 1, 100))
    assert.is_false(A.Set(store, "ev1", "Victor Vaz", 0, 90))  -- mais antiga
    assert.is_false(A.Set(store, "ev1", "Victor Vaz", 0, 100)) -- empate: mantém
    assert.are.equal(1, A.Status(store, "ev1", "Victor Vaz"))
    assert.is_true(A.Set(store, "ev1", "Victor Vaz", 0, 110))
    assert.are.equal(0, A.Status(store, "ev1", "Victor Vaz"))
    assert.is_nil(A.Status(store, "ev1", "Maren Luz"))
  end)

  it("recusa respostas inválidas", function()
    local store = {}
    assert.is_false(A.Set(store, "", "Victor Vaz", 1, 1))
    assert.is_false(A.Set(store, "ev1", "", 1, 1))
    assert.is_false(A.Set(store, "ev1", "Victor Vaz", 2, 1))
    assert.is_false(A.Set(store, "ev1", "Victor Vaz", 1, nil))
    assert.are.same({}, store)
  end)

  it("lista os confirmados em ordem alfabética", function()
    local store = {}
    A.Set(store, "ev1", "Maren Luz", 1, 1)
    A.Set(store, "ev1", "Dorvan Silva", 1, 1)
    A.Set(store, "ev1", "Victor Vaz", 0, 1)
    assert.are.same({ "Dorvan Silva", "Maren Luz" }, A.Confirmed(store, "ev1"))
    assert.are.same({}, A.Confirmed(store, "ev2"))
  end)

  it("mescla em qualquer ordem com o mesmo resultado", function()
    local a, b = {}, {}
    A.Set(a, "ev1", "Victor Vaz", 1, 100)
    A.Set(a, "ev1", "Maren Luz", 1, 50)
    A.Set(b, "ev1", "Victor Vaz", 0, 120)
    A.Set(b, "ev2", "Maren Luz", 1, 60)
    local ab, ba = addon.Copy(a), addon.Copy(b)
    assert.are.equal(2, A.Merge(ab, b))
    A.Merge(ba, a)
    assert.are.same(ab, ba)
    assert.are.equal(0, A.Merge(ab, b)) -- de novo: nada muda
  end)

  it("apaga respostas de eventos que o addon não tem e filtra eventos", function()
    local store = {}
    A.Set(store, "ev1", "Victor Vaz", 1, 1)
    A.Set(store, "ev2", "Victor Vaz", 1, 1)
    A.Prune(store, { ev1 = {} })
    assert.is_nil(store.ev2)
    assert.are.same({}, A.Select(store, function() return false end))
    assert.are.same(store, A.Select(store, function() return true end))
  end)
end)
