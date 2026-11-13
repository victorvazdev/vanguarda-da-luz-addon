local addon = require("helpers.addon")

describe("Tempo de jogo com a guilda", function()
  local ns, Together

  before_each(function()
    ns = addon.Load()
    Together = ns.Together
  end)

  it("conta só junto de alguém da guilda, na mesma zona e sem ausentes", function()
    local me = { afk = false, zone = "Pantanal" }
    local mate = { guild = true, connected = true, afk = false, zone = "Pantanal" }
    assert.is_true(Together.Counts(me, { mate }))
    assert.is_false(Together.Counts(me, {}))
    assert.is_false(Together.Counts({ afk = true, zone = "Pantanal" }, { mate }))
    assert.is_false(Together.Counts(me, { { guild = false, connected = true, zone = "Pantanal" } }))
    assert.is_false(Together.Counts(me, { { guild = true, connected = false, zone = "Pantanal" } }))
    assert.is_false(Together.Counts(me, { { guild = true, connected = true, afk = true, zone = "Pantanal" } }))
    assert.is_false(Together.Counts(me, { { guild = true, connected = true, zone = "Desolação" } }))
    assert.is_false(Together.Counts({ zone = "" }, { mate }))
    assert.is_true(Together.Counts(me, { { guild = false, connected = true, zone = "Pantanal" }, mate }))
  end)

  it("soma o próprio tempo e aceita só totais maiores de outros", function()
    local store = {}
    Together.Add(store, "Ana", 60)
    Together.Add(store, "Ana", 60)
    assert.are.equal(120, store.Ana)
    assert.is_false(Together.Set(store, "Ana", 100))
    assert.is_true(Together.Set(store, "Ana", 180))
    assert.is_false(Together.Set(store, "Ana", -1))
    assert.is_false(Together.Set(store, "", 10))
    assert.are.equal(1, Together.Merge(store, { Ana = 10, Bia = 30 }))
    Together.Prune(store, { Bia = true })
    assert.are.same({ Bia = 30 }, store)
  end)

  it("codifica e decodifica", function()
    assert.are.equal(3600, Together.DecodeOwn(Together.EncodeOwn(3600)))
    assert.is_nil(Together.DecodeOwn("x"))
    assert.is_nil(Together.DecodeOwn("1:51:6"))
    local store = { ["Victor Vaz"] = 45600, Ana = 60 }
    assert.are.same(store, Together.DecodeStore(Together.EncodeStore(store)))
    assert.are.same({}, Together.DecodeStore(Together.EncodeStore({})))
    assert.is_nil(Together.DecodeStore("1:13:Ana"))
    assert.is_nil(Together.DecodeStore("1:23:Ana1:1"))
  end)

  it("soma os alts no main e monta o ranking", function()
    local members = {
      ["Evelyn Vaz"] = { t = 1, i = 1, m = "Victor Vaz" },
      ["Victor Vaz"] = { t = 1, i = 30, m = "Victor Vaz" },
    }
    local totals = Together.Totals({ ["Victor Vaz"] = 3600, ["Evelyn Vaz"] = 600, Ana = 7200, Bia = 0 }, members)
    assert.are.same({ ["Victor Vaz"] = 4200, Ana = 7200, Bia = 0 }, totals)
    assert.are.equal("Victor Vaz", Together.PersonOf("Evelyn Vaz", members))
    local ranking = Together.Ranking(totals, 5)
    assert.are.same({ { name = "Ana", seconds = 7200 }, { name = "Victor Vaz", seconds = 4200 } }, ranking)
    assert.are.equal(1, #Together.Ranking(totals, 1))
  end)

  it("formata o tempo", function()
    assert.are.equal("0min", Together.Format(0))
    assert.are.equal("35min", Together.Format(35 * 60 + 59))
    assert.are.equal("12h 40min", Together.Format(12 * 3600 + 40 * 60))
    assert.are.equal("1h 05min", Together.Format(3900))
  end)
end)
