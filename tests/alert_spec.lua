local addon = require("helpers.addon")

describe("Alert", function()
  local ns, Alert, config

  before_each(function()
    ns = addon.Load()
    Alert, config = ns.Alert, ns.Config
  end)

  it("deixa o texto em uma linha, sem barras verticais e sem espaços sobrando", function()
    assert.are.equal("Raide às 20h / entrem já", Alert.Clean("  Raide às 20h |\n entrem\t já \r\n"))
    assert.are.equal("", Alert.Clean(nil))
  end)

  it("valida o texto e o tamanho", function()
    assert.are.equal("Raide agora", Alert.Validate(" Raide agora ", config))
    assert.are.same({ nil, "empty" }, { Alert.Validate("   ", config) })
    assert.are.equal(string.rep("a", 200), Alert.Validate(string.rep("a", 200), config))
    assert.are.same({ nil, "long" }, { Alert.Validate(string.rep("a", 201), config) })
    -- 200 caracteres acentuados ocupam 400 bytes: passam do limite do chat.
    assert.are.same({ nil, "long" }, { Alert.Validate(string.rep("á", 200), config) })
    local accented = string.rep("á", 123)
    assert.are.equal(accented, Alert.Validate(accented, config))
    assert.is_true(#Alert.ChatLine(accented, config) <= Alert.CHAT_MAX_BYTES)
  end)

  it("monta a linha do chat da guilda", function()
    assert.are.equal("[Alerta] Raide agora", Alert.ChatLine("Raide agora", config))
  end)

  it("calcula a espera entre envios", function()
    assert.are.equal(0, Alert.WaitTime(nil, 100, 30))
    assert.are.equal(20, Alert.WaitTime(100, 110, 30))
    assert.are.equal(1, Alert.WaitTime(100, 129.5, 30))
    assert.are.equal(0, Alert.WaitTime(100, 130, 30))
  end)

  it("gera identificadores com o horário do servidor", function()
    assert.are.equal("1794410000042", Alert.NewId(1794410000, function() return 42 end))
  end)

  it("descarta repetidos e alertas seguidos do mesmo remetente", function()
    local state = Alert.NewState()
    assert.is_true(Alert.Accept(state, "Maren", 1, 100, 20))
    assert.are.same({ false, "duplicate" }, { Alert.Accept(state, "Dorvan", 1, 200, 20) })
    assert.are.same({ false, "interval" }, { Alert.Accept(state, "Maren", 2, 110, 20) })
    assert.is_true(Alert.Accept(state, "Dorvan", 3, 110, 20))
    assert.is_true(Alert.Accept(state, "Maren", 4, 121, 20))
  end)

  it("viaja pelo protocolo", function()
    local message = ns.Protocol.Parse(ns.Protocol.Alert("1794410000042", "Raide / agora"))
    assert.are.same({ kind = "alert", id = 1794410000042, text = "Raide / agora" }, message)
    assert.is_nil(ns.Protocol.Parse("A|12"))
    assert.is_nil(ns.Protocol.Parse("A|12|"))
  end)
end)
