local addon = require("helpers.addon")

describe("Bate-papo da guilda", function()
  local Chat

  before_each(function()
    Chat = addon.Load().Chat
  end)

  it("acha os canais da guilda e de oficiais", function()
    local types = { guild = 1, officer = 2 }
    assert.are.same({ guild = 1, officer = 2 }, Chat.Streams({
      { streamId = 1, streamType = 1, name = "Guilda" },
      { streamId = 2, streamType = 2, name = "Oficial" },
    }, types))
    assert.are.same({ guild = 7 }, Chat.Streams({ { streamId = 7, streamType = 1 } }, types))
    assert.are.same({}, Chat.Streams(nil, types))
  end)

  it("monta a linha com hora, nome clicável, alt e links", function()
    local line = Chat.Line({ clock = "20:31", name = "Victor Vaz", color = "|cfff48cba", main = "Aelin Ash",
      content = "vejam https://vanguarda-da-luz.web.app | ok" }, "|cff888888", "|cff66aaff", "alt de %s")
    assert.are.equal("|cff88888820:31|r  |Hvdlplayer:Victor Vaz|h|cfff48cbaVictor Vaz|r|h"
      .. "|cff888888 (alt de Aelin Ash)|r: vejam |cff66aaff|Hvdlurl:https://vanguarda-da-luz.web.app|h"
      .. "https://vanguarda-da-luz.web.app|h|r || ok", line)
  end)

  it("mostra o texto secreto como veio", function()
    local line = Chat.Line({ clock = "1:00", name = "Ana", content = "x|y", secret = true }, "", "", "%s")
    assert.are.equal("1:00|r  Ana: x|y", line)
  end)

  it("deixa o texto protegido do histórico como veio", function()
    assert.is_true(Chat.IsProtected("|Kw774|k"))
    assert.is_false(Chat.IsProtected("oi |Kw1|k"))
    local line = Chat.Line({ clock = "9:33", name = "Fan Te", content = "|Kw784|k" }, "", "|cff66aaff", "%s")
    assert.are.equal("9:33|r  |Hvdlplayer:Fan Te|hFan Te|h: |Kw784|k", line)
    line = Chat.Line({ clock = "", name = "A", content = "a|b |Kw1|k www.x.com" }, "", "|cff1", "%s")
    assert.are.equal("|r  |Hvdlplayer:A|hA|h: a||b |Kw1|k |cff1|Hvdlurl:www.x.com|hwww.x.com|h|r", line)
  end)

  it("mostra os links do jogo recebidos como vieram", function()
    local item = "|cnIQ1:|Hitem:216483::35|h[Marreta Cascasseca]|h|r"
    local line = Chat.Line({ clock = "", name = "A", content = "teste " .. item .. " a|b" }, "", "", "%s")
    assert.are.equal("|r  |Hvdlplayer:A|hA|h: teste " .. item .. " a||b", line)
  end)

  it("mostra o link de localização do mapa e ícones", function()
    local pin = "|cffffff00|Hworldmap:1439:3264:4274|h[|A:Waypoint-MapPin-ChatIcon:13:13:0:0|a Local]|h|r"
    local line = Chat.Line({ clock = "", name = "A", content = pin .. " |T123:0|t a|b" }, "", "", "%s")
    assert.are.equal("|r  |Hvdlplayer:A|hA|h: " .. pin .. " |T123:0|t a||b", line)
    assert.are.equal("aqui " .. pin, Chat.Outgoing("aqui " .. pin))
  end)

  it("acha o texto normal da mensagem recebida ao vivo", function()
    local recent = {
      { guid = "G1", name = "Ana", time = 100, text = "primeira" },
      { guid = "G1", name = "Ana", time = 101, text = "segunda" },
      { guid = "G2", name = "Bia", time = 100, text = "da Bia" },
    }
    local used = {}
    assert.are.equal("primeira", Chat.MatchRecent(recent, "G1", "Ana", 100, 3, used))
    assert.are.equal("segunda", Chat.MatchRecent(recent, "G1", "Ana", 100, 3, used))
    assert.is_nil(Chat.MatchRecent(recent, "G1", "Ana", 100, 3, used))
    assert.are.equal("da Bia", Chat.MatchRecent(recent, nil, "Bia", 102, 3, {}))
    assert.is_nil(Chat.MatchRecent(recent, "G2", "Bia", 110, 3, {}))
  end)

  it("lê o destino dos links", function()
    assert.are.same({ "player", "Victor Vaz" }, { Chat.ParseLink("vdlplayer:Victor Vaz") })
    assert.are.same({ "url", "https://a.b/c:d" }, { Chat.ParseLink("vdlurl:https://a.b/c:d") })
    assert.is_nil(Chat.ParseLink("item:123"))
    assert.is_nil(Chat.ParseLink(nil))
  end)

  it("prepara o texto para enviar", function()
    assert.is_nil(Chat.Outgoing("   "))
    assert.is_nil(Chat.Outgoing(nil))
    assert.are.equal("oi / tudo bem", Chat.Outgoing("  oi | tudo\nbem "))
    local long = Chat.Outgoing(string.rep("á", 200))
    assert.is_true(#long <= Chat.MAX_LENGTH)
    -- links do jogo (Shift+clique) passam inteiros
    local item = "|cff0070dd|Hitem:6219::::::::30:::::|h[Chave Inglesa]|h|r"
    assert.are.equal("vendo " .. item .. " a / b", Chat.Outgoing(" vendo " .. item .. " a | b "))
    -- cor no formato novo, por nome (WoW Forever)
    local named = "|cnIQ3:|Hitem:6219::::::::30:::::|h[Chave Inglesa]|h|r"
    assert.are.equal("troco " .. named, Chat.Outgoing("troco " .. named))
    local quest = "|Hquest:123:30|h[A noiva]|h"
    assert.are.equal(quest .. " e " .. item, Chat.Outgoing(quest .. " e " .. item))
    -- link que não cabe fica de fora
    local cut = Chat.Outgoing(string.rep("a", 240) .. " " .. item)
    assert.are.equal(string.rep("a", 240), cut)
  end)
end)
