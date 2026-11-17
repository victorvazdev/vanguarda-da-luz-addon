local addon = require("helpers.addon")

describe("BackupCodec", function()
  local ns, B, LibDeflate

  before_each(function()
    ns = addon.Load()
    B, LibDeflate = ns.BackupCodec, ns.LibDeflate
  end)

  local function Wrap(payload)
    local data = LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(payload))
    return "VDLB1:" .. LibDeflate:Adler32(payload) .. ":" .. data
  end

  local function Empty()
    return { game = "forever", generatedAt = 10, exportNumber = 0, generatedBy = "Victor Vaz", events = {},
      attendance = {}, professions = {}, members = {}, together = {} }
  end

  it("ida e volta com o exemplo de docs/exemplos-addon", function()
    local expected = dofile(addon.DOCS .. "backup-esperado.lua")
    local text = addon.Read("backup.txt")
    assert.are.same(expected, B.Decode(text))
    assert.are.equal(ns.Text.Trim(text), B.Encode(expected))
    assert.are.equal(addon.Read("backup-payload.txt"), B.BuildPayload(expected))
  end)

  it("monta o payload vazio na ordem do formato", function()
    assert.are.equal("4:VDLB1:17:forever2:101:010:Victor Vaz1:01:01:01:01:0", B.BuildPayload(Empty()))
    assert.are.same(Empty(), B.Decode(B.Encode(Empty())))
  end)

  it("conta os itens de cada seção", function()
    local data = B.Decode(addon.Read("backup.txt"))
    assert.are.same({ events = 2, attendance = 3, professions = 3, members = 3, together = 2 }, B.Counts(data))
  end)

  it("recusa prefixo, versão, checksum e conteúdo inválidos", function()
    local text = ns.Text.Trim(addon.Read("backup.txt"))
    assert.are.same({ nil, "empty" }, { B.Decode("  ") })
    assert.are.same({ nil, "prefix" }, { B.Decode("VDLP1:1:abc") })
    assert.are.same({ nil, "version" }, { B.Decode((string.gsub(text, "^VDLB1", "VDLB2"))) })
    assert.are.same({ nil, "checksum" }, { B.Decode((string.gsub(text, "^VDLB1:%d+", "VDLB1:1"))) })
    assert.are.same({ nil, "compression" }, { B.Decode(string.sub(text, 1, math.floor(#text * 0.6))) })
    local payload = B.BuildPayload(Empty())
    assert.are.same({ nil, "payload" }, { B.Decode(Wrap(payload .. "1:x")) })
    assert.are.same({ nil, "payload" }, { B.Decode(Wrap(string.sub(payload, 1, -5))) })
  end)

  it("recusa evento com origem ou situação desconhecida", function()
    local data = Empty()
    data.events = { { id = "abc", origin = "outro", title = "T", startsAt = 5, description = "", organizer = "O",
      status = "ativo", updatedAt = 3, by = "Victor Vaz" } }
    assert.are.same({ nil, "payload" }, { B.Decode(B.Encode(data)) })
    data.events[1].origin, data.events[1].status = "jogo", "talvez"
    assert.are.same({ nil, "payload" }, { B.Decode(B.Encode(data)) })
  end)

  it("recusa personagem repetido e terceira profissão", function()
    local data = Empty()
    local payload = B.BuildPayload(data)
    -- seção de tempo junto com o mesmo personagem duas vezes
    local twice = string.gsub(payload, "1:0$", "1:210:Victor Vaz1:510:Victor Vaz1:6")
    assert.are.same({ nil, "payload" }, { B.Decode(Wrap(twice)) })
    data.professions = { ["Victor Vaz"] = { t = 1, p = {
      { n = "A", l = 1, m = 1 }, { n = "B", l = 1, m = 1 }, { n = "C", l = 1, m = 1 } } } }
    assert.are.same({ nil, "payload" }, { B.Decode(B.Encode(data)) })
  end)
end)
