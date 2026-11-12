local addon = require("helpers.addon")

describe("PresenceCodec", function()
  local ns, P, LibDeflate

  before_each(function()
    ns = addon.Load()
    P, LibDeflate = ns.PresenceCodec, ns.LibDeflate
  end)

  local function Wrap(payload)
    local data = LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(payload))
    return "VDLP1:" .. LibDeflate:Adler32(payload) .. ":" .. data
  end

  it("monta o payload na ordem do formato", function()
    local payload = P.BuildPayload({
      game = "forever", generatedAt = 1794410000, exportNumber = 1794409200,
      store = {
        evB = { ["Maren Luz"] = { s = 1, t = 1794400000 } },
        evA = { ["Victor Vaz"] = { s = 0, t = 1794400100 }, ["Dorvan Silva"] = { s = 1, t = 1794400050 } },
      },
    })
    assert.are.equal("4:VDLP1:17:forever10:179441000010:17944092001:2"
      .. "3:evA1:2" .. "12:Dorvan Silva1:110:1794400050" .. "10:Victor Vaz1:010:1794400100"
      .. "3:evB1:1" .. "9:Maren Luz1:110:1794400000", payload)
  end)

  it("ida e volta com o exemplo de docs/exemplos-addon", function()
    local expected = dofile(addon.DOCS .. "presencas-esperado.lua")
    local text = addon.Read("presencas.txt")
    assert.are.same(expected, P.Decode(text))
    assert.are.equal(ns.Text.Trim(text), P.Encode(expected))
  end)

  it("aceita acentos nos nomes", function()
    local data = { game = "forever", generatedAt = 1, exportNumber = 0,
      store = { ev = { ["Árya Ñúñez"] = { s = 1, t = 5 } } } }
    assert.are.same(data, P.Decode(P.Encode(data)))
  end)

  it("recusa strings inválidas", function()
    assert.are.same({ nil, "empty" }, { P.Decode("  ") })
    assert.are.same({ nil, "prefix" }, { P.Decode("VDL1:1:abc") })
    assert.are.same({ nil, "version" }, { P.Decode("VDLP2:1:abc") })
    local good = P.Encode({ game = "forever", generatedAt = 1, exportNumber = 0, store = {} })
    assert.are.same({ nil, "checksum" }, { P.Decode((good:gsub(":(%d+):", ":1:", 1))) })
    -- contagem de registros maior que os campos
    assert.are.same({ nil, "payload" }, { P.Decode(Wrap("4:VDLP1:17:forever1:11:01:12:ev1:2")) })
    -- campos sobrando
    assert.are.same({ nil, "payload" }, { P.Decode(Wrap("4:VDLP1:17:forever1:11:01:03:xyz")) })
    -- situação inválida e personagem repetido
    assert.are.same({ nil, "payload" }, { P.Decode(Wrap("4:VDLP1:17:forever1:11:01:12:ev1:11:A1:21:5")) })
    assert.are.same({ nil, "payload" },
      { P.Decode(Wrap("4:VDLP1:17:forever1:11:01:12:ev1:21:A1:11:51:A1:01:6")) })
  end)

  it("viaja pelo protocolo", function()
    local Protocol = ns.Protocol
    assert.are.same({ kind = "presence", eventId = "3kTq9ZcV1bWfX7rLm2Pa", status = 1, at = 1794410000 },
      Protocol.Parse(Protocol.Presence("3kTq9ZcV1bWfX7rLm2Pa", 1, 1794410000)))
    assert.are.same({ kind = "presenceRequest" }, Protocol.Parse(Protocol.PresenceRequest()))
    assert.are.same({ kind = "presenceList", encoded = "VDLP1:1:abc" },
      Protocol.Parse(Protocol.PresenceList("VDLP1:1:abc")))
    assert.is_nil(Protocol.Parse("P|ev|2|1"))
    assert.is_nil(Protocol.Parse("P|ev-1|1|1"))
    assert.is_nil(Protocol.Parse("L|lixo"))
  end)
end)
