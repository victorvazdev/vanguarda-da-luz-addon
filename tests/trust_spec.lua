local addon = require("helpers.addon")

describe("Trust", function()
  local Trust, config

  before_each(function()
    Trust = addon.Load().Trust
    config = { TRUSTED_MAX_RANK_INDEX = 1, TRUSTED_RANK_NAMES = { "Tesoureiro" } }
  end)

  it("aceita os cargos configurados", function()
    assert.is_true(Trust.IsTrustedRank(0, "Mestre", config))
    assert.is_true(Trust.IsTrustedRank(1, "Oficial", config))
    assert.is_false(Trust.IsTrustedRank(2, "Veterano", config))
    assert.is_true(Trust.IsTrustedRank(4, "Tesoureiro", config))
  end)

  it("compara nomes com e sem reino", function()
    assert.is_true(Trust.SameName("Maren", "Maren"))
    assert.is_true(Trust.SameName("Maren-Forever", "Maren"))
    assert.is_false(Trust.SameName("Maren-A", "Maren-B"))
    assert.is_false(Trust.SameName("Maren", "Dorvan"))
  end)

  it("confere o remetente no roster", function()
    local roster = {
      { name = "Maren-Forever", rankName = "Oficial", rankIndex = 1 },
      { name = "Dorvan-Forever", rankName = "Membro", rankIndex = 3 },
    }
    assert.is_true(Trust.IsTrustedSender("Maren", roster, config))
    assert.is_false(Trust.IsTrustedSender("Dorvan-Forever", roster, config))
    assert.is_nil(Trust.IsTrustedSender("Tavia", roster, config))
  end)
end)
