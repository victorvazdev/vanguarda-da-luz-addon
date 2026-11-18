local addon = require("helpers.addon")

describe("Lembrete antes do evento", function()
  local ns, Reminders
  local now = 1794410000
  local lead = 15 * 60

  local function Event(id, minutes, status)
    return { id = id, title = id, startsAt = now + minutes * 60, status = status or "ativo" }
  end

  before_each(function()
    ns = addon.Load()
    Reminders = ns.Reminders
  end)

  it("lembra só eventos ativos e confirmados que começam em até 15 min", function()
    local events = {
      a = Event("a", 10), b = Event("b", 5), cedo = Event("cedo", 16), passou = Event("passou", -1),
      cancelado = Event("cancelado", 5, "cancelado"), nao = Event("nao", 5),
    }
    local function confirmed(id) return id ~= "nao" end
    local due = Reminders.Due(events, confirmed, {}, now, lead)
    assert.equals(2, #due)
    assert.equals("b", due[1].id)
    assert.equals("a", due[2].id)
  end)

  it("não repete o lembrete, a não ser que o horário mude", function()
    local events = { a = Event("a", 10) }
    local reminded = { a = events.a.startsAt }
    assert.equals(0, #Reminders.Due(events, function() return true end, reminded, now, lead))
    events.a.startsAt = events.a.startsAt + 60
    assert.equals(1, #Reminders.Due(events, function() return true end, reminded, now, lead))
  end)

  it("conta os minutos que faltam e esquece eventos que já começaram", function()
    assert.equals(10, Reminders.MinutesLeft(Event("a", 10), now))
    assert.equals(1, Reminders.MinutesLeft({ startsAt = now + 20 }, now))
    local reminded = { a = now - 1, b = now + 600, sumiu = now + 600 }
    Reminders.Prune(reminded, { a = {}, b = {} }, now)
    assert.same({ b = now + 600 }, reminded)
  end)
end)

describe("Última entrada do membro", function()
  local ns

  before_each(function()
    ns = addon.Load()
  end)

  it("mostra horas, dias, meses ou mais de um ano", function()
    local LastSeen = ns.Roster.LastSeen
    assert.equals("há menos de 1 h", LastSeen(0))
    assert.equals("há 5 h", LastSeen(5))
    assert.equals("há 3 d", LastSeen(3 * 24 + 2))
    assert.equals("há 2 mês(es)", LastSeen(65 * 24))
    assert.equals("há mais de 1 ano", LastSeen(400 * 24))
    assert.is_nil(LastSeen(nil))
  end)
end)
