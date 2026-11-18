local addon = require("helpers.addon")

describe("Mensagem de recrutamento", function()
  local ns, Recruit

  before_each(function()
    ns = addon.Load()
    Recruit = ns.Recruit
  end)

  it("limpa o texto numa linha só, sem barra vertical", function()
    assert.equals("Vanguarda da Luz / recrutando é só chamar",
      Recruit.Clean("  Vanguarda da Luz | recrutando\n\n é só chamar  "))
  end)

  it("valida vazio e o limite de 255 bytes", function()
    local text, code = Recruit.Validate("   ")
    assert.is_nil(text)
    assert.equals("empty", code)
    assert.equals(string.rep("a", 255), Recruit.Validate(string.rep("a", 255)))
    text, code = Recruit.Validate(string.rep("é", 128)) -- 256 bytes
    assert.is_nil(text)
    assert.equals("long", code)
  end)

  it("codifica e decodifica a carga", function()
    local record = { text = "Recrutando | raide às 20h", at = 1794410000, by = "Maren Forever" }
    record.text = Recruit.Clean(record.text)
    local back = Recruit.Decode(Recruit.Encode(record))
    assert.same(record, back)
    assert.is_nil(Recruit.Decode("x|Maren|oi"))
    assert.is_nil(Recruit.Decode("10|Maren|"))
    assert.is_nil(Recruit.Decode("10|Maren|a|b"))
    assert.is_nil(Recruit.Decode("10|Maren|" .. string.rep("a", 256)))
  end)

  it("fica o texto salvo por último", function()
    local current = { text = "a", at = 10, by = "Maren" }
    assert.is_true(Recruit.IsNewer(nil, current))
    assert.is_true(Recruit.IsNewer(current, { text = "b", at = 11, by = "Ana" }))
    assert.is_false(Recruit.IsNewer(current, { text = "b", at = 9, by = "Zed" }))
    assert.is_true(Recruit.IsNewer(current, { text = "b", at = 10, by = "Zed" }))
    assert.is_false(Recruit.IsNewer(current, { text = "b", at = 10, by = "Ana" }))
    assert.is_false(Recruit.IsNewer(current, current))
    assert.is_false(Recruit.IsNewer(current, nil))
  end)

  it("lista os canais e escolhe o salvo ou o primeiro", function()
    local channels = Recruit.Channels(2, "Comércio", false, 1, "Geral", false, 3, "DefesaLocal", true, 4, "", false)
    assert.same({ { id = 1, name = "Geral" }, { id = 2, name = "Comércio" } }, channels)
    assert.equals("Comércio", Recruit.PickChannel(channels, "Comércio").name)
    assert.equals("Geral", Recruit.PickChannel(channels, "Sumiu").name)
    assert.equals("Geral", Recruit.PickChannel(channels, nil).name)
    assert.is_nil(Recruit.PickChannel({}, "Geral"))
    assert.equals("Comércio", Recruit.NextChannel(channels, channels[1]).name)
    assert.equals("Geral", Recruit.NextChannel(channels, channels[2]).name)
    assert.equals("Geral", Recruit.NextChannel(channels, nil).name)
    assert.is_nil(Recruit.NextChannel({}, nil))
  end)
end)

describe("Protocolo da mensagem de recrutamento", function()
  local ns

  before_each(function()
    ns = addon.Load()
  end)

  it("monta e lê S e Z", function()
    local payload = ns.Recruit.Encode({ text = "Recrutando", at = 1794410000, by = "Maren Forever" })
    assert.same({ kind = "recruit", payload = payload }, ns.Protocol.Parse(ns.Protocol.Recruit(payload)))
    assert.same({ kind = "recruitRequest" }, ns.Protocol.Parse(ns.Protocol.RecruitRequest()))
    assert.is_nil(ns.Protocol.Parse("S|abc"))
  end)
end)
