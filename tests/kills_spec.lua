local addon = require("helpers.addon")

describe("Abates honrosos", function()
  local ns, Kills

  before_each(function()
    ns = addon.Load()
    Kills = ns.Kills
  end)

  it("aceita só totais maiores", function()
    local store = {}
    assert.is_true(Kills.Set(store, "Ana", 165))
    assert.is_false(Kills.Set(store, "Ana", 100))
    assert.is_false(Kills.Set(store, "Ana", 165))
    assert.is_true(Kills.Set(store, "Ana", 170))
    assert.are.equal(170, store.Ana)
    assert.is_false(Kills.Set(store, "Ana", -1))
    assert.is_false(Kills.Set(store, "Ana|x", 10))
    assert.are.equal(1, Kills.Merge(store, { Ana = 160, Bruno = 3 }))
    assert.are.same({ Ana = 170, Bruno = 3 }, store)
  end)

  it("codifica e decodifica o próprio total e a lista", function()
    assert.are.equal(165, Kills.DecodeOwn(Kills.EncodeOwn(165)))
    assert.is_nil(Kills.DecodeOwn("lixo"))
    local store = { Ana = 170, ["Bruno Lima"] = 0 }
    assert.are.same(store, Kills.DecodeStore(Kills.EncodeStore(store)))
    assert.is_nil(Kills.DecodeStore("2:1:3:Ana"))
  end)

  it("soma os alts no main e ordena o ranking", function()
    local store = { Ana = 100, AnaAlt = 50, Bruno = 120, Caio = 0 }
    local members = { AnaAlt = { i = 200, m = "Ana" } }
    local totals = Kills.Totals(store, members)
    assert.are.same({ Ana = 150, Bruno = 120, Caio = 0 }, totals)
    assert.are.same({ { name = "Ana", kills = 150 }, { name = "Bruno", kills = 120 } }, Kills.Ranking(totals, 10))
    assert.are.same({ { name = "Ana", kills = 150 } }, Kills.Ranking(totals, 1))
  end)
end)
