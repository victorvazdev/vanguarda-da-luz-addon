local addon = require("helpers.addon")

describe("Lista de membros", function()
  local ns, Roster

  before_each(function()
    ns = addon.Load()
    Roster = ns.Roster
  end)

  local ENTRIES = {
    { name = "bia", rank = "Escudeiro", rankIndex = 4, level = 20, zone = "Pantanal", online = true },
    { name = "Ana", rank = "Lorde", rankIndex = 1, level = 30, zone = "Vale", online = false },
    { name = "Caio", rank = "Grão Lorde", rankIndex = 0, level = 25, zone = "", online = true },
    { name = "Davi", rank = "Lorde", rankIndex = 1, level = 25, online = true },
  }
  local STORE = { Ana = { t = 1, i = 200, m = "Ana" }, bia = { t = 1, i = 150, m = "Ana" }, Davi = { t = 1, i = 90 } }

  local function Names(rows)
    local names = {}
    for i, row in ipairs(rows) do names[i] = row.name end
    return names
  end

  it("junta o roster com item level e main", function()
    local rows = Roster.BuildRows(ENTRIES, STORE)
    assert.are.equal(4, #rows)
    assert.are.equal(200, rows[2].ilvl)
    assert.are.equal("Main", Roster.MainText(rows[2]))
    assert.are.equal("Alt de Ana", Roster.MainText(rows[1]))
    assert.is_nil(Roster.MainText(rows[4]))
    assert.is_nil(rows[3].ilvl)
  end)

  it("ordena por online, posto, nível decrescente e nome por padrão", function()
    local rows = Roster.Sort(Roster.BuildRows(ENTRIES, STORE))
    assert.are.same({ "Caio", "Davi", "bia", "Ana" }, Names(rows))
    local sameRank = {
      { name = "Bruno", rankIndex = 4, level = 20, online = true },
      { name = "Alice", rankIndex = 4, level = 20, online = true },
      { name = "Carla", rankIndex = 4, level = 34, online = true },
    }
    assert.are.same({ "Carla", "Alice", "Bruno" }, Names(Roster.Sort(Roster.BuildRows(sameRank, {}))))
  end)

  it("ordena por coluna, com quem não tem valor no fim", function()
    local rows = Roster.BuildRows(ENTRIES, STORE)
    assert.are.same({ "Davi", "bia", "Ana", "Caio" }, Names(Roster.Sort(rows, "ilvl")))
    assert.are.same({ "Ana", "bia", "Davi", "Caio" }, Names(Roster.Sort(rows, "ilvl", true)))
    assert.are.same({ "bia", "Caio", "Davi", "Ana" }, Names(Roster.Sort(rows, "level")))
    assert.are.same({ "Ana", "bia", "Caio", "Davi" }, Names(Roster.Sort(rows, "name")))
    assert.are.same({ "Caio", "Ana", "Davi", "bia" }, Names(Roster.Sort(rows, "rank")))
    assert.are.same({ "bia", "Ana", "Caio", "Davi" }, Names(Roster.Sort(rows, "main")))
    assert.are.same({ "bia", "Ana", "Caio", "Davi" }, Names(Roster.Sort(rows, "zone")))
  end)

  it("mostra o tempo da pessoa (main com alts) e ordena por ele", function()
    local rows = Roster.BuildRows(ENTRIES, STORE, { Ana = 500, Davi = 90 })
    assert.are.equal(500, rows[1].together) -- bia é alt de Ana
    assert.are.equal(500, rows[2].together)
    assert.is_nil(rows[3].together)
    assert.are.same({ "Ana", "bia", "Davi", "Caio" }, Names(Roster.Sort(rows, "time", true)))
  end)

    it("filtra só online", function()
    local rows = Roster.BuildRows(ENTRIES, STORE)
    assert.are.equal(3, #Roster.Filter(rows, { onlineOnly = true }))
    assert.are.equal(4, #Roster.Filter(rows, {}))
  end)
end)
