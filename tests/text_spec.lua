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

  it("conta caracteres UTF-8", function()
    assert.are.equal(0, Text.Length(""))
    assert.are.equal(5, Text.Length("Ação!"))
    assert.are.equal(1, Text.Length("…"))
  end)
  it("encontra links no texto", function()
    local text = "Site: https://vanguarda-da-luz.web.app\n\nDiscord (www.discord.gg/abc). Fim http://x.y/a?b=1."
    local links = Text.FindLinks(text)
    assert.are.equal(3, #links)
    assert.are.equal("https://vanguarda-da-luz.web.app", links[1].url)
    assert.are.equal("www.discord.gg/abc", links[2].url)
    assert.are.equal("http://x.y/a?b=1", links[3].url)
    assert.are.equal("https://vanguarda-da-luz.web.app", text:sub(links[1].first, links[1].last))
    assert.are.same({}, Text.FindLinks("sem links aqui, nem www. sozinho"))
    assert.are.equal(1, #Text.FindLinks("HTTPS://A.B"))
  end)

  it("transforma os links em hyperlinks e escapa o resto", function()
    assert.are.equal("Veja |cffaabbcc|Hurl:https://a.b/c|hhttps://a.b/c|h|r || ok",
      Text.Linkify("Veja https://a.b/c | ok", "url", "|cffaabbcc"))
    assert.are.equal("nada || aqui", Text.Linkify("nada | aqui", "url", "|cff000000"))
  end)
end)
