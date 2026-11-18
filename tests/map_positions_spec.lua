local addon = require("helpers.addon")

describe("Posições no mapa", function()
  local ns, MapPositions, config

  before_each(function()
    ns = addon.Load()
    MapPositions = ns.MapPositions
    config = ns.Config
  end)

  it("codifica e decodifica a posição com 4 casas", function()
    local payload = MapPositions.Encode(1429, 0.41237, 0.6, true)
    assert.are.equal("1429|4124|6000|1", payload)
    assert.are.same({ map = 1429, x = 0.4124, y = 0.6, taxi = true }, MapPositions.Decode(payload))
    assert.are.same({ map = 12, x = 0, y = 1, taxi = false }, MapPositions.Decode("12|0|10000|0"))
  end)

  it("recusa posições inválidas", function()
    assert.is_nil(MapPositions.Encode(nil, 0.5, 0.5))
    assert.is_nil(MapPositions.Encode(0, 0.5, 0.5))
    assert.is_nil(MapPositions.Encode(12.5, 0.5, 0.5))
    assert.is_nil(MapPositions.Encode(12, 1.2, 0.5))
    assert.is_nil(MapPositions.Encode(12, 0, 0)) -- o jogo dá 0,0 quando não sabe
    for _, bad in ipairs({ "", "12|1|2", "0|1|2|0", "12|10001|5|0", "12|5|5|2", "x|1|2|0", "12|-1|2|0" }) do
      assert.is_nil(MapPositions.Decode(bad), bad)
    end
    assert.is_nil(MapPositions.Decode(nil))
  end)

  it("a mensagem W passa pelo protocolo", function()
    local message = ns.Protocol.Parse(ns.Protocol.Position("1429|4124|6000|0"))
    assert.are.same({ kind = "position", payload = "1429|4124|6000|0" }, message)
    assert.is_nil(ns.Protocol.Parse("W|"))
  end)

  it("envia ao andar, mudar de mapa ou de voo, e parado só de tempos em tempos", function()
    local here = { map = 1, x = 0.5, y = 0.5, taxi = false }
    assert.is_true(MapPositions.ShouldSend(nil, here, 0, config))
    assert.is_false(MapPositions.ShouldSend(nil, nil, 0, config))
    local last = { map = 1, x = 0.5, y = 0.5, taxi = false, time = 100 }
    assert.is_false(MapPositions.ShouldSend(last, here, 105, config))
    assert.is_false(MapPositions.ShouldSend(last, { map = 1, x = 0.501, y = 0.5, taxi = false }, 105, config))
    assert.is_true(MapPositions.ShouldSend(last, { map = 1, x = 0.502, y = 0.5, taxi = false }, 105, config))
    assert.is_true(MapPositions.ShouldSend(last, { map = 2, x = 0.5, y = 0.5, taxi = false }, 105, config))
    assert.is_true(MapPositions.ShouldSend(last, { map = 1, x = 0.5, y = 0.5, taxi = true }, 105, config))
    assert.is_true(MapPositions.ShouldSend(last, here, 100 + config.MAP_HEARTBEAT, config))
  end)

  it("guarda e expira as posições recebidas", function()
    local store = {}
    MapPositions.Set(store, "Ana Clara", { map = 1, x = 0.1, y = 0.2, taxi = false }, 10)
    MapPositions.Set(store, "Maren", { map = 1, x = 0.3, y = 0.4, taxi = true }, 50)
    assert.are.same({ map = 1, x = 0.1, y = 0.2, taxi = false, time = 10 }, store["Ana Clara"])
    assert.are.equal(1, MapPositions.Prune(store, 100, config.MAP_EXPIRE))
    assert.is_nil(store["Ana Clara"])
    assert.is_not_nil(store.Maren)
  end)

  it("leva a posição da zona para o continente e para o bairro", function()
    -- Zona 10 ocupa x 0.2–0.6 e y 0.5–0.7 do continente 1; o bairro 20 ocupa
    -- a metade esquerda e de cima da zona 10.
    local rects = { ["10>1"] = { 0.2, 0.6, 0.5, 0.7 }, ["20>10"] = { 0, 0.5, 0, 0.5 } }
    local function rectOf(a, b)
      local r = rects[a .. ">" .. b]
      if r then return r[1], r[2], r[3], r[4] end
    end
    local pos = { map = 10, x = 0.25, y = 0.5 }
    assert.are.same({ 0.25, 0.5 }, { MapPositions.ToMap(pos, 10, rectOf) })
    local x, y = MapPositions.ToMap(pos, 1, rectOf)
    assert.are.near(0.3, x, 1e-9)
    assert.are.near(0.6, y, 1e-9)
    x, y = MapPositions.ToMap(pos, 20, rectOf)
    assert.are.near(0.5, x, 1e-9)
    assert.are.near(1, y, 1e-9)
    assert.is_nil(MapPositions.ToMap({ map = 10, x = 0.75, y = 0.25 }, 20, rectOf)) -- fora do bairro
    assert.is_nil(MapPositions.ToMap(pos, 99, rectOf)) -- outro continente
  end)
end)
