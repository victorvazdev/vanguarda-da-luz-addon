local addon = require("helpers.addon")

-- Chaves L["..."] usadas no código (com textos concatenados por ..), mais as
-- mensagens de erro e as linhas de ajuda, que são traduzidas onde aparecem.
local function UsedKeys()
  local keys, seen = {}, {}
  local function Add(key)
    if not seen[key] then
      seen[key] = true
      keys[#keys + 1] = key
    end
  end
  local function Unescape(s) return (s:gsub('\\"', '"')) end
  local files = io.popen("find VanguardaDaLuz/core VanguardaDaLuz/logic VanguardaDaLuz/game VanguardaDaLuz/ui "
    .. "-name '*.lua'")
  for path in files:lines() do
    if not path:find("Locale.lua", 1, true) then
      local f = assert(io.open(path))
      local source = f:read("*a")
      f:close()
      local pos = 1
      while true do
        local start = source:find("%f[%w]L%[%s*\"", pos)
        if not start then break end
        -- Lê "texto" .. "texto" ... até o ], respeitando os \" dentro do texto.
        local i, parts = source:find("\"", start, true), {}
        while true do
          local j, piece = i + 1, {}
          while source:sub(j, j) ~= "\"" do
            if source:sub(j, j) == "\\" then j = j + 1 end
            piece[#piece + 1] = source:sub(j, j)
            j = j + 1
          end
          parts[#parts + 1] = table.concat(piece)
          local nextQuote = source:match("^%s*%.%.%s*()\"", j + 1)
          if not nextQuote then
            pos = j + 1
            break
          end
          i = nextQuote
        end
        Add(table.concat(parts))
      end
    end
  end
  files:close()
  for _, spec in ipairs({
    { "VanguardaDaLuz/logic/Codec.lua", "Codec%.ERRORS = (%b{})" },
    { "VanguardaDaLuz/logic/Alert.lua", "Alert%.ERRORS = (%b{})" },
    { "VanguardaDaLuz/core/Main.lua", "local HELP = (%b{})" },
  }) do
    local f = assert(io.open(spec[1]))
    local body = f:read("*a"):match(spec[2])
    f:close()
    for text in body:gmatch('"(.-[^\\])"') do Add(Unescape(text)) end
  end
  return keys, seen
end

describe("Idioma", function()
  after_each(function() _G.GetLocale = nil end)

  it("todo texto usado tem tradução para o inglês, e toda tradução é usada", function()
    local ns = addon.Load()
    local keys, used = UsedKeys()
    assert.is_true(#keys > 150)
    local missing, unused = {}, {}
    for _, key in ipairs(keys) do
      if not ns.LocaleEN[key] then missing[#missing + 1] = key end
    end
    for key in pairs(ns.LocaleEN) do
      if not used[key] then unused[#unused + 1] = key end
    end
    assert.are.same({}, missing)
    assert.are.same({}, unused)
  end)

  it("as traduções mantêm os mesmos marcadores de formato", function()
    local ns = addon.Load()
    for pt, en in pairs(ns.LocaleEN) do
      local a, b = {}, {}
      for m in pt:gmatch("%%%a") do a[#a + 1] = m end
      for m in en:gmatch("%%%a") do b[#b + 1] = m end
      assert.are.same(a, b, pt)
    end
  end)

  it("usa português no jogo em ptBR e inglês nos outros idiomas", function()
    _G.GetLocale = function() return "ptBR" end
    local pt = addon.Load()
    assert.are.equal("ptBR", pt.locale)
    assert.are.equal("Início", pt.L["Início"])
    _G.GetLocale = function() return "esES" end
    local en = addon.Load()
    assert.are.equal("enUS", en.locale)
    assert.are.equal("Home", en.L["Início"])
    assert.are.equal("texto sem tradução", en.L["texto sem tradução"])
  end)

  it("formata datas e textos das listas em inglês", function()
    _G.GetLocale = function() return "enUS" end
    local ns = addon.Load()
    local offset = ns.Config.BRASILIA_OFFSET
    local saturday = ns.Time.FromFields(2026, 11, 14, 20, 0, offset)
    assert.are.equal("Saturday, November 14, 2026", ns.Time.FormatLongDate(saturday, offset))
    assert.are.equal("2026-11-14 20:00", ns.Time.FormatDateTime(saturday, offset))
    assert.are.equal("November 2026", ns.Time.FormatMonth(2026, 11))
    assert.are.equal("Sat", ns.Time.Names().WEEKDAYS_SHORT[7])
    assert.are.equal("Alt of Ana", ns.Roster.MainText({ name = "Bia", main = "Ana" }))
    assert.are.equal("Item level 231 · Alt of Ana", ns.Members.Detail("Bia", { i = 231, m = "Ana" }))
  end)
end)
