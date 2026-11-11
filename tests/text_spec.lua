local addon = require("helpers.addon")

-- Confere se cada byte inicial tem a quantidade certa de continuações.
local function ValidUtf8(s)
  local i = 1
  while i <= #s do
    local b = string.byte(s, i)
    local n = b < 128 and 0 or (b >= 240 and 3) or (b >= 224 and 2) or (b >= 192 and 1) or -1
    if n < 0 then return false end
    for k = 1, n do
      local c = string.byte(s, i + k)
      if not c or c < 128 or c >= 192 then return false end
    end
    i = i + n + 1
  end
  return true
end

describe("Text", function()
  local Text

  before_each(function()
    Text = addon.Load().Text
  end)

  it("corta sem quebrar caracteres UTF-8", function()
    local s = "Poções de resistência"
    for limit = 4, #s do
      local cut = Text.Truncate(s, limit)
      assert.is_true(#cut <= limit)
      assert.is_true(ValidUtf8(cut), cut)
    end
    assert.are.equal(s, Text.Truncate(s, #s))
  end)

  it("escapa | para exibir e troca no texto do jogo", function()
    assert.are.equal("a || b", Text.Escape("a | b"))
    assert.are.equal("a / b\nc", Text.ForGame("a | b\r\nc\1"))
  end)
end)
