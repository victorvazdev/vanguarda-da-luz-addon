local addon = require("helpers.addon")

describe("Time", function()
  local ns, Time, Config

  before_each(function()
    ns = addon.Load()
    Time, Config = ns.Time, ns.Config
  end)

  it("converte instantes iguais ao os.date em UTC", function()
    for _, ts in ipairs({ 0, 951782400, 1794366000, 1794614400, 1799636340, 4102444800 }) do
      local f, t = Time.Fields(ts, 0), os.date("!*t", ts)
      assert.are.same({ t.year, t.month, t.day, t.hour, t.min, t.wday },
        { f.year, f.month, f.day, f.hour, f.minute, f.weekday })
      assert.are.equal(ts, Time.FromFields(f.year, f.month, f.day, f.hour, f.minute, 0))
    end
  end)

  it("o início da janela é 00:00 em Brasília", function()
    local export = addon.Expected()
    local f = Time.Fields(export.windowStart, Config.BRASILIA_OFFSET)
    assert.are.same({ 0, 0 }, { f.hour, f.minute })
    assert.are.equal("11/11/2026 00:00", Time.FormatDateTime(export.windowStart, Config.BRASILIA_OFFSET))
  end)

  it("formata datas em português", function()
    -- 14/11/2026 às 20:00 em Brasília
    local ts = Time.FromFields(2026, 11, 14, 20, 0, Config.BRASILIA_OFFSET)
    assert.are.equal("sábado, 14 de novembro de 2026", Time.FormatLongDate(ts, Config.BRASILIA_OFFSET))
    assert.are.equal("20:00", Time.FormatClock(ts, Config.BRASILIA_OFFSET))
    assert.are.equal("23:00", Time.FormatClock(ts, 0))
  end)

  it("calcula a diferença do horário do servidor", function()
    local now = Time.FromFields(2026, 11, 14, 23, 0, 0)
    local calendar = { year = 2026, month = 11, monthDay = 14, hour = 15, minute = 0 }
    assert.are.equal(-8 * 3600, Time.ServerOffset(calendar, now + 37)) -- segundos ignorados
    calendar = { year = 2026, month = 11, monthDay = 15, hour = 0, minute = 0 }
    assert.are.equal(3600, Time.ServerOffset(calendar, now))
    assert.are.equal("UTC-8", Time.FormatOffset(-8 * 3600))
    assert.are.equal("UTC+5:30", Time.FormatOffset(5.5 * 3600))
  end)

  it("calcula meses do calendário", function()
    assert.are.equal(29, Time.DaysInMonth(2028, 2))
    assert.are.equal(28, Time.DaysInMonth(2026, 2))
    assert.are.equal(31, Time.DaysInMonth(2026, 12))
    assert.are.equal(os.date("!*t", Time.FromFields(2026, 11, 1, 0, 0, 0)).wday, Time.FirstWeekday(2026, 11))
    assert.are.same({ 2027, 1 }, { Time.AddMonths(2026, 12, 1) })
    assert.are.same({ 2025, 12 }, { Time.AddMonths(2026, 1, -1) })
  end)
end)
