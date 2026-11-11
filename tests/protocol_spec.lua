local addon = require("helpers.addon")

describe("Protocol", function()
  local Protocol

  before_each(function()
    Protocol = addon.Load().Protocol
  end)

  it("monta e lê as mensagens", function()
    local raw = addon.Read("valida.txt"):gsub("%s+$", "")
    assert.are.same({ kind = "query", number = 0 }, Protocol.Parse(Protocol.Query(nil)))
    assert.are.same({ kind = "have", number = 42 }, Protocol.Parse(Protocol.Have(42)))
    assert.are.same({ kind = "data", number = 42, raw = raw }, Protocol.Parse(Protocol.Data(42, raw)))
  end)

  it("ignora mensagens inválidas", function()
    assert.is_nil(Protocol.Parse("X|1"))
    assert.is_nil(Protocol.Parse("Q|abc"))
    assert.is_nil(Protocol.Parse("Q|1|extra"))
    assert.is_nil(Protocol.Parse("D|1|nada"))
    assert.is_nil(Protocol.Parse(nil))
  end)

  it("só responde quem tem cargo aceito e dados mais novos", function()
    assert.is_true(Protocol.ShouldRespond(10, 5, true))
    assert.is_false(Protocol.ShouldRespond(10, 10, true))
    assert.is_false(Protocol.ShouldRespond(10, 5, false))
    assert.is_false(Protocol.ShouldRespond(nil, 0, true))
  end)

  it("cancela a resposta quando outro envia dados iguais ou mais novos", function()
    assert.is_true(Protocol.ShouldCancel(10, 10))
    assert.is_true(Protocol.ShouldCancel(10, 11))
    assert.is_false(Protocol.ShouldCancel(10, 9))
    assert.is_false(Protocol.ShouldCancel(nil, 9))
  end)

  it("ignora dados mais antigos ou iguais aos meus", function()
    assert.is_true(Protocol.IsNewer(11, 10))
    assert.is_false(Protocol.IsNewer(10, 10))
    assert.is_true(Protocol.IsNewer(1, nil))
  end)

  it("sorteia a espera dentro do intervalo", function()
    assert.are.equal(1, Protocol.RandomDelay(1, 6, function() return 0 end))
    assert.are.equal(6, Protocol.RandomDelay(1, 6, function() return 1 end))
  end)
end)
