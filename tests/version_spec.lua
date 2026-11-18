local addon = require("helpers.addon")

describe("Versão do addon", function()
  local ns, Version

  before_each(function()
    ns = addon.Load()
    Version = ns.Version
  end)

  it("lê versões válidas e recusa as inválidas", function()
    assert.same({ 0, 6, 0 }, Version.Parse("0.6.0"))
    assert.same({ 1, 2 }, Version.Parse("1.2"))
    assert.same({ 1, 2, 3, 4 }, Version.Parse("1.2.3.4"))
    for _, bad in ipairs({ "1", "1.2.3.4.5", "1..2", "1.2.", ".1.2", "v1.2", "1.2-beta", "", "1.10000", "?" }) do
      assert.is_nil(Version.Parse(bad), bad)
    end
    assert.is_nil(Version.Parse(nil))
    assert.is_nil(Version.Parse(string.rep("1.", 20) .. "1"))
  end)

  it("compara número por número", function()
    assert.equals(-1, Version.Compare("0.9.0", "0.10.0"))
    assert.equals(1, Version.Compare("0.10.0", "0.9.9"))
    assert.equals(0, Version.Compare("0.6", "0.6.0"))
    assert.equals(-1, Version.Compare("0.6.0", "0.6.1"))
    assert.is_nil(Version.Compare("0.6.0", "?"))
  end)

  it("diz se a versão recebida é mais nova", function()
    assert.is_true(Version.IsNewer("0.7.0", "0.6.0"))
    assert.is_false(Version.IsNewer("0.6.0", "0.6.0"))
    assert.is_false(Version.IsNewer("0.5.9", "0.6.0"))
    assert.is_false(Version.IsNewer("lixo", "0.6.0"))
    assert.is_false(Version.IsNewer("0.7.0", "?"))
  end)

  it("monta e lê a mensagem I", function()
    assert.same({ kind = "version", version = "0.6.0" }, ns.Protocol.Parse(ns.Protocol.Version("0.6.0")))
    assert.is_nil(ns.Protocol.Parse("I|"))
    assert.is_nil(ns.Protocol.Parse("I|0.6.0|x"))
  end)
end)
