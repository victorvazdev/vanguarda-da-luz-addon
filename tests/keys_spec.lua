local addon = require("helpers.addon")

describe("Atalho de teclado", function()
  local Keys

  before_each(function()
    Keys = addon.Load().Keys
  end)

  it("monta a combinação no formato do jogo", function()
    assert.are.equal("V", Keys.Build("V", {}))
    assert.are.equal("SHIFT-V", Keys.Build("V", { shift = true }))
    assert.are.equal("ALT-CTRL-SHIFT-F7", Keys.Build("F7", { shift = true, alt = true, ctrl = true }))
    assert.are.equal("META-K", Keys.Build("K", { meta = true }))
  end)

  it("espera a tecla quando só o modificador foi apertado", function()
    assert.is_true(Keys.IsModifier("LSHIFT"))
    assert.is_nil(Keys.Build("LSHIFT", { shift = true }))
    assert.is_nil(Keys.Build("RCTRL", { ctrl = true }))
  end)

  it("recusa teclas que não servem de atalho", function()
    assert.is_nil(Keys.Build("ESCAPE", {}))
    assert.is_nil(Keys.Build("UNKNOWN", {}))
    assert.is_nil(Keys.Build("", {}))
    assert.is_nil(Keys.Build(nil, {}))
  end)

  it("valida a combinação salva", function()
    assert.is_true(Keys.IsValid("SHIFT-V"))
    assert.is_true(Keys.IsValid("ALT-CTRL-SHIFT-F7"))
    assert.is_true(Keys.IsValid("MINUS"))
    assert.is_false(Keys.IsValid("SHIFT-"))
    assert.is_false(Keys.IsValid("SHIFT-LSHIFT"))
    assert.is_false(Keys.IsValid("CTRL-ALT-V"))
    assert.is_false(Keys.IsValid("ESCAPE"))
    assert.is_false(Keys.IsValid(42))
  end)
end)
