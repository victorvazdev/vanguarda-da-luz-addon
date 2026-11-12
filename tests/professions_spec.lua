local addon = require("helpers.addon")

describe("Profissões", function()
  local ns, Professions

  before_each(function()
    ns = addon.Load()
    Professions = ns.Professions
  end)

  local FERRARIA = { { n = "Ferraria", l = 88, m = 150 }, { n = "Mineração", l = 120, m = 150 } }

  it("guarda o registro mais recente de cada personagem", function()
    local store = {}
    assert.is_true(Professions.Set(store, "Victor Vaz", FERRARIA, 100))
    assert.is_false(Professions.Set(store, "Victor Vaz", { { n = "Alquimia", l = 1, m = 75 } }, 100))
    assert.is_false(Professions.Set(store, "Victor Vaz", {}, 90))
    assert.are.equal(88, store["Victor Vaz"].p[1].l)
    assert.is_true(Professions.Set(store, "Victor Vaz", {}, 101))
    assert.are.same({}, store["Victor Vaz"].p)
  end)

  it("recusa dados inválidos", function()
    local store = {}
    assert.is_false(Professions.Set(store, "", FERRARIA, 1))
    assert.is_false(Professions.Set(store, "A|B", FERRARIA, 1))
    assert.is_false(Professions.Set(store, "Ana", { {}, {}, {} }, 1))
    assert.is_false(Professions.Set(store, "Ana", { { n = "Ferraria", l = "88", m = 150 } }, 1))
    assert.is_nil(next(store))
  end)

  it("compara listas", function()
    assert.is_true(Professions.SameList(FERRARIA, addon.Copy(FERRARIA)))
    local other = addon.Copy(FERRARIA)
    other[1].l = 89
    assert.is_false(Professions.SameList(FERRARIA, other))
    assert.is_false(Professions.SameList(nil, FERRARIA))
  end)

  it("codifica e lê as profissões do remetente, com acentos", function()
    local payload = Professions.EncodeOwn(FERRARIA)
    assert.are.equal("1:28:Ferraria2:883:15011:Mineração3:1203:150", payload)
    assert.are.same(FERRARIA, Professions.DecodeOwn(payload))
    assert.are.same({}, Professions.DecodeOwn(Professions.EncodeOwn({})))
    assert.is_nil(Professions.DecodeOwn("1:3"))
    assert.is_nil(Professions.DecodeOwn(payload .. "1:x"))
    assert.is_nil(Professions.DecodeOwn("1:3" .. string.rep("8:Ferraria1:11:1", 3)))
  end)

  it("codifica, lê e mescla os níveis conhecidos", function()
    local store = {}
    Professions.Set(store, "Victor Vaz", FERRARIA, 100)
    Professions.Set(store, "Árya Ñúñez", { { n = "Alquimia", l = 30, m = 75 } }, 200)
    local decoded = Professions.DecodeStore(Professions.EncodeStore(store))
    assert.are.same(store, decoded)
    assert.is_nil(Professions.DecodeStore("2:" .. "x"))
    assert.is_nil(Professions.DecodeStore(Professions.EncodeStore(store) .. "1:1"))

    local mine = {}
    Professions.Set(mine, "Victor Vaz", { { n = "Ferraria", l = 90, m = 150 } }, 150)
    assert.are.equal(1, Professions.Merge(mine, decoded))
    assert.are.equal(90, mine["Victor Vaz"].p[1].l) -- o meu é mais recente
    assert.are.equal(30, mine["Árya Ñúñez"].p[1].l)
  end)

  it("apaga quem saiu da guilda", function()
    local store = {}
    Professions.Set(store, "Victor Vaz", FERRARIA, 1)
    Professions.Set(store, "Saiu Embora", FERRARIA, 1)
    Professions.Prune(store, { ["Victor Vaz"] = true })
    assert.is_nil(store["Saiu Embora"])
    assert.is_not_nil(store["Victor Vaz"])
  end)

  describe("lista exibida", function()
    local members = {
      { name = "Victor Vaz", online = true, professions = { "Mineração", "Ferraria" } },
      { name = "aelin Ashryvrr", online = false, professions = { "Esfolamento", "Couraria" } },
      { name = "Bruna Sol", online = true, professions = { "Ferraria" } },
      { name = "Caio Sem", online = false, professions = {} },
      { name = "Dora Nova", online = true },
    }
    local store = {}

    before_each(function()
      store = {}
      Professions.Set(store, "Victor Vaz", FERRARIA, 1)
      Professions.Set(store, "Bruna Sol", { { n = "Ferraria", l = 150, m = 150 } }, 1)
      Professions.Set(store, "Dora Nova", { { n = "Alquimia", l = 10, m = 75 } }, 1)
    end)

    it("junta as profissões da guilda com os níveis do addon", function()
      local rows = Professions.BuildRows(members, store)
      assert.are.same({ { name = "Mineração", level = 120, max = 150 }, { name = "Ferraria", level = 88, max = 150 } },
        rows[1].professions)
      assert.are.same({ name = "Esfolamento" }, rows[2].professions[1]) -- sem addon: sem nível
      assert.are.same({}, rows[4].professions)
      -- sem profissões na guilda: usa as que o addon anunciou
      assert.are.same({ { name = "Alquimia", level = 10, max = 75 } }, rows[5].professions)
      assert.is_false(rows[2].online)
    end)

    it("ordena por nome, sem diferenciar maiúsculas", function()
      local names = {}
      for i, row in ipairs(Professions.Filter(Professions.BuildRows(members, store))) do names[i] = row.name end
      assert.are.same({ "aelin Ashryvrr", "Bruna Sol", "Caio Sem", "Dora Nova", "Victor Vaz" }, names)
    end)

    it("filtra por profissão, do maior nível para o menor, e só online", function()
      local rows = Professions.BuildRows(members, store)
      local names = {}
      for i, row in ipairs(Professions.Filter(rows, { profession = "Ferraria" })) do names[i] = row.name end
      assert.are.same({ "Bruna Sol", "Victor Vaz" }, names)
      names = {}
      for i, row in ipairs(Professions.Filter(rows, { onlineOnly = true })) do names[i] = row.name end
      assert.are.same({ "Bruna Sol", "Dora Nova", "Victor Vaz" }, names)
      -- quem não informou o nível fica no fim
      local all = Professions.Filter(rows, { profession = "Esfolamento" })
      assert.are.equal("aelin Ashryvrr", all[1].name)
    end)

    it("lista as profissões para o filtro", function()
      assert.are.same({ "Alquimia", "Couraria", "Esfolamento", "Ferraria", "Mineração" },
        Professions.Names(Professions.BuildRows(members, store)))
    end)
  end)
end)
