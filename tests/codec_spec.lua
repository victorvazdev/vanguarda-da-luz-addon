local addon = require("helpers.addon")

describe("Codec", function()
  local ns, Codec, LibDeflate

  before_each(function()
    ns = addon.Load()
    Codec, LibDeflate = ns.Codec, ns.LibDeflate
  end)

  -- Monta uma string com um payload qualquer (para testar payloads inválidos).
  local function Wrap(payload, version)
    local data = LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(payload))
    return "VDL" .. (version or "1") .. ":" .. LibDeflate:Adler32(payload) .. ":" .. data
  end

  describe("ReadFields", function()
    it("lê os campos de payload.txt", function()
      local fields = Codec.ReadFields(addon.Read("payload.txt"))
      assert.are.equal(7 + 3 * 7, #fields)
      assert.are.equal("VDL", fields[1])
      assert.are.equal("forever", fields[3])
      assert.are.equal("Raid: Núcleo Derretido", fields[9])
      assert.are.equal("Masmorras em grupo | Iniciantes", fields[16])
    end)

    it("recusa tamanho maior que o restante do payload", function()
      assert.is_nil(Codec.ReadFields("3:VDL9:abc"))
    end)

    it("recusa tamanho que não é número", function()
      assert.is_nil(Codec.ReadFields("x:VDL"))
    end)
  end)

  describe("Decode", function()
    it("decodifica valida.txt igual a esperado.lua", function()
      assert.are.same(addon.Expected(), Codec.Decode(addon.Read("valida.txt")))
    end)

    it("ignora espaços e quebras de linha nas pontas", function()
      local text = "  \n" .. addon.Read("valida.txt") .. "\r\n  "
      assert.are.same(addon.Expected(), Codec.Decode(text))
    end)

    it("recusa a string corrompida (cortada)", function()
      local result, code = Codec.Decode(addon.Read("corrompida.txt"))
      assert.is_nil(result)
      assert.are.equal("compression", code)
    end)

    it("recusa string vazia", function()
      assert.are.same({ nil, "empty" }, { Codec.Decode("  \n ") })
      assert.are.same({ nil, "empty" }, { Codec.Decode(nil) })
    end)

    it("recusa prefixo desconhecido", function()
      assert.are.same({ nil, "prefix" }, { Codec.Decode("ABC1:123:abc") })
    end)

    it("recusa versão do formato desconhecida", function()
      local text = string.gsub(addon.Read("valida.txt"), "^VDL1:", "VDL2:")
      assert.are.same({ nil, "version" }, { Codec.Decode(text) })
    end)

    it("recusa checksum diferente", function()
      local text = string.gsub(addon.Read("valida.txt"), "^VDL1:%d+:", "VDL1:12345:")
      assert.are.same({ nil, "checksum" }, { Codec.Decode(text) })
    end)

    it("recusa caracteres fora do alfabeto", function()
      assert.are.same({ nil, "encoding" }, { Codec.Decode("VDL1:1:abc$def") })
    end)

    it("recusa string maior que o limite", function()
      local text = ns.Text.Trim(addon.Read("valida.txt"))
      assert.are.same({ nil, "size" }, { Codec.Decode(text, #text - 1) })
      assert.is_table(Codec.Decode(text, #text))
    end)

    it("recusa quantidade de campos diferente de 7 + 7 x count", function()
      local payload = "3:VDL1:17:forever1:11:11:21:1"
      assert.are.same({ nil, "payload" }, { Codec.Decode(Wrap(payload)) })
    end)

    it("recusa versão diferente no cabeçalho", function()
      local payload = "3:VDL1:27:forever1:11:11:21:0"
      assert.are.same({ nil, "version" }, { Codec.Decode(Wrap(payload)) })
    end)

    it("recusa situação desconhecida", function()
      local export = addon.Expected()
      export.events[1].status = "adiado"
      assert.are.same({ nil, "payload" }, { Codec.Decode(Codec.Encode(export)) })
    end)

    it("recusa IDs repetidos", function()
      local export = addon.Expected()
      export.events[2].id = export.events[1].id
      assert.are.same({ nil, "payload" }, { Codec.Decode(Codec.Encode(export)) })
    end)

    it("recusa janela vazia", function()
      local export = addon.Expected()
      export.windowEnd = export.windowStart
      assert.are.same({ nil, "payload" }, { Codec.Decode(Codec.Encode(export)) })
    end)

    it("aceita exportação sem eventos", function()
      local export = addon.Expected()
      export.events, export.count = {}, 0
      assert.are.same(export, Codec.Decode(Codec.Encode(export)))
    end)
  end)

  describe("Encode", function()
    it("gera o mesmo payload de payload.txt", function()
      assert.are.equal(addon.Read("payload.txt"), Codec.BuildPayload(addon.Expected()))
    end)

    it("ida e volta", function()
      local export = addon.Expected()
      assert.are.same(export, Codec.Decode(Codec.Encode(export)))
    end)

    it("aceita strings de até 30.000 caracteres", function()
      -- Descrições pseudoaleatórias comprimem mal e deixam a string grande.
      local seed = 7
      local function Random()
        seed = (seed * 16807) % 2147483647
        return seed
      end
      local alphabet = "abcdefghijklmnopqrstuvwxyzáéíóúãõç ABCDEFGHIJ0123456789:|\n\""
      local export = addon.Expected()
      export.events = {}
      local text
      for i = 1, 200 do
        local chars = {}
        for c = 1, 300 do
          local p = Random() % #alphabet + 1
          chars[c] = string.sub(alphabet, p, p)
        end
        export.events[i] = {
          id = string.format("evt%017d", i), title = "Evento " .. i,
          startsAt = export.windowStart + i * 3600, description = table.concat(chars),
          organizer = "Maren", status = "ativo", updatedAt = export.exportNumber - i,
        }
        export.count = i
        local candidate = Codec.Encode(export)
        if #candidate > ns.Config.MAX_STRING_LENGTH then break end
        text = candidate
      end
      assert.is_true(#text > 28000)
      local decoded = Codec.Decode(text, ns.Config.MAX_STRING_LENGTH)
      assert.is_table(decoded)
      assert.are.equal(#decoded.events, decoded.count)
    end)
  end)
end)
