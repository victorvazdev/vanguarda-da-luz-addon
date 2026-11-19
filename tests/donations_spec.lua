local addon = require("helpers.addon")

describe("Ouro doado ao banco da guilda", function()
  local ns, Donations
  local NOW = 1794410000
  local DAY, HOUR = 86400, 3600

  before_each(function()
    ns = addon.Load()
    Donations = ns.Donations
  end)

  local function Log(...)
    return { ... }
  end

  it("lê só os depósitos do registro, com o horário aproximado", function()
    local entries = Donations.FromLog(Log(
      { kind = "deposit", who = "Castiel Jeremiel", amount = 100, years = 0, months = 0, days = 11, hours = 9 },
      { kind = "withdraw", who = "Ana", amount = 500, days = 1 },
      { kind = "depositSummary", who = "", amount = 900, days = 1 },
      { kind = "deposit", who = "Ana", amount = 0, days = 1 },
      { kind = "deposit", who = "Bruno", amount = 20000, years = 1, months = 2, days = 3, hours = 4 }
    ), NOW)
    assert.are.same({
      { w = "Castiel Jeremiel", a = 100, t = NOW - 11 * DAY - 9 * HOUR },
      { w = "Bruno", a = 20000, t = NOW - (365 + 60 + 3) * DAY - 4 * HOUR },
    }, entries)
  end)

  it("não repete o mesmo depósito em leituras diferentes", function()
    local store = {}
    local first = Donations.FromLog(Log({ kind = "deposit", who = "Ana", amount = 100, days = 2, hours = 3 }), NOW)
    assert.are.equal(1, #Donations.Absorb(store, first))
    -- uma hora depois o registro mostra "há 2 dias e 4 horas" (ou ainda 3)
    for _, hours in ipairs({ 3, 4 }) do
      local again = Donations.FromLog(Log({ kind = "deposit", who = "Ana", amount = 100, days = 2, hours = hours }),
        NOW + HOUR)
      assert.are.equal(0, #Donations.Absorb(store, again))
    end
    assert.are.equal(1, #store)
    -- outro valor, outra pessoa ou outro dia são depósitos novos
    local other = Donations.FromLog(Log(
      { kind = "deposit", who = "Ana", amount = 200, days = 2, hours = 3 },
      { kind = "deposit", who = "Bruno", amount = 100, days = 2, hours = 3 },
      { kind = "deposit", who = "Ana", amount = 100, days = 5 }
    ), NOW)
    assert.are.equal(3, #Donations.Absorb(store, other))
    assert.are.equal(4, #store)
  end)

  it("conta duas doações iguais na mesma hora", function()
    local store = {}
    local one = Log({ kind = "deposit", who = "Ana", amount = 100, hours = 1 })
    Donations.Absorb(store, Donations.FromLog(one, NOW))
    local two = Log({ kind = "deposit", who = "Ana", amount = 100, hours = 1 },
      { kind = "deposit", who = "Ana", amount = 100, hours = 1 })
    assert.are.equal(1, #Donations.Absorb(store, Donations.FromLog(two, NOW)))
    assert.are.equal(0, #Donations.Absorb(store, Donations.FromLog(two, NOW + 1800)))
    assert.are.equal(2, #store)
  end)

  it("codifica e decodifica a lista e recusa dados ruins", function()
    local entries = { { w = "Castiel Jeremiel", a = 100, t = NOW }, { w = "Ana", a = 12345678, t = NOW - DAY } }
    assert.are.same(entries, Donations.Decode(Donations.Encode(entries)))
    assert.are.same({}, Donations.Decode(Donations.Encode({})))
    assert.is_nil(Donations.Decode("1:13:Ana1:0"))
    assert.is_nil(Donations.Decode("lixo"))
    -- a lista recebida passa pela mesma regra
    local store = {}
    Donations.Absorb(store, entries)
    assert.are.equal(0, #Donations.Absorb(store, Donations.Decode(Donations.Encode(entries))))
  end)

  it("compara rápido mesmo com um registro grande", function()
    -- 5.000 depósitos de 50 pessoas com valores variados, recebidos de novo
    -- inteiros (como na resposta a um pedido): nenhum entra, sem demorar
    local store, list = {}, {}
    for i = 1, 5000 do
      list[i] = { w = "Membro " .. (i % 50), a = 100 * (i % 37 + 1), t = NOW - i * HOUR }
    end
    assert.are.equal(5000, #Donations.Absorb(store, list))
    local started = os.clock()
    assert.are.equal(0, #Donations.Absorb(store, Donations.Decode(Donations.Encode(list))))
    assert.is_true(os.clock() - started < 0.5)
    assert.are.equal(5000, #store)
  end)

  it("apaga os depósitos de quem saiu da guilda", function()
    local store = { { w = "Ana", a = 1, t = 1 }, { w = "Saiu", a = 2, t = 2 }, { w = "Bruno", a = 3, t = 3 },
      { w = "Saiu", a = 4, t = 4 } }
    Donations.Prune(store, { Ana = true, Bruno = true })
    assert.are.same({ { w = "Ana", a = 1, t = 1 }, { w = "Bruno", a = 3, t = 3 } }, store)
  end)

  it("soma por pessoa, com os alts no main, e ordena", function()
    local store = { { w = "Ana", a = 100, t = 1 }, { w = "AnaAlt", a = 50, t = 2 }, { w = "Bruno", a = 120, t = 3 } }
    local totals = Donations.Totals(store, { AnaAlt = { i = 200, m = "Ana" } })
    assert.are.same({ Ana = 150, Bruno = 120 }, totals)
    assert.are.same({ { name = "Ana", amount = 150 }, { name = "Bruno", amount = 120 } }, Donations.Ranking(totals, 5))
  end)
end)
