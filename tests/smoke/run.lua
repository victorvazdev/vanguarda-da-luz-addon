-- Teste de fumaça: carrega o addon inteiro, na ordem do .toc, com uma
-- simulação mínima da API do jogo, e percorre importação, calendário do jogo
-- e sincronização. Não substitui o teste no jogo (ver README).
-- Retorna as linhas impressas e o namespace do addon.
local ROOT = "VanguardaDaLuz/"
local frames = {}
local function Mock(name)
  local o = { _scripts = {}, _shown = false, _text = "", _enabled = true, _name = name }
  return setmetatable(o, { __index = function(_, k)
    local f = ({
      SetScript = function(self, n, fn) self._scripts[n] = fn end,
      GetScript = function(self, n) return self._scripts[n] end,
      CreateFontString = function() return Mock() end,
      CreateTexture = function() return Mock() end,
      Show = function(self) self._shown = true; if self._scripts.OnShow then self._scripts.OnShow(self) end end,
      Hide = function(self)
        local was = self._shown
        self._shown = false
        if was and self._scripts.OnHide then self._scripts.OnHide(self) end
      end,
      HookScript = function(self, n, fn)
        local old = self._scripts[n]
        self._scripts[n] = function(...) if old then old(...) end fn(...) end
      end,
      SetChecked = function(self, v) self._checked = v and true or false end,
      SetAttribute = function(self, key, v) rawset(self, "_attr", rawget(self, "_attr") or {}); self._attr[key] = v end,
      SetPropagateMouseClicks = function(self, v) self._propagate = v end,
      AddMessage = function(self, text)
        rawset(self, "_lines", rawget(self, "_lines") or {})
        table.insert(self._lines, text)
      end,
      Clear = function(self) rawset(self, "_lines", {}) end,
      HasFocus = function() return false end,
      SetPoint = function(self, _, rel, _, x, y)
        if type(rel) == "table" then self._rel = rel end
        self._x, self._y = x, y
        self._moves = (rawget(self, "_moves") or 0) + 1
      end,
      CreateMaskTexture = function() return Mock() end,
      SetFrameLevel = function(self, v) self._level = v end,
      GetFrameLevel = function(self) return rawget(self, "_level") end,
      GetChecked = function(self) return self._checked end,
      IsShown = function(self) return self._shown end,
      SetShown = function(self, v) if v then self:Show() else self:Hide() end end,
      SetText = function(self, v) self._text = v end,
      GetText = function(self) return self._text end,
      IsEnabled = function(self) return self._enabled end,
      Enable = function(self) self._enabled = true end,
      Disable = function(self) self._enabled = false end,
      SetEnabled = function(self, v) self._enabled = v and true or false end,
      GetWidth = function() return 140 end,
      GetHeight = function() return 60 end,
      GetLeft = function() return 100 end,
      GetTop = function() return 500 end,
      GetStringHeight = function() return 20 end,
      GetCenter = function() return 0, 0 end,
      GetEffectiveScale = function() return 1 end,
      RegisterEvent = function(self) frames.events = self; return true end,
    })[k]
    return f or function() return nil end
  end })
end
local all = {}
_G.CreateFrame = function(_, name) local f = Mock(name); all[#all+1] = f; if name then _G[name] = f end; return f end
_G.CreateFont = function() return Mock() end
_G.UIParent, _G.Minimap, _G.GameTooltip = Mock(), Mock(), Mock()
-- Métodos fixos no minimapa: os do Mock criam uma tabela a cada chamada, e o
-- teste de memória do minimapa mede o lixo criado.
rawset(_G.Minimap, "GetWidth", function() return 140 end)
rawset(_G.Minimap, "GetHeight", function() return 60 end)
rawset(_G.Minimap, "GetFrameLevel", function() return 2 end)
_G.UISpecialFrames, _G.SlashCmdList = {}, {}
_G.Mixin = function(o) return o end
_G.BackdropTemplateMixin = {}
_G.CreateColor = function() return {} end
_G.geterrorhandler = function() return error end
_G.securecallfunction = function(f, ...) return f(...) end
local now = 1794410000
_G.GetServerTime = function() return now end
local clock = 0
_G.GetTime = function() return clock end
_G.IsInGuild = function() return true end
local inCombat = false
_G.InCombatLockdown = function() return inCombat end
-- Atalhos de teclado: os do addon ficam em `bindings`.
local bindings, shiftDown = {}, false
_G.SetOverrideBindingClick = function(_, _, key, button) bindings[key] = button end
_G.ClearOverrideBindings = function() for k in pairs(bindings) do bindings[k] = nil end end
_G.GetBindingText = function(key) return (key:gsub("SHIFT%-", "Shift-")) end
_G.GetBindingAction = function(key) return key == "SHIFT-M" and "TOGGLEWORLDMAP" or "" end
_G.BINDING_NAME_TOGGLEWORLDMAP = "Abrir mapa"
_G.IsShiftKeyDown = function() return shiftDown end
_G.IsAltKeyDown = function() return false end
_G.IsControlKeyDown = function() return false end
_G.GetGuildInfo = function() return "Vanguarda da Luz", "Lorde", 1 end
-- O nome do jogador no roster é diferente de UnitName("player").
local roster = {
  { "Maren-Forever", "Lorde", 1, [17] = "Player-2", level = 30, class = "Ladina", zone = "Pantanal",
    online = true, classFile = "ROGUE" },
  { "Tester Vaz", "Lorde", 1, [17] = "Player-1", level = 33, class = "Paladino", zone = "Desolação",
    online = true, classFile = "PALADIN" },
  { "Ana Clara", "Escudeiro", 4, level = 34, class = "Maga", zone = "Vale Gris", online = false,
    classFile = "MAGE" },
  -- Outro personagem da conta (offline), também na lista da comunidade.
  { "Aelin Ashryvrr", "Escudeiro", 4, [17] = "Player-3", level = 20, class = "Caçadora", zone = "",
    online = false, classFile = "HUNTER" },
}
_G.GetNumGuildMembers = function() return #roster end
-- Última entrada de quem está offline: 3 dias e 2 horas.
_G.GetGuildRosterLastOnline = function(i)
  if roster[i] and not roster[i].online then return 0, 0, 3, 2 end
end
-- Leituras do roster: o addon só deve ler de novo quando o roster muda.
local rosterReads = 0
_G.GetGuildRosterInfo = function(i)
  rosterReads = rosterReads + 1
  local m = roster[i]
  return m[1], m[2], m[3], m.level, m.class, m.zone, nil, nil, m.online, m.status, m.classFile,
    nil, nil, nil, nil, nil, m[17]
end
_G.RAID_CLASS_COLORS = { ROGUE = { colorStr = "fffff468" }, PALADIN = { colorStr = "fff48cba" },
  MAGE = { colorStr = "ff3fc7eb" } }
_G.UnitName = function() return "Tester" end
_G.UnitGUID = function() return "Player-1" end
_G.Ambiguate = function(n) return n end
_G.GetCursorPosition = function() return 0, 0 end
_G.Enum = { ClubMemberPresence = { Unknown = 0, Online = 1, OnlineMobile = 2, Offline = 3, Away = 4, Busy = 5 },
  TooltipDataType = { Unit = 2 }, PlayerInteractionType = { GuildBanker = 10, Banker = 8 } }
-- Banco da guilda: registro de dinheiro e pedidos ao servidor.
local moneyLog, moneyLogQueries = {}, 0
_G.MAX_GUILDBANK_TABS = 8
_G.QueryGuildBankLog = function(tab) if tab == 9 then moneyLogQueries = moneyLogQueries + 1 end end
_G.GetNumGuildBankMoneyTransactions = function() return #moneyLog end
_G.GetGuildBankMoneyTransaction = function(i) return unpack(moneyLog[i]) end
_G.GetCoinTextureString = function(copper) return "[" .. copper .. "]" end
_G.UpdateAddOnMemoryUsage = function() end
_G.GetAddOnMemoryUsage = function(name) return name == "VanguardaDaLuz" and 1234.4 or 0 end
-- Lista da guilda (C_Club): nível da profissão sempre 1, como no WoW Forever.
local club = {
  { name = "Tester Vaz", presence = 1, profession1Name = "Mineração", profession1Rank = 1,
    profession2Name = "Ferraria", profession2Rank = 1 },
  { name = "Maren-Forever", presence = 4, profession1Name = "Alquimia", profession1Rank = 1 },
  { name = "Aelin Ashryvrr", presence = 3, profession1Name = "Esfolamento", profession1Rank = 1,
    profession2Name = "Couraria", profession2Rank = 1 },
}
local officerLoaded, historyRequests, readMarks = false, {}, {}
_G.C_Club = {
  GetGuildClubId = function() return "clube" end,
  GetClubMembers = function() local ids = {} for i = 1, #club do ids[i] = i end return ids end,
  GetMemberInfo = function(_, id) return club[id] end,
  -- Bate-papo: canais da guilda e de oficiais, com o histórico carregado.
  GetStreams = function() return { { streamId = "g", streamType = 1, name = "Guilda" },
    { streamId = "o", streamType = 2, name = "Oficial" } } end,
  -- O canal de oficiais só tem histórico depois de pedido ao servidor.
  -- O da guilda vem em dois blocos, com um buraco entre eles (o bloco novo
  -- vem primeiro, para conferir a ordem).
  GetMessageRanges = function(_, stream)
    if stream == "o" and not officerLoaded then return {} end
    if stream == "o" then return { { oldestMessageId = 1, newestMessageId = 2 } } end
    return { { oldestMessageId = "novo1", newestMessageId = "novo2" }, { oldestMessageId = 1, newestMessageId = 2 } }
  end,
  -- Marcador de leitura da guilda entre as mensagens; o de oficiais, ausente.
  GetStreamViewMarker = function(_, stream) if stream == "g" then return 1794410000000000 end end,
  AdvanceStreamViewMarker = function(_, stream) readMarks[#readMarks + 1] = stream end,
  RequestMoreMessagesBefore = function(_, stream, before)
    historyRequests[#historyRequests + 1] = stream .. (before and ("<" .. before) or "")
  end,
  GetMessagesInRange = function(_, stream, oldest)
    if oldest == "novo1" then return {
      { messageId = { epoch = 1794410120000000, position = 3 }, author = { name = "Maren-Forever", guid = "Player-2" },
        content = "oi | tudo" },
    } end
    if stream == "o" then return { { messageId = { epoch = 1794410000000000, position = 1 },
      author = { name = "Maren", guid = "Player-2" }, content = "só oficiais" } } end
    return {
      { messageId = { epoch = 1794410000000000, position = 1 }, author = { name = "Tester", guid = "Player-1" },
        content = "vejam www.site.app agora" },
      { messageId = { epoch = 1794410060000000, position = 2 }, author = { name = "Ana Clara" },
        content = "mensagem-destruida-xyz", destroyed = true },
      -- texto protegido, como o histórico entrega; o jogo mostra o texto
      { messageId = { epoch = 1794409000000000, position = 4 }, author = { name = "Ana Clara" },
        content = "|Kw774|k" },
      -- protegido, mas recebido ao vivo nesta sessão: vale o texto normal
      { messageId = { epoch = now * 1000000, position = 5 }, author = { name = "Maren-Forever", guid = "Player-2" },
        content = "|Kw775|k" },
    }
  end,
}
-- Hora fixa nas linhas do chat; datas de verdade para os separadores por dia.
_G.date = function(format, ...)
  if format == "%H:%M" then return "20:33" end
  return os.date(format, ...)
end
_G.time = os.time
_G.GetProfessions = function() return 6, 8 end
_G.GetProfessionInfo = function(index)
  if index == 6 then return "Ferraria", 136241, 88, 150 end
  return "Mineração", 136248, 120, 150
end
-- Janela "Guilda e comunidades" já carregada, com os 4 botões laterais.
_G.CommunitiesFrame = Mock("CommunitiesFrame")
_G.CommunitiesFrame.GetWidth = function() return 814 end
for _, key in ipairs({ "ChatTab", "RosterTab", "GuildBenefitsTab", "GuildInfoTab", "CommunitiesList" }) do
  _G.CommunitiesFrame[key] = Mock(key)
end
-- Botões laterais de 32x32, um abaixo do outro; o 5º (idioma) tem outro nome.
local sideTabs = { "ChatTab", "RosterTab", "GuildBenefitsTab", "GuildInfoTab", "LanguageTab" }
_G.CommunitiesFrame.LanguageTab = Mock("LanguageTab")
for i, key in ipairs(sideTabs) do
  local tab = _G.CommunitiesFrame[key]
  tab._shown = true
  tab.GetObjectType = function() return "CheckButton" end
  tab.GetSize = function() return 32, 32 end
  tab.GetLeft = function() return 800 end
  tab.GetBottom = function() return 900 - i * 52 end
end
_G.CommunitiesFrame.GuildInfoTab._shown = false -- aparece ao selecionar a guilda
_G.CommunitiesFrame.GetChildren = function()
  local list = {}
  for _, key in ipairs(sideTabs) do list[#list + 1] = _G.CommunitiesFrame[key] end
  return unpack(list)
end
-- Aba Informações da Blizzard: botões "Editar" e a janela de edição.
_G.CommunitiesFrame.GuildDetailsFrame = { Info = { EditMOTDButton = Mock("EditMOTDButton"),
  EditDetailsButton = Mock("EditDetailsButton") } }
_G.CommunitiesGuildTextEditFrame = Mock("CommunitiesGuildTextEditFrame")
_G.GuildMicroButton = Mock("GuildMicroButton")
_G.CommunitiesFrame.InviteButton = Mock("InviteButton")
local canEdit = true
_G.CanEditMOTD = function() return canEdit end
_G.CanEditGuildInfo = function() return canEdit end
_G.GetGuildRosterMOTD = function() return "Raide sexta | tragam poções" end
_G.GetGuildInfoText = function() return "Site: https://vanguarda-da-luz.web.app\nDiscord: www.discord.gg/abc." end
local tells = {}
_G.ChatFrame_SendTell = function(name) tells[#tells + 1] = name end
-- Shift+clique num item chama esta função (o addon observa).
_G.ChatFrameUtil = { InsertLink = function() return false end }
local timers = {}
_G.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end, NewTicker = function() end }
_G.C_AddOns = { GetAddOnMetadata = function() return "0.1.0" end,
  IsAddOnLoaded = function(name) return name == "Blizzard_Communities" end }
-- Mapa-múndi: a tela do mapa (zoom 2) e a posição do jogador no mapa 10,
-- que fica em x 0.2–0.6 e y 0.5–0.7 do continente 1.
local mapCanvas = Mock("mapCanvas")
mapCanvas.GetScale = function() return 2 end
mapCanvas.GetFrameLevel = function() return 5 end
local shownMap = 10
_G.WorldMapFrame = Mock("WorldMapFrame")
_G.WorldMapFrame.GetCanvas = function() return mapCanvas end
_G.WorldMapFrame.GetMapID = function() return shownMap end
local myMap = { map = 10, x = 0.5, y = 0.25 }
local vectorsMade = 0 -- vetores do mapa criados (cada um custa memória no jogo)
_G.C_Map = {
  GetBestMapForUnit = function() return myMap.map end,
  GetPlayerMapPosition = function()
    if not myMap.x then return nil end
    vectorsMade = vectorsMade + 1
    return { GetXY = function() return myMap.x, myMap.y end }
  end,
  GetMapRectOnMap = function(a, b) if a == 10 and b == 1 then return 0.2, 0.6, 0.5, 0.7 end end,
  -- O mapa 10 tem 1000 x 1000 jardas; o canto de cima à esquerda fica em
  -- norte 5000, oeste 3000. O vetor traz o norte e depois o oeste.
  GetWorldPosFromMapPos = function(map, v)
    if map ~= 10 then return nil end
    vectorsMade = vectorsMade + 1
    return 0, { GetXY = function() return 5000 - v.y * 1000, 3000 - v.x * 1000 end }
  end,
}
_G.CreateVector2D = function(x, y) vectorsMade = vectorsMade + 1; return { x = x, y = y } end
-- Posição no mundo (norte, oeste, altura, instância), como no mapa 10.
local function UnitPositionMock(unit)
  if unit ~= "player" or myMap.map ~= 10 or not myMap.x then return nil end
  return 5000 - myMap.y * 1000, 3000 - myMap.x * 1000, 0, 0
end
_G.UnitPosition = UnitPositionMock
local honorKills = 165 -- abates honrosos do jogador (GetPVPLifetimeStats)
_G.GetPVPLifetimeStats = function() return honorKills, 0, 0 end
-- Minimapa: raio de 500 jardas, sem girar (a não ser que o teste mude).
local minimapRadius, cvars, facing = 500, { rotateMinimap = "0" }, 0
_G.C_Minimap = { GetViewRadius = function() return minimapRadius end }
_G.GetCVar = function(name) return cvars[name] end
_G.GetPlayerFacing = function() return facing end
_G.UnitOnTaxi = function() return false end
local canInvite = true
_G.CanGuildInvite = function() return canInvite end
_G.C_GuildInfo = {
  GuildRoster = function() end,
  GuildControlGetRankFlags = function() return { [14] = false, [17] = true } end,
}
local sent, chat = {}, {}
local lockdown = false
_G.C_ChatInfo = {
  RegisterAddonMessagePrefix = function() return 0 end,
  SendAddonMessage = function(_, m) sent[#sent + 1] = m; return 0 end,
  InChatMessagingLockdown = function() return lockdown end,
  SendChatMessage = function(m, chatType, _, target)
    chat[#chat + 1] = chatType .. (target and ("#" .. target) or "") .. " " .. m
  end,
}
local warnings, sounds = {}, 0
_G.RaidWarningFrame = Mock()
_G.RaidNotice_AddMessage = function(_, text) warnings[#warnings + 1] = text end
_G.PlaySound = function() sounds = sounds + 1 end
_G.C_DateAndTime = { GetCurrentCalendarTime = function()
  return { year = 2026, month = 11, monthDay = 12, hour = 20, minute = 33 } end }
-- O addon não usa mais o calendário do jogo: qualquer acesso falha.
_G.C_Calendar = nil
_G.ChatFrame_AddMessageEventFilter = function() end
_G.hooksecurefunc = function(t, name, fn)
  if type(t) ~= "table" then return end
  local old = t[name]
  t[name] = function(...)
    old(...)
    fn(...)
  end
end
_G.GetAverageItemLevel = function() return 27.3, 27.3125, 27 end
local tipLines = {}
_G.GameTooltip.AddLine = function(_, text) tipLines[#tipLines + 1] = text end
-- Tooltip de unidades: guarda a função do addon para o teste chamar.
local unitTooltipCalls = {}
_G.TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) unitTooltipCalls[kind] = fn end }
-- Lista de membros da janela da guilda: as linhas copiam SetMember do mixin
-- ao serem criadas, como no jogo.
local selectedClub = "clube"
_G.CommunitiesFrame.GetSelectedClubId = function() return selectedClub end
_G.CommunitiesMemberListEntryMixin = { SetMember = function(self, info) self._member = info end }
local rosterRows = {}
local function NewRosterRow()
  local row = Mock()
  row.SetMember = _G.CommunitiesMemberListEntryMixin.SetMember
  rosterRows[#rosterRows + 1] = row
  return row
end
NewRosterRow() -- linha criada antes de o addon carregar
_G.CommunitiesFrame.MemberList = Mock("MemberList")
_G.CommunitiesFrame.MemberList.ScrollBox = {
  ForEachFrame = function(_, fn) for _, row in ipairs(rosterRows) do fn(row) end end,
}
local output = {}
_G.print = function(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
  output[#output + 1] = table.concat(t, " ")
end
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.strsplit = function() end
_G.max, _G.min, _G.floor = math.max, math.min, math.floor
_G.tinsert, _G.tremove = table.insert, table.remove
_G.debugstack = function() return "" end
_G.issecretvalue = nil

local ns = {}
for line in io.lines(ROOT .. "VanguardaDaLuz_Forever.toc") do
  if not line:match("^##") and line:match("%S") then
    local path = line:gsub("\\", "/")
    local files = {}
    if path:match("%.xml$") then
      local dir = path:match("^(.*)/")
      for l in io.lines(ROOT .. path) do
        local f = l:match('Script file="([^"]+)"'); if f then files[#files + 1] = dir .. "/" .. f end
      end
    else files = { path } end
    for _, f in ipairs(files) do assert(loadfile(ROOT .. f))("VanguardaDaLuz", ns) end
  end
end

local ev = frames.events
-- SavedVariables de uma versão anterior, com a ligação ao calendário do jogo.
_G.VanguardaDaLuzDB = { schema = 1, events = {}, game = { x = { state = "done" } },
  attendance = { sumiu = { ["Maren-Forever"] = { s = 1, t = 1 } } } }
ev._scripts.OnEvent(ev, "ADDON_LOADED", "VanguardaDaLuz")
ev._scripts.OnEvent(ev, "PLAYER_ENTERING_WORLD")
SlashCmdList.VANGUARDADALUZ("")
SlashCmdList.VANGUARDADALUZ("ajuda")
SlashCmdList.VANGUARDADALUZ("importar")
local dialog = _G.VanguardaDaLuzImportDialog
local f = io.open("docs/exemplos-addon/valida.txt"); local raw = f:read("*a"); f:close()
-- Clica no botão com o texto indicado (o mais recente, se houver vários).

local function Click(label)
  for i = #all, 1, -1 do
    local b = all[i]
    if b._text == label and b._scripts.OnClick then return b._scripts.OnClick(b, "LeftButton") end
  end
  error("botão não encontrado: " .. label)
end
local function RunTimers() local list = timers; timers = {}; for _, fn in ipairs(list) do fn() end end

dialog.edit:SetText("lixo"); Click("Validar"); print("erro:", dialog.message._text)
dialog.edit:SetText(raw); Click("Validar"); print("resumo:\n" .. dialog.message._text)
print("confirm enabled:", dialog.confirm:IsEnabled())
local comms = {}
ns.Comm.SendCommMessage = function(_, prefix, msg, dist, _, prio)
  comms[#comms + 1] = prefix .. " " .. dist .. " " .. (prio or "") .. " " .. msg:sub(1, 30)
end
Click("Confirmar importação")
print("eventos salvos:", (function() local n=0 for _ in pairs(ns.db.events) do n=n+1 end return n end)())
SlashCmdList.VANGUARDADALUZ("")  -- fecha
SlashCmdList.VANGUARDADALUZ("")  -- abre de novo e renderiza
local main = _G.VanguardaDaLuzMainFrame
print("info:", main.info._text)
-- Início: mensagem do dia, informações com links e próximo evento
local home = main.panels.home
print("abre no início:", home.frame._shown, main.panels.events.frame._shown, main.tabs.admin._shown)
-- no Início do addon, o clique no texto abre a janela da guilda (botão Guilda)
local openEditor
for _, e in ipairs(ns.GuildTextEdit.editors) do if e.mode == "open" and e.kind == "info" then openEditor = e end end
print("editar pelo addon:", openEditor.button._shown, openEditor.button._attr.clickbutton == _G.GuildMicroButton,
  home.motd.hint._shown, home.motd.hint._text)
openEditor.button._scripts.PostClick(openEditor.button, "LeftButton", true)
openEditor.button._scripts.PostClick(openEditor.button, "LeftButton", false)
print("abriu a guilda:", main._shown)
main:Show()
print("mdd:", home.motd.holder.text._text)
print("info guilda:", home.info.holder.text._text)
home.info.holder._scripts.OnHyperlinkClick(home.info.holder, "vdlurl:www.discord.gg/abc", "x")
print("copiar:", home.copy._shown, home.copy.edit._text)
home.copy._scripts.OnEvent(home.copy, "GLOBAL_MOUSE_DOWN") -- clique fora da caixa
print("copiar fecha com clique fora:", home.copy._shown)
print("próximo evento:", home.nextEvent.name._text)
Click("Ver no calendário")
print("ver no calendário:", main.panels.events.frame._shown, home.frame._shown, main.dayTitle._text)
-- membro recebendo dados de um oficial
local comm = ns.Comm
ns.db.export = nil; ns.db.events = {}
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.Data(1794409200, raw:gsub("%s+$","")), "GUILD", "Maren-Forever")
print("recebido da guilda:", ns.db.export and ns.db.export.source, ns.db.export and ns.db.export.sender)
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.Query(0), "GUILD", "Dorvan")
RunTimers()
print("respondeu ao pedido; mensagens enviadas:", #sent)
-- lista de presença
local A, C = "3kTq9ZcV1bWfX7rLm2Pa", "Hq2mB8xY4nRcT0vKs9Ue"
print("presença de evento removido apagada:", ns.db.attendance.sumiu == nil)
local P = ns.Presence
print("toggle cancelado:", P.Toggle(C))
print("toggle confirma:", P.Toggle(A), P.Status(A), comms[#comms])
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.Presence(A, 1, now + 5), "GUILD", "Maren-Forever")
print("confirmados:", table.concat(P.Confirmed(A), ","))
-- seleciona o dia 13/11, do evento A, na grade do mês
ns.MainFrame.ShowTab("events")
for _, cell in ipairs(all) do
  if cell.day == 13 and cell._scripts.OnClick then cell._scripts.OnClick(cell); break end
end
print("detalhe presença:", _G.VanguardaDaLuzMainFrame.detail.attendance._text)
-- quem confirmou: um por linha, com o botão de grupo para quem está online
local people = _G.VanguardaDaLuzMainFrame.detail.people
local function Person(i)
  local r = people.rows[i]
  return table.concat({ r.name._text, r.detail._text, tostring(r.button._shown), r.button._text, r.state._text }, " | ")
end
print("confirmado 1:", Person(1))
print("confirmado 2:", Person(2))
local groupInvites = {}
local realParty = _G.C_PartyInfo
_G.C_PartyInfo = { InviteUnit = function(name) groupInvites[#groupInvites + 1] = name end }
people.rows[1].button._scripts.OnClick(people.rows[1].button)
_G.C_PartyInfo = realParty
print("convite do confirmado:", groupInvites[1])
Click("Cancelar presença")
print("depois do clique:", P.Status(A), table.concat(P.Confirmed(A), ","))
-- outro membro pede as presenças e recebe a lista
local beforeList = #comms
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.PresenceRequest(), "GUILD", "Dorvan")
RunTimers()
print("lista enviada:", #comms - beforeList, comms[#comms])
-- recebe uma lista com uma resposta mais nova de Maren
local list = ns.PresenceCodec.Encode({ game = "forever", generatedAt = now, exportNumber = 0,
  store = { [A] = { ["Maren-Forever"] = { s = 0, t = now + 50 }, ["Ana Clara"] = { s = 1, t = now + 60 } } } })
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.PresenceList(list), "GUILD", "Dorvan")
print("confirmados após lista:", table.concat(P.Confirmed(A), ","))
SlashCmdList.VANGUARDADALUZ("presencas")
local exported = ns.PresenceCodec.Decode(_G.VanguardaDaLuzPresenceExport.edit._text)
print("exportação:", exported and exported.exportNumber, exported and exported.store[A]["Tester Vaz"].s,
  _G.VanguardaDaLuzPresenceExport.summary._text)
-- evento criado no jogo (o jogador é Lorde)
_G.VanguardaDaLuzPresenceExport:Hide()
ns.MainFrame.ShowTab("events")
Click("+ Evento")
local ed = _G.VanguardaDaLuzEventDialog
print("novo evento:", ed._shown, ed.heading._text, ed.organizer._text, ed.max._text, ed.max.box._shown)
ed.title:SetText("Treino | PvP")
ed.date:SetText("40/11/2026"); Click("Salvar")
print("data inválida:", ed.message._text, ed._shown)
local day = ns.Time.Fields(now + 3 * 86400, ns.Config.BRASILIA_OFFSET)
ed.date:SetText(string.format("%02d/%02d/%04d", day.day, day.month, day.year))
ed.clock:SetText("21:30")
Click("Salvar")
local createdId
for id, e in pairs(ns.db.events) do if e.origin == "jogo" then createdId = id end end
local created = ns.db.events[createdId]
print("evento criado:", created.title, created.pending, created.max, created.guests, #createdId, ed._shown,
  comms[#comms])
print("detalhe do criado:", main.detail.organizer._text)
Click("Editar")
print("editar abre:", ed.heading._text, ed.title._text, ed.clock._text)
ed.title:SetText("Treino de PvP"); ed.max:SetText("12")
Click("Salvar")
print("evento editado:", ns.db.events[createdId].title, ns.db.events[createdId].max)
Click("Cancelar evento")
print("cancelar pede confirmação:", ns.db.events[createdId].status)
Click("Clique de novo")
print("evento cancelado:", ns.db.events[createdId].status)
Click("Excluir evento")
print("excluir pede confirmação:", ns.db.events[createdId] ~= nil)
Click("Clique de novo")
print("evento excluído:", ns.db.events[createdId] == nil, ns.db.deleted[createdId].status, comms[#comms])
-- evento do site editado no jogo: sem vagas e visitantes
for _, cell in ipairs(all) do
  if cell.day == 13 and cell._scripts.OnClick then cell._scripts.OnClick(cell); break end
end
Click("Editar")
print("editar do site:", ed.title._text, ed.max.box._shown, ed.limitsNote._shown)
ed.hide = nil; ed:Hide()
-- alterações recebidas de um Lorde e de quem não tem cargo
local function Remote(id, title)
  return ns.BackupCodec.Encode({ game = "forever", generatedAt = now, exportNumber = 0, generatedBy = "x",
    events = { { id = id, origin = "jogo", title = title, startsAt = now + 7200, description = "", organizer = "M",
      status = "ativo", updatedAt = now, max = 10, guests = true, by = "Maren-Forever" } } })
end
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.GameEvents(Remote("RemotoLorde", "De Maren")), "GUILD",
  "Maren-Forever")
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.GameEvents(Remote("RemotoMembro", "De Ana")), "GUILD",
  "Ana Clara")
print("eventos recebidos:", ns.db.events.RemotoLorde and ns.db.events.RemotoLorde.title,
  ns.db.events.RemotoMembro == nil)
local beforeEvents = #comms
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.GameEventsRequest(), "GUILD", "Ana Clara")
RunTimers()
print("eventos do jogo enviados:", #comms - beforeEvents, comms[#comms])
-- backup e restauração
Click("Gerar backup")
local be = _G.VanguardaDaLuzBackupExport
local backup = ns.BackupCodec.Decode(be.edit._text)
print("backup:", be._shown, backup and #backup.events, backup and backup.generatedBy, be.summary._text)
be:Hide()
backup.together["Ana Clara"] = 99999
backup.professions["Ana Clara"] = { t = now, p = { { n = "Costura", l = 50, m = 75, i = 197 } } }
Click("Restaurar")
local br = _G.VanguardaDaLuzBackupRestore
br.edit:SetText("VDLP1:1:abc"); Click("Validar")
print("restaurar inválido:", br.message._text, br.confirm:IsEnabled())
br.edit:SetText(ns.BackupCodec.Encode(backup)); Click("Validar")
print("restaurar válido:", br.confirm:IsEnabled(), br.message._text)
Click("Restaurar")
print("restaurado:", br._shown, ns.db.together["Ana Clara"], ns.db.professions["Ana Clara"].p[1].n)
RunTimers()
-- desfaz o restaurado, para não mudar os testes seguintes
ns.db.together["Ana Clara"], ns.db.professions["Ana Clara"] = nil, nil
-- profissões
for _, c in ipairs(comms) do
  if c:find(" F|", 1, true) then print("profissões anunciadas:", c) end
end
local Pro = ns.Professions
comm.OnCommReceived(comm, "VanguardaDaLuz",
  ns.Protocol.Professions(now + 1, Pro.EncodeOwn({ { n = "Alquimia", l = 40, m = 75 } })), "GUILD", "Maren-Forever")
SlashCmdList.VANGUARDADALUZ("profissoes")
local pframe = _G.VanguardaDaLuzProfessionsFrame
local function PrintRows(label)
  for i, row in ipairs(pframe.rows) do
    if row._shown then
      print(label, i, row.name._text, "|", row.first._text, "|", row.second._text, "|",
        row.whisper._shown and (row.whisper._enabled and "sussurrar" or "offline") or "sem botão")
    end
  end
end
local visible = 0
for _, row in ipairs(pframe.rows) do if row._shown then visible = visible + 1 end end
print("padrão profissões:", pframe.online._text, visible)
Click("Mostrar: só online") -- passa a mostrar todos
print("contagem profissões:", pframe.count._text)
PrintRows("linha")
pframe.rows[2].whisper._scripts.OnClick(pframe.rows[2].whisper)
print("sussurro para:", tells[1])
Click("Profissão: Todas"); Click("Ferraria")
PrintRows("filtro")
Click("Mostrar: todos")
print("só online:", pframe.online._text, pframe.rows[1]._shown, pframe.rows[2]._shown)
-- outro membro pede os níveis e recebe a lista
beforeList = #comms
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.ProfessionsRequest(), "GUILD", "Dorvan")
RunTimers()
print("níveis enviados:", #comms - beforeList, comms[#comms])
-- abas na janela da guilda
local cf, GT = _G.CommunitiesFrame, ns.GuildTabs
print("abas antes de abrir:", GT.tabs.events._shown)
cf:Show(); cf.GuildInfoTab:Show()
local gt = GT.tabs
print("abas da guilda:", gt.events._shown, gt.professions._shown, gt.admin._shown,
  "abaixo de", gt.events._rel and gt.events._rel._name)
-- a Blizzard esconde e mostra o botão de idioma ao trocar de modo
cf.LanguageTab:Hide(); GT.Update()
local during = gt.events._rel._name
cf.LanguageTab:Show(); RunTimers()
print("troca de modo:", during, "->", gt.events._rel._name)
cf.ChatTab:SetChecked(true)
gt.events._scripts.OnClick(gt.events)
print("aba eventos:", GT.overlay._shown, gt.events._checked, cf.ChatTab._checked)
gt.professions._scripts.OnClick(gt.professions)
print("aba profissões:", gt.professions._checked, gt.events._checked)
gt.admin._scripts.OnClick(gt.admin)
_G.VanguardaDaLuzPresenceExport:Hide()
Click("Gerar string")
print("admin abre presenças:", _G.VanguardaDaLuzPresenceExport._shown)
cf.RosterTab:SetChecked(true) -- a Blizzard marca o botão clicado
cf.RosterTab._scripts.OnClick(cf.RosterTab)
print("aba da Blizzard fecha o painel:", GT.overlay._shown, gt.admin._checked)
gt.events._scripts.OnClick(gt.events)
cf.LanguageTab._scripts.OnClick(cf.LanguageTab)
print("5º botão da Blizzard fecha o painel:", GT.overlay._shown)
cf.RosterTab:SetChecked(true)
gt.events._scripts.OnClick(gt.events)
cf.GuildInfoTab:Hide() -- outra comunidade selecionada
print("outra comunidade:", gt.events._shown, GT.overlay._shown, cf.RosterTab._checked)
cf.GuildInfoTab:Show()
-- aba Informações: o Início do addon por cima, com o botão para a original
cf.RosterTab:SetChecked(false)
cf.GuildInfoTab:SetChecked(true) -- a Blizzard marca o botão clicado
cf.GuildInfoTab._scripts.OnClick(cf.GuildInfoTab)
RunTimers()
local infoPanel = GT.panels.info
print("informações:", GT.overlay._shown, infoPanel and infoPanel.frame._shown, cf.GuildInfoTab._checked)
print("dica informações:", infoPanel.hint._text)
-- na janela da guilda as informações seguem no espaço grande e o cartão
-- Guilda só tem o ranking de tempo
local coverHome = infoPanel.inner
print("início na guilda:", coverHome.info._y, coverHome.guild._y < -150, #coverHome.guild.rankLines,
  next(coverHome.guild.rankButtons) == nil)
-- a Blizzard mostra um quadro mais alto depois de o painel abrir: o painel
-- sobe de novo (fora de combate)
local lateFrame = Mock("lateFrame")
lateFrame._shown, lateFrame._level = true, 500
lateFrame.GetFrameStrata = function() return "MEDIUM" end
sideTabs[#sideTabs + 1] = "LateFrame"
_G.CommunitiesFrame.LateFrame = lateFrame
inCombat = true
GT.overlay._scripts.OnUpdate(GT.overlay, 1)
local levelInCombat = rawget(GT.overlay, "_level")
inCombat = false
GT.overlay._scripts.OnUpdate(GT.overlay, 1)
print("painel sobe:", levelInCombat ~= 510, GT.overlay._level)
sideTabs[#sideTabs] = nil
-- clique no texto abre a edição da Blizzard por um botão seguro
local function Editor(kind, mode)
  for _, e in ipairs(ns.GuildTextEdit.editors) do if e.kind == kind and e.mode == mode then return e end end
end
local motdEditor, infoEditor = Editor("motd", "edit"), Editor("info", "edit")
print("edição:", motdEditor.button._shown, motdEditor.button._attr.type,
  motdEditor.button._attr.clickbutton == _G.CommunitiesFrame.GuildDetailsFrame.Info.EditMOTDButton,
  infoEditor.button._attr.clickbutton == _G.CommunitiesFrame.GuildDetailsFrame.Info.EditDetailsButton,
  motdEditor.holder._propagate)
infoEditor.holder._scripts.OnHyperlinkEnter(infoEditor.holder)
print("em cima do link:", infoEditor.holder._propagate)
infoEditor.holder._scripts.OnHyperlinkLeave(infoEditor.holder)
print("fora do link:", infoEditor.holder._propagate)
-- em combate o botão seguro sai do painel; ao sair do combate, volta
ns.GuildTextEdit.OnCombatStart()
print("edição em combate:", motdEditor.button._shown, motdEditor.holder._propagate)
ns.GuildTextEdit.Refresh()
print("edição depois do combate:", motdEditor.button._shown, motdEditor.holder._propagate)
canEdit = false
infoPanel:Refresh()
print("sem permissão no jogo:", motdEditor.button._shown, motdEditor.holder._propagate, infoPanel.hint._text)
canEdit = true
infoPanel:Refresh()
infoPanel.original._scripts.OnClick(infoPanel.original)
print("original da Blizzard:", GT.overlay._shown)
cf.GuildInfoTab._scripts.OnClick(cf.GuildInfoTab)
RunTimers()
print("informações de novo:", GT.overlay._shown)
-- aba Bate-papo da Blizzard: o bate-papo do addon por cima, com o botão para a original
cf.GuildInfoTab:SetChecked(false)
cf.ChatTab:SetChecked(true)
cf.ChatTab._scripts.OnClick(cf.ChatTab)
RunTimers()
local chatCover = GT.panels.chat
print("bate-papo na guilda:", GT.overlay._shown, chatCover and chatCover.frame._shown,
  #chatCover.inner.messages._lines > 0)
chatCover.original._scripts.OnClick(chatCover.original)
print("bate-papo original:", GT.overlay._shown)
cf.ChatTab._scripts.OnClick(cf.ChatTab)
RunTimers()
print("bate-papo de novo:", GT.overlay._shown)
cf.ChatTab:SetChecked(false)
cf.GuildInfoTab:SetChecked(true)
cf.GuildInfoTab._scripts.OnClick(cf.GuildInfoTab)
RunTimers()
gt.events._scripts.OnClick(gt.events)
print("eventos a partir de informações:", GT.overlay._shown, gt.events._checked, cf.GuildInfoTab._checked,
  infoPanel.frame._shown)
cf.GuildInfoTab:SetChecked(false)
cf.RosterTab:SetChecked(true)
cf.RosterTab._scripts.OnClick(cf.RosterTab)
RunTimers()
print("membros depois:", GT.overlay._shown, GT.panels.members and GT.panels.members.frame._shown)
local membersCover = GT.panels.members
local guildInvite = membersCover.inner.inviteLink
print("convite na guilda:", membersCover.inner.invite._shown, guildInvite.mode, guildInvite.button._shown,
  guildInvite.button._attr.clickbutton == _G.CommunitiesFrame.InviteButton)
selectedClub = "outro"
membersCover.inner:Refresh()
print("convite em outro clube:", guildInvite.button._shown)
selectedClub = "clube"
membersCover.inner:Refresh()
local coverRow = membersCover.inner.rows[1]
print("lista na guilda:", coverRow.name._text, "|", coverRow.rank._text, "| dica:", membersCover.hint._shown,
  "| tempo:", membersCover.inner.columns.time ~= nil, rawget(membersCover.inner.headers, "time") ~= nil)
membersCover.original._scripts.OnClick(membersCover.original)
print("membros original:", GT.overlay._shown)
cf.RosterTab._scripts.OnClick(cf.RosterTab)
RunTimers()
print("membros de novo:", GT.overlay._shown)
-- popup "é o seu main?" ao logar (conta sem main)
RunTimers()
local prompt = _G.VanguardaDaLuzMainPrompt
print("popup main:", prompt._shown, prompt.question._text)
Click("Não")
print("popup não:", prompt._shown, ns.db.settings.mainAsked["Tester Vaz"])
ns.MainPrompt.ShowIfNeeded()
print("popup de novo:", prompt._shown)
ns.db.settings.mainAsked = nil
ns.MainPrompt.ShowIfNeeded()
Click("Não perguntar mais")
ns.MainPrompt.ShowIfNeeded()
print("popup desligado:", prompt._shown, ns.db.settings.mainPromptOff)
ns.db.settings.mainPromptOff = nil
-- item level e main/alt na lista de membros
local beforeMembers = #comms
SlashCmdList.VANGUARDADALUZ("main")
print("main anunciado:", #comms - beforeMembers, comms[#comms])
comm.OnCommReceived(comm, "VanguardaDaLuz",
  ns.Protocol.Member(now, ns.Members.EncodeOwn({ i = 231, m = "Aelin Ashryvrr" })), "GUILD", "Maren-Forever")
local newRow = NewRosterRow() -- linha criada depois: gancho pelo mixin
rosterRows[1]:SetMember(club[1])
newRow:SetMember(club[2])
local GR = ns.GuildRoster
print("linhas membros:", GR.labels[rosterRows[1]]._text, "|", GR.labels[newRow]._text, "|",
  rosterRows[1]._member.name)
newRow._scripts.OnEnter(newRow)
print("tooltip membro:", tipLines[#tipLines])
selectedClub = "outra"
GR.Refresh()
print("outra comunidade sem texto:", GR.labels[newRow]._shown)
selectedClub = "clube"
ns.db.settings.main = "Aelin Ashryvrr" -- outro personagem da conta é o main
ns.GuildMembers.Announce()
GR.Refresh()
print("vira alt:", GR.labels[rosterRows[1]]._text, comms[#comms])
-- no bate-papo a lista é estreita: sem texto na linha, só no tooltip
cf.RosterTab:SetChecked(false)
cf.ChatTab:SetChecked(true)
cf.ChatTab._scripts.OnClick(cf.ChatTab)
RunTimers()
newRow._scripts.OnEnter(newRow)
print("bate-papo:", GR.labels[rosterRows[1]]._shown, tipLines[#tipLines])
cf.ChatTab:SetChecked(false)
cf.RosterTab:SetChecked(true)
cf.RosterTab._scripts.OnClick(cf.RosterTab)
RunTimers()
print("membros com texto:", GR.labels[rosterRows[1]]._shown)
beforeMembers = #comms
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.MembersRequest(), "GUILD", "Dorvan")
RunTimers()
print("membros enviados:", #comms - beforeMembers, comms[#comms])
-- tempo de jogo com a guilda: em grupo com Maren, na mesma zona
local group = { count = 2, afk = {} }
_G.GetNumGroupMembers = function() return group.count end
_G.IsInRaid = function() return false end
_G.UnitExists = function() return true end
_G.UnitIsUnit = function(a, b) return a == b end
_G.UnitIsConnected = function() return true end
_G.UnitIsAFK = function(unit) return group.afk[unit] end
_G.GetZoneText = function() return "Pantanal" end
_G.UnitGUID = function(unit) return unit == "party1" and "Player-2" or "Player-1" end
ns.GuildTogether.Tick()
local afterOne = ns.db.together["Tester Vaz"]
group.afk.party1 = true; ns.GuildTogether.Tick(); group.afk.party1 = nil
group.afk.player = true; ns.GuildTogether.Tick(); group.afk.player = nil
roster[1].status = 1; ns.Flavor.InvalidateRoster(); ns.GuildTogether.Tick() -- ausente no roster
_G.GetZoneText = function() return "Desolação" end; ns.GuildTogether.Tick()
_G.GetZoneText = function() return "Pantanal" end
group.count = 1; ns.GuildTogether.Tick(); group.count = 2
print("tempo junto:", afterOne, ns.db.together["Tester Vaz"])
ns.GuildTogether.Tick()
print("tempo junto depois:", ns.db.together["Tester Vaz"])
ns.GuildTogether.Announce()
print("tempo anunciado:", comms[#comms])
comm.OnCommReceived(comm, "VanguardaDaLuz",
  ns.Protocol.TogetherList(ns.Together.EncodeStore({ ["Ana Clara"] = 3600, ["Maren-Forever"] = 100 })),
  "GUILD", "Maren-Forever")
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.Together(ns.Together.EncodeOwn(50)), "GUILD", "Maren-Forever")
print("tempo recebido:", ns.db.together["Ana Clara"], ns.db.together["Maren-Forever"])
ns.MainFrame.Open("home")
local hp = _G.VanguardaDaLuzMainFrame.panels.home
print("ranking:", #hp.guild.rankLines, hp.guild.rankLines[1].name._text, hp.guild.rankLines[1].value._text,
  hp.guild.rankLines[2].name._text)
-- abates honrosos: lê os próprios, anuncia só quando mudam e repassa
local commsBeforeKills = #comms
local killsAtLogin = false -- anunciados no login, com os outros dados
for _, c in ipairs(comms) do if c == "VanguardaDaLuz GUILD NORMAL h|3:165" then killsAtLogin = true end end
print("abates no login:", killsAtLogin, ns.db.kills["Tester Vaz"])
ns.GuildKills.Announce()
print("abates sem mudança:", #comms - commsBeforeKills)
honorKills = 170
ev._scripts.OnEvent(ev, "PLAYER_PVP_KILLS_CHANGED")
ev._scripts.OnEvent(ev, "PLAYER_PVP_KILLS_CHANGED")
print("abate lido na hora:", ns.db.kills["Tester Vaz"], "anúncios antes da espera:", #comms - commsBeforeKills)
RunTimers()
print("abates depois da espera:", comms[#comms], #comms - commsBeforeKills)
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.Kills(ns.Kills.EncodeOwn(400)), "GUILD", "Maren-Forever")
comm.OnCommReceived(comm, "VanguardaDaLuz",
  ns.Protocol.KillsList(ns.Kills.EncodeStore({ ["Ana Clara"] = 90, ["Maren-Forever"] = 10, Fulano = 999 })),
  "GUILD", "Dorvan")
print("abates recebidos:", ns.db.kills["Maren-Forever"], ns.db.kills["Ana Clara"])
ns.MainFrame.Open("home")
print("início no addon: guilda à esquerda", hp.guild._x, hp.guild._y, "informações à direita", hp.info._x,
  hp.info._y)
local function RankingText(label)
  local rl = hp.guild.rankLines
  print(label, #rl, hp.guild.rankTitle._text, rl[1].name._text, rl[1].value._text, "|", rl[2].name._text,
    rl[2].value._text, "|", rl[3].name._text, "|", rl[4].name._text)
end
hp.guild.rankButtons.kills._scripts.OnClick(hp.guild.rankButtons.kills)
RankingText("ranking abates:")
print("botões do ranking:", hp.guild.rankButtons.kills.kind, hp.guild.rankButtons.together.kind,
  ns.db.settings.homeRanking)
-- pedido de abates: alguém responde com a lista
commsBeforeKills = #comms
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.KillsRequest(), "GUILD", "Dorvan")
RunTimers()
print("abates repassados:", comms[#comms] and comms[#comms]:match("BULK k|") ~= nil, #comms - commsBeforeKills)
-- ouro doado ao banco: o addon pede o registro ao abrir o banco e lê quando chega
local donationsBefore = #comms
ev._scripts.OnEvent(ev, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 8) -- banco comum: nada
ev._scripts.OnEvent(ev, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 10)
RunTimers()
print("registro pedido ao abrir o banco:", moneyLogQueries)
moneyLog = {
  { "deposit", "Ana Clara", 50000, 0, 0, 2, 0 },
  { "withdraw", "Ana Clara", 900, 0, 0, 1, 0 },
  { "deposit", "Maren-Forever", 1234567, 0, 0, 0, 3 },
  { "depositSummary", "", 777, 0, 0, 0, 1 },
}
ev._scripts.OnEvent(ev, "GUILDBANKLOG_UPDATE")
print("depósitos lidos:", #ns.db.donations, comms[#comms]:match("BULK g|") ~= nil, #comms - donationsBefore)
ev._scripts.OnEvent(ev, "GUILDBANKLOG_UPDATE")
print("depósitos repetidos:", #ns.db.donations, #comms - donationsBefore)
ev._scripts.OnEvent(ev, "GUILDBANK_UPDATE_MONEY")
ev._scripts.OnEvent(ev, "GUILDBANK_UPDATE_MONEY")
RunTimers()
print("registro pedido depois do depósito:", moneyLogQueries)
ev._scripts.OnEvent(ev, "PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 10)
ev._scripts.OnEvent(ev, "GUILDBANK_UPDATE_MONEY")
RunTimers()
print("banco fechado sem pedido:", moneyLogQueries)
-- lista de outro membro: o depósito de Ana Clara já conhecido (horário uma
-- hora diferente) e um novo de Aelin
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.DonationsList(ns.Donations.Encode({
  { w = "Ana Clara", a = 50000, t = now - 2 * 86400 + 3600 },
  { w = "Aelin Ashryvrr", a = 10000, t = now - 86400 },
})), "GUILD", "Dorvan")
print("depósitos recebidos:", #ns.db.donations)
hp.guild.rankButtons.gold._scripts.OnClick(hp.guild.rankButtons.gold)
RankingText("ranking ouro:")
hp.guild.rankButtons.together._scripts.OnClick(hp.guild.rankButtons.together)
print("ranking de volta ao tempo:", hp.guild.rankTitle._text, ns.db.settings.homeRanking)
donationsBefore = #comms
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.DonationsRequest(3), "GUILD", "Dorvan")
RunTimers()
print("pedido de quem já tem tudo:", #comms - donationsBefore)
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.DonationsRequest(), "GUILD", "Dorvan")
RunTimers()
print("depósitos repassados:", comms[#comms]:match("BULK l|") ~= nil, #comms - donationsBefore)
-- quem saiu da guilda sai dos rankings guardados quando o roster muda
ns.db.together.Fulano, ns.db.donations[#ns.db.donations + 1] = 60, { w = "Fulano", a = 5, t = now }
ev._scripts.OnEvent(ev, "GUILD_ROSTER_UPDATE")
RunTimers()
print("quem saiu apagado:", ns.db.kills.Fulano, ns.db.together.Fulano, #ns.db.donations, ns.db.kills["Ana Clara"])
-- aba Membros da janela do addon
ns.MainFrame.Open("members")
local mp = _G.VanguardaDaLuzMainFrame.panels.members
local function MemberLine(i)
  local r = mp.rows[i]
  if not (r and r._shown) then return "-" end
  return table.concat({ r.name._text, r.level._text, r.ilvl._text, r.main._text, r.zone._text, r.rank._text }, " | ")
end
print("membros 1:", MemberLine(1))
print("membros 2:", MemberLine(2))
print("membros 3:", MemberLine(3))
print("membros contagem:", mp.count._text, mp.online._text)
print("membros tempo:", mp.rows[1].time._text, mp.rows[3].time._text, mp.rows[2].data.status,
  ns.Theme.PresenceColor(true, mp.rows[2].data.status) == ns.Theme.colors.away)
-- clique direito: menu com sussurrar e convidar
local invites = {}
local requests = {}
_G.C_PartyInfo = { InviteUnit = function(name) invites[#invites + 1] = name end,
  RequestInviteFromUnit = function(name) requests[#requests + 1] = name end }
local inviteType, inGroup = nil, {}
_G.GetDisplayedInviteType = function(guid)
  if not guid then return "INVITE" end
  return inviteType or "INVITE"
end
_G.UnitInParty = function(name) return inGroup[name] or false end
_G.UnitInRaid = function() return nil end
mp.rows[2]._scripts.OnMouseUp(mp.rows[2], "RightButton")
local memberMenu = _G.VanguardaDaLuzMemberMenu
local function MenuState(m)
  local parts = {}
  for _, b in ipairs(m.buttons) do
    if b._shown then parts[#parts + 1] = b._text .. "=" .. tostring(b._enabled) end
  end
  return table.concat(parts, ",")
end
print("menu membro:", memberMenu._shown, memberMenu.title._text, MenuState(memberMenu))
memberMenu.buttons[2]._scripts.OnClick(memberMenu.buttons[2])
print("convite:", invites[1], memberMenu._shown)
mp.rows[2]._scripts.OnMouseUp(mp.rows[2], "RightButton")
memberMenu.buttons[1]._scripts.OnClick(memberMenu.buttons[1])
print("sussurro membro:", tells[#tells])
mp.rows[3]._scripts.OnMouseUp(mp.rows[3], "RightButton")
print("menu offline:", MenuState(memberMenu))
mp.rows[1]._scripts.OnMouseUp(mp.rows[1], "RightButton")
print("menu você:", MenuState(memberMenu))
-- o item de grupo segue a regra do jogo: pedir para entrar, sugerir convite
inviteType = "REQUEST_INVITE"
mp.rows[2]._scripts.OnMouseUp(mp.rows[2], "RightButton")
print("menu pedir:", MenuState(memberMenu))
memberMenu.buttons[2]._scripts.OnClick(memberMenu.buttons[2])
print("pedido:", requests[1], #invites)
inviteType = "SUGGEST_INVITE"
mp.rows[2]._scripts.OnMouseUp(mp.rows[2], "RightButton")
print("menu sugerir:", MenuState(memberMenu))
inviteType = nil
inGroup["Maren-Forever"] = true
mp.rows[2]._scripts.OnMouseUp(mp.rows[2], "RightButton")
print("menu no grupo:", MenuState(memberMenu))
inGroup["Maren-Forever"] = nil
memberMenu._scripts.OnEvent(memberMenu, "GLOBAL_MOUSE_DOWN")
print("menu fecha fora:", memberMenu._shown)
-- convidar para a guilda: botão só com a permissão do posto; na janela do
-- addon, um botão seguro abre a janela da guilda
_G.CommunitiesFrame:Hide()
mp:Refresh()
local addonInvite = mp.inviteLink
print("botão convite guilda:", mp.invite._shown, mp.hint._rel == mp.invite, addonInvite.button._shown,
  addonInvite.button._attr.type, addonInvite.button._attr.clickbutton == _G.GuildMicroButton)
addonInvite.button._scripts.PostClick(addonInvite.button)
print("convite abre a guilda:", _G.VanguardaDaLuzMainFrame._shown)
ns.MainFrame.Open("members")
_G.CommunitiesFrame:Show()
mp:Refresh()
print("convite com a guilda aberta:", mp.invite._shown, addonInvite.button._shown)
mp.invite._scripts.OnClick(mp.invite)
canInvite = false
mp:Refresh()
print("sem permissão convite:", mp.invite._shown, mp.hint._rel == mp.online, addonInvite.button._shown)
canInvite = true
_G.CommunitiesFrame:Hide()
mp:Refresh()
ns.GuildInviteButton.OnCombatStart()
print("convite em combate:", addonInvite.button._shown, addonInvite.button._rel == UIParent)
ns.GuildInviteButton.Refresh()
print("convite depois do combate:", addonInvite.button._shown)
-- membros no mapa-múndi: envio da própria posição
clock = 100
local sentBefore = #comms
ns.GuildMap.Broadcast()
print("posição enviada:", comms[sentBefore + 1])
ns.GuildMap.Broadcast()
print("posição parado:", #comms - sentBefore)
clock = 100 + ns.Config.MAP_HEARTBEAT
ns.GuildMap.Broadcast()
print("posição de novo:", #comms - sentBefore)
myMap.x = 0.7
lockdown = true
ns.GuildMap.Broadcast()
lockdown = false
myMap.x = nil -- instância: o jogo não dá a posição
ns.GuildMap.Broadcast()
print("posição em restrição e instância:", #comms - sentBefore)
myMap.x = 0.5
ns.GuildMap.SetSharing(false)
clock = clock + 100
ns.GuildMap.Broadcast()
print("sem compartilhar:", #comms - sentBefore, ns.db.settings.map.share)
ns.GuildMap.SetSharing(true)
-- posições recebidas e desenho no mapa
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.Position("10|2500|5000|1"), "GUILD", "Maren-Forever")
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.Position("10|1000|1000|0"), "GUILD", "Ana Clara")
comm.OnCommReceived(comm, "VanguardaDaLuz", "W|lixo", "GUILD", "Dorvan")
ns.GuildMapPins.driver._scripts.OnUpdate(ns.GuildMapPins.driver, 1)
local mapPin = ns.GuildMapPins.pins[1]
print("pontos no mapa:", ns.GuildMapPins.count, mapPin._shown, mapPin._x, mapPin._y, mapPin.item.name,
  ns.GuildMap.positions["Ana Clara"] ~= nil, ns.GuildMap.positions.Dorvan == nil)
for i = #tipLines, 1, -1 do tipLines[i] = nil end
mapPin._scripts.OnEnter(mapPin)
print("tooltip do mapa:", table.concat(tipLines, " / "))
-- membros no minimapa: Maren 250 jardas ao sul e 250 a oeste
ns.GuildMinimapPins.driver._scripts.OnUpdate(ns.GuildMinimapPins.driver, 1)
local miniPin = ns.GuildMinimapPins.pins[1]
print("ponto no minimapa:", ns.GuildMinimapPins.count, miniPin._shown, miniPin._x, miniPin._y, miniPin.item.name)
cvars.rotateMinimap, facing = "1", math.pi
ns.GuildMinimapPins.Draw()
print("minimapa girado:", ns.GuildMinimapPins.count, miniPin._x, miniPin._y)
cvars.rotateMinimap = "0"
minimapRadius = 200
ns.GuildMinimapPins.Draw()
print("fora do minimapa:", ns.GuildMinimapPins.count, miniPin._shown)
minimapRadius = 500
inGroup["Maren-Forever"] = true
ev._scripts.OnEvent(ev, "GROUP_ROSTER_UPDATE")
ns.GuildMinimapPins.Draw()
print("no grupo fora do minimapa:", ns.GuildMinimapPins.count, #ns.GuildMap.Visible())
inGroup["Maren-Forever"] = nil
ev._scripts.OnEvent(ev, "GROUP_ROSTER_UPDATE")
ns.GuildMap.SetOnMinimap(false)
ns.GuildMinimapPins.Draw()
print("minimapa sem membros:", ns.GuildMinimapPins.count, #ns.GuildMap.Visible(), ns.db.settings.map.minimap)
ns.GuildMap.SetOnMinimap(true)
-- desempenho: mensagens recebidas e o minimapa não leem o roster de novo;
-- vários avisos seguidos do jogo viram um só trabalho
local readsBefore = rosterReads
for i = 1, 20 do
  comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.Position("10|" .. (2500 + i) .. "|5000|0"), "GUILD",
    "Maren-Forever")
  ns.GuildMinimapPins.Draw()
end
print("leituras do roster em 20 mensagens:", rosterReads - readsBefore)
-- o minimapa parado não cria lixo nem redesenha; a própria posição vem de
-- UnitPosition (sem vetores do mapa)
ns.GuildMinimapPins.Draw()
local vectorsBefore, movesBefore = vectorsMade, miniPin._moves
collectgarbage("collect")
collectgarbage("stop")
local memBefore = collectgarbage("count")
for _ = 1, 100 do ns.GuildMinimapPins.driver._scripts.OnUpdate(ns.GuildMinimapPins.driver, 1) end
local garbage = collectgarbage("count") - memBefore
collectgarbage("restart")
print("minimapa parado: lixo", garbage < 1, "vetores", vectorsMade - vectorsBefore, "redesenhos",
  miniPin._moves - movesBefore, "ponto", ns.GuildMinimapPins.count)
myMap.x = 0.45
ns.GuildMinimapPins.Draw()
print("minimapa andando:", ns.GuildMinimapPins.count, miniPin._x, miniPin._y, "vetores", vectorsMade - vectorsBefore)
myMap.x = 0.5
_G.UnitPosition = nil -- sem UnitPosition: vale o caminho pelo mapa
ns.GuildMinimapPins.Draw()
print("minimapa sem UnitPosition:", ns.GuildMinimapPins.count, miniPin._x, miniPin._y)
_G.UnitPosition = UnitPositionMock
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.Position("10|2500|5000|1"), "GUILD", "Maren-Forever")
local firesBefore = #timers
ev._scripts.OnEvent(ev, "GUILD_ROSTER_UPDATE")
ev._scripts.OnEvent(ev, "GUILD_ROSTER_UPDATE")
ev._scripts.OnEvent(ev, "GUILD_ROSTER_UPDATE")
local queued = #timers - firesBefore
readsBefore = rosterReads
ns.Guild.PlayerName(); ns.Guild.PlayerName()
print("avisos do roster agrupados:", queued, "leituras depois do aviso:", rosterReads - readsBefore == 2 * #roster)
RunTimers()
-- membros por perto: logo na placa de nome e linha no tooltip
local plates = { nameplate1 = Mock("plate1"), nameplate2 = Mock("plate2") }
plates.nameplate1.namePlateUnitToken, plates.nameplate2.namePlateUnitToken = "nameplate1", "nameplate2"
plates.nameplate1.UnitFrame = { name = Mock("plateName") }
plates.nameplate1.UnitFrame.name:Show()
_G.C_NamePlate = {
  GetNamePlateForUnit = function(unit) return plates[unit] end,
  GetNamePlates = function() return { plates.nameplate1, plates.nameplate2 } end,
}
_G.UnitIsPlayer = function() return true end
_G.UnitIsInMyGuild = function(unit) return unit == "nameplate1" end
local oldGuid = _G.UnitGUID
_G.UnitGUID = function(unit) return unit == "nameplate1" and "Player-2" or oldGuid(unit) end
local GN = ns.GuildNearby
GN.events._scripts.OnEvent(GN.events, "NAME_PLATE_UNIT_ADDED", "nameplate1")
GN.events._scripts.OnEvent(GN.events, "NAME_PLATE_UNIT_ADDED", "nameplate2")
local plateIcon = GN.icons[plates.nameplate1]
print("logo na placa:", plateIcon._shown, plateIcon._rel == plates.nameplate1.UnitFrame.name,
  GN.icons[plates.nameplate2] == nil)
GN.SetPlates(false)
print("placa sem logo:", plateIcon._shown, ns.db.settings.nearby.plates)
GN.SetPlates(true)
print("logo de volta:", plateIcon._shown)
GN.events._scripts.OnEvent(GN.events, "NAME_PLATE_UNIT_REMOVED", "nameplate1")
print("placa removida:", plateIcon._shown)
-- Placas sem namePlateUnitToken (como no jogo): mudar o tamanho mantém o logo.
plates.nameplate1.namePlateUnitToken, plates.nameplate2.namePlateUnitToken = nil, nil
GN.events._scripts.OnEvent(GN.events, "NAME_PLATE_UNIT_ADDED", "nameplate1")
GN.StepScale(1)
print("logo depois de mudar o tamanho:", plateIcon._shown, ns.db.settings.nearby.scale)
GN.StepScale(-1)
local unitTip = unitTooltipCalls[_G.Enum.TooltipDataType.Unit]
local tipUnit = "nameplate1"
_G.GameTooltip.GetUnit = function() return "Maren", tipUnit end
for i = #tipLines, 1, -1 do tipLines[i] = nil end
unitTip(_G.GameTooltip)
tipUnit = "nameplate2"
unitTip(_G.GameTooltip)
print("tooltip por perto:", #tipLines, tipLines[1])
GN.SetTooltip(false)
tipUnit = "nameplate1"
unitTip(_G.GameTooltip)
print("tooltip desligado:", #tipLines, ns.db.settings.nearby.tooltip)
GN.SetTooltip(true)
_G.UnitGUID = oldGuid
shownMap = 1
ns.GuildMapPins.Draw()
print("ponto no continente:", ns.GuildMapPins.count, mapPin._x, mapPin._y)
shownMap = 99
ns.GuildMapPins.Draw()
print("ponto em outro mapa:", ns.GuildMapPins.count, mapPin._shown)
shownMap = 10
ns.GuildMap.SetShown(false)
ns.GuildMapPins.Draw()
print("mapa sem membros:", ns.GuildMapPins.count, ns.db.settings.map.show)
ns.GuildMap.SetShown(true)
clock = clock + ns.Config.MAP_EXPIRE + 1
ns.GuildMapPins.Draw()
print("posição expirada:", ns.GuildMapPins.count, ns.GuildMap.positions["Maren-Forever"] == nil)
clock = 0
mp.headers.level._scripts.OnClick(mp.headers.level)
print("ordem nível:", mp.rows[1].level._text, mp.rows[2].level._text, mp.rows[3].level._text)
mp.headers.level._scripts.OnClick(mp.headers.level)
print("ordem nível desc:", mp.rows[1].level._text, mp.rows[2].level._text, mp.rows[3].level._text)
mp.reset._scripts.OnClick(mp.reset)
print("ordem padrão pela bolinha:", mp.options.sort == nil, mp.headers.level.arrow._shown,
  mp.rows[1].level._text, mp.rows[2].level._text, mp.rows[3].level._text)
mp.online._scripts.OnClick(mp.online)
print("membros só online:", mp.online._text, mp.rows[3]._shown)
-- Bate-papo: histórico da guilda com nome, alt e links; canal de oficiais
ns.GuildChat.OnEvent(nil, "CHAT_MSG_GUILD", "ao vivo www.ao.vivo", "Maren-Forever",
  nil, nil, nil, nil, nil, nil, nil, nil, nil, "Player-2")
ns.MainFrame.Open("chat")
local cp = _G.VanguardaDaLuzMainFrame.panels.chat
print("bate-papo:", cp.frame._shown, cp.officerTab._shown, #cp.messages._lines)
for _, line in ipairs(cp.messages._lines) do print("linha:", line) end
print("canais lidos:", table.concat(readMarks, ","))
cp.messages._scripts.OnHyperlinkClick(cp.messages, "vdlurl:www.site.app", "", "LeftButton")
print("copiar do chat:", cp.copy._shown, cp.copy.edit._text)
cp.messages._scripts.OnHyperlinkClick(cp.messages, "vdlplayer:Maren-Forever", "", "RightButton")
print("menu no nome:", _G.VanguardaDaLuzMemberMenu._shown)
local itemRefs = {}
_G.SetItemRef = function(link, _, button) itemRefs[#itemRefs + 1] = link .. " " .. button end
cp.messages._scripts.OnHyperlinkClick(cp.messages, "quest:123:30", "[A noiva]", "LeftButton")
print("link do jogo:", itemRefs[1])
local hyperlinks = {}
_G.GameTooltip.SetHyperlink = function(_, link) hyperlinks[#hyperlinks + 1] = link end
cp.messages._scripts.OnHyperlinkEnter(cp.messages, "item:6219")
print("tooltip do link:", hyperlinks[1], _G.GameTooltip._shown)
cp.messages._scripts.OnHyperlinkLeave(cp.messages)
_G.VanguardaDaLuzMemberMenu:Hide()
-- Shift+clique num item com a caixa do addon em foco: o link entra nela
cp.input.HasFocus = function() return true end
cp.input.Insert = function(self, t) self._text = self._text .. t end
cp.input:SetText("vendo ")
_G.ChatFrameUtil.InsertLink("|cnIQ3:|Hitem:6219|h[Chave]|h|r")
print("link na caixa:", cp.input._text)
cp.input._scripts.OnEnterPressed(cp.input)
print("enviado com link:", chat[#chat])
cp.input.HasFocus = function() return false end
local chatBefore = #chat
cp.input:SetText("  olá | guilda ")
cp.input._scripts.OnEnterPressed(cp.input)
print("enviado no chat:", chat[#chat], #chat - chatBefore, "|" .. cp.input._text .. "|")
cp.officerTab._scripts.OnClick(cp.officerTab)
print("oficiais sem histórico:", cp.messages._lines[1], table.concat(historyRequests, ","))
officerLoaded = true
ns.GuildChat.OnEvent(nil, "CLUB_MESSAGE_HISTORY_RECEIVED")
RunTimers()
cp:Refresh()
print("oficiais:", cp:Channel(), cp.messages._lines[#cp.messages._lines])
cp.input:SetText("reunião")
cp.input._scripts.OnEnterPressed(cp.input)
print("enviado aos oficiais:", chat[#chat])
cp.guildTab._scripts.OnClick(cp.guildTab)
for i = #chat, 1, -1 do chat[i] = nil end -- o alerta de raide confere o chat sozinho
_G.VanguardaDaLuzMainFrame:Hide()
-- Configurações
ns.MainFrame.Open("settings")
local sp = _G.VanguardaDaLuzMainFrame.panels.settings
print("configurações:", sp.frame._shown, sp.main.value, sp.minimap.value, sp.features.events.value, sp.mainNote._text)
-- tamanho do logo dos membros por perto: 100% a 300%, de 25 em 25
print("logo 100%:", sp.scaleValue._text, sp.smaller._enabled, sp.bigger._enabled)
sp.bigger._scripts.OnClick(sp.bigger)
sp:Refresh()
print("logo maior:", sp.scaleValue._text, ns.db.settings.nearby.scale, sp.smaller._enabled)
for _ = 1, 10 do sp.bigger._scripts.OnClick(sp.bigger) end
sp:Refresh()
print("logo no máximo:", sp.scaleValue._text, sp.bigger._enabled)
for _ = 1, 10 do sp.smaller._scripts.OnClick(sp.smaller) end
sp:Refresh()
print("logo de volta a 100%:", sp.scaleValue._text, ns.db.settings.nearby.scale, sp.smaller._enabled)
Click("Aba Eventos")
print("sem aba eventos:", gt.events._shown, gt.professions._shown, gt.professions._rel._name,
  ns.db.settings.guildWindow.events)
Click("Aba Eventos")
print("aba eventos de volta:", gt.events._shown, gt.professions._rel._name, ns.db.settings.guildWindow.events)
Click("Item level e main/alt na lista original de Membros")
print("sem item level:", GR.labels[newRow]._shown)
Click("Item level e main/alt na lista original de Membros")
print("item level de volta:", GR.labels[newRow]._shown)
Click("Início do addon na aba Informações")
cf.RosterTab:SetChecked(false)
cf.GuildInfoTab:SetChecked(true)
cf.GuildInfoTab._scripts.OnClick(cf.GuildInfoTab)
RunTimers()
print("informações desligada:", GT.overlay._shown)
Click("Início do addon na aba Informações")
print("informações ligada:", GT.overlay._shown)
cf.GuildInfoTab:SetChecked(false)
cf.RosterTab:SetChecked(true)
cf.RosterTab._scripts.OnClick(cf.RosterTab)
RunTimers()
Click("Mostrar o botão no minimapa")
print("minimapa escondido:", _G.VanguardaDaLuzMinimapButton._shown, ns.db.settings.minimap.hide, sp.minimap.value)
Click("Mostrar o botão no minimapa")
print("minimapa de volta:", _G.VanguardaDaLuzMinimapButton._shown, ns.db.settings.minimap.hide)
Click("Este personagem é o meu main")
print("main pela tela:", ns.db.settings.main, sp.main.value, sp.mainNote._text)
Click("Este personagem é o meu main")
print("main desmarcado:", ns.db.settings.main, sp.main.value, ns.db.members["Tester Vaz"].m)
ns.MainPrompt.ShowIfNeeded()
Click("Sim, é o meu main")
print("popup sim:", prompt._shown, ns.db.settings.main)
ns.MainPrompt.ShowIfNeeded()
print("popup com main:", prompt._shown)
ns.db.settings.main = "Fulano Saiu" -- main fora da guilda: pergunta de novo
ns.MainPrompt.ShowIfNeeded()
print("popup main fora da guilda:", prompt._shown)
prompt:Hide()
ns.db.settings.main = nil
-- atalho de teclado
print("atalho:", sp.key._text, sp.keyNote._text)
sp.key._scripts.OnClick(sp.key)
print("capturando:", sp.key._text)
sp.key._scripts.OnKeyDown(sp.key, "LSHIFT")
shiftDown = true
sp.key._scripts.OnKeyDown(sp.key, "M")
shiftDown = false
print("atalho definido:", ns.db.settings.keybind, bindings["SHIFT-M"], sp.key._text, sp.keyNote._text)
_G.VanguardaDaLuzMainFrame:Hide()
_G.VanguardaDaLuzToggleButton._scripts.OnClick(_G.VanguardaDaLuzToggleButton)
print("atalho abre:", _G.VanguardaDaLuzMainFrame._shown)
ns.MainFrame.Open("settings")
sp.key._scripts.OnClick(sp.key)
sp.key._scripts.OnKeyDown(sp.key, "ESCAPE")
print("captura cancelada:", sp.key._text, ns.db.settings.keybind)
-- sem clicar no botão, uma tecla com a aba aberta não vira atalho
sp.key._scripts.OnKeyDown(sp.key, "D")
print("tecla sem captura:", ns.db.settings.keybind, sp.key._text)
inCombat = true
sp.key._scripts.OnClick(sp.key)
sp.key._scripts.OnKeyDown(sp.key, "F7")
print("em combate:", ns.db.settings.keybind, bindings.F7, bindings["SHIFT-M"], sp.keyNote._text)
inCombat = false
ns.Keybind.OnCombatEnd()
print("fim do combate:", bindings.F7, bindings["SHIFT-M"], sp.keyNote._text)
sp.clearKey._scripts.OnClick(sp.clearKey)
print("atalho limpo:", ns.db.settings.keybind, next(bindings), sp.key._text)
_G.VanguardaDaLuzMainFrame:Hide()
-- menu de atalhos do minimapa (clique direito)
local mb, mainFrame = _G.VanguardaDaLuzMinimapButton, _G.VanguardaDaLuzMainFrame
local function MenuLabels(menu)
  local labels = {}
  for _, b in ipairs(menu.buttons) do if b._shown then labels[#labels + 1] = b._text end end
  return table.concat(labels, ",")
end
mainFrame:Hide()
mb._scripts.OnClick(mb, "RightButton")
local mm = _G.VanguardaDaLuzMinimapMenu
print("menu minimapa:", mm._shown, MenuLabels(mm))
mm.buttons[2]._scripts.OnClick(mm.buttons[2])
print("atalho eventos:", mm._shown, mainFrame._shown, mainFrame.panels.events.frame._shown)
mb._scripts.OnClick(mb, "RightButton")
mm._scripts.OnUpdate(mm, 3)
print("menu fecha sozinho:", mm._shown)
local trustedInfo = _G.GetGuildInfo
_G.GetGuildInfo = function() return "Vanguarda da Luz", "Membro", 5 end
mb._scripts.OnClick(mb, "RightButton")
print("menu sem cargo:", MenuLabels(mm))
ns.MainFrame.Open("settings")
print("abas sem cargo:", mainFrame.tabs.admin._shown, mainFrame.tabs.settings._rel == mainFrame.tabs.professions)
ns.MainFrame.Open("chat")
local chatSemCargo = mainFrame.panels.chat
print("bate-papo sem cargo:", chatSemCargo.officerTab._shown, chatSemCargo:Channel())
GT.panels.members:Refresh()
print("dica membros sem cargo:", GT.panels.members.hint._shown, GT.panels.members.hint._text)
GT.panels.info:Refresh()
print("dica informações sem cargo:", GT.panels.info.hint._text)
local sf = mainFrame.panels.settings.features
print("opção administração sem cargo:", sf.admin._shown, sf.chat._rel == sf.professions)
mainFrame:Hide()
mm:Hide()
dialog:Hide()
SlashCmdList.VANGUARDADALUZ("importar")
print("importar sem cargo abre:", dialog._shown)
_G.GetGuildInfo = trustedInfo
mainFrame:Hide()
-- luta com chefe: o jogo entrega a lista de membros, o roster e o chat como
-- secretos; o addon usa a última leitura, sem erro
local SECRET = setmetatable({}, { __len = function() error("attempt to get length of a secret table") end })
_G.issecretvalue = function(v) return v == SECRET end
local realMembers, realStreams, realCount = _G.C_Club.GetClubMembers, _G.C_Club.GetStreams, _G.GetNumGuildMembers
_G.C_Club.GetClubMembers = function() return SECRET end
_G.C_Club.GetStreams = function() return SECRET end
_G.GetNumGuildMembers = function() return SECRET end
ev._scripts.OnEvent(ev, "GUILD_ROSTER_UPDATE")
RunTimers()
local secretMembers = ns.Flavor.GuildMembers()
print("em luta:", secretMembers and #secretMembers, #ns.Flavor.GuildRoster(), ns.Guild.Counts(),
  #ns.GuildChat.Entries("guild"), ns.Guild.PlayerName())
_G.C_Club.GetClubMembers, _G.C_Club.GetStreams, _G.GetNumGuildMembers = realMembers, realStreams, realCount
_G.issecretvalue = nil
-- mensagem de recrutamento: salva, vai para a guilda e sai no canal com o clique
_G.GetChannelList = function() return 1, "Geral", false, 2, "Comércio", false, 4, "DefesaLocal", true end
local adminPanel = main.panels.admin
adminPanel:Refresh()
print("recrutamento vazio:", adminPanel.recruit.send._enabled, adminPanel.recruit.text._text:sub(1, 20))
local recruitBefore = #comms
Click("Editar texto")
local rd = _G.VanguardaDaLuzRecruitDialog
rd.edit:SetText("Vanguarda da Luz | recrutando\nraides às 20h")
rd.edit._scripts.OnTextChanged(rd.edit)
print("recrutamento diálogo:", rd._shown, rd.counter._text, rd.channel._text)
Click("Salvar e enviar")
print("recrutamento enviado:", ns.db.recruit.text, ns.db.recruit.by, chat[#chat], rd._shown)
print("recrutamento guilda:", #comms - recruitBefore, comms[#comms])
Click("Enviar no canal")                               -- antes do intervalo
clock = clock + 61
lockdown = true
Click("Enviar no canal")
lockdown = false
SlashCmdList.VANGUARDADALUZ("")
ns.RecruitDialog.Show()
Click("Canal: 1. Geral")
print("recrutamento canal:", rd.channel._text, ns.db.settings.recruitChannel)
rd:Hide()
Click("Enviar no canal")
print("recrutamento no comércio:", chat[#chat])
adminPanel:Refresh()
print("recrutamento cartão:", adminPanel.recruit.send._enabled, adminPanel.recruit.text._text)
-- texto de um Lorde vale; de quem não tem cargo, não
local newer = ns.Recruit.Encode({ text = "Texto da Maren", at = ns.db.recruit.at + 10, by = "Maren-Forever" })
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.Recruit(newer), "GUILD", "Ana Clara")
print("recrutamento sem cargo:", ns.db.recruit.text)
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.Recruit(newer), "GUILD", "Maren-Forever")
print("recrutamento de lorde:", ns.db.recruit.text, ns.db.recruit.by)
recruitBefore = #comms
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.RecruitRequest(), "GUILD", "Ana Clara")
RunTimers()
print("recrutamento responde:", #comms - recruitBefore, comms[#comms])
for i = #chat, 1, -1 do chat[i] = nil end -- o alerta de raide confere o chat sozinho
-- versão nova: o pedido de sincronização leva a versão; quem tem uma mais
-- nova responde; o aviso aparece uma vez
local versionBefore = #comms
ns.Comm.RequestLatest()
print("versão no pedido:", comms[#comms])
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.Version("0.0.9"), "GUILD", "Dorvan")
RunTimers()
print("versão responde ao antigo:", comms[#comms])
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.Version("0.0.8"), "GUILD", "Dorvan")
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.Version("0.1.0"), "GUILD", "Ana Clara")
RunTimers()
print("versão resposta cancelada:", comms[#comms] == comms[versionBefore + 10], #comms - versionBefore)
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.Version("0.2.0"), "GUILD", "Maren-Forever")
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.Version("0.10.0"), "GUILD", "Ana Clara")
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.Version("lixo"), "GUILD", "Ana Clara")
print("versão mais nova:", ns.VersionCheck.Newest())
-- lembrete 15 min antes de um evento confirmado, uma vez só
ns.db.events.lembrete = { id = "lembrete", title = "Raide | teste", startsAt = now + 600, status = "ativo",
  description = "", organizer = "M", updatedAt = now }
ns.db.events.semPresenca = { id = "semPresenca", title = "Outro", startsAt = now + 300, status = "ativo",
  description = "", organizer = "M", updatedAt = now }
ns.Attendance.Set(ns.db.attendance, "lembrete", "Tester Vaz", 1, now)
local warningsBefore, soundsBefore = #warnings, sounds
ns.EventReminder.Check()
ns.EventReminder.Check()
print("lembretes:", #warnings - warningsBefore, warnings[#warnings], ns.db.reminded.lembrete == now + 600,
  sounds - soundsBefore)
for i = #warnings, warningsBefore + 1, -1 do warnings[i] = nil end
sounds = sounds - 1 -- o alerta de raide confere os sons sozinho
ns.db.events.lembrete, ns.db.events.semPresenca = nil, nil
-- diagnóstico
SlashCmdList.VANGUARDADALUZ("status")
-- alerta de raide
local before = #comms
SlashCmdList.VANGUARDADALUZ("alerta   ")             -- sem texto: abre o modal
_G.VanguardaDaLuzAlertDialog.edit:SetText("Raide | Núcleo às 20h")
_G.VanguardaDaLuzAlertDialog.edit._scripts.OnTextChanged(_G.VanguardaDaLuzAlertDialog.edit)
print("prévia:", _G.VanguardaDaLuzAlertDialog.preview._text)
Click("Enviar alerta")
SlashCmdList.VANGUARDADALUZ("alerta De novo")         -- antes do intervalo
lockdown = true
SlashCmdList.VANGUARDADALUZ("alerta x")
lockdown = false
print("alertas enviados:", #comms - before, comms[#comms])
-- a mensagem volta para quem enviou, com o nome do roster
local ownId = comms[#comms]:match("A|(%d+)|")
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.Alert(ownId, "Raide / Núcleo às 20h"), "GUILD", "Tester Vaz")
local alertId = 1794410000123
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.Alert(alertId, "Entrem já"), "GUILD", "Maren-Forever")
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.Alert(alertId, "Entrem já"), "GUILD", "Maren-Forever")
-- jogador de outra guilda: só a janela de boas-vindas, sem sincronização
_G.GetGuildInfo = function() return "Outra Guilda", "Mestre", 0 end
local commsBefore = #comms
SlashCmdList.VANGUARDADALUZ("")
local welcome = _G.VanguardaDaLuzWelcomeFrame
print("boas-vindas:", welcome._shown, welcome.link._text, "calendário:", _G.VanguardaDaLuzMainFrame._shown)
welcome:Hide()
SlashCmdList.VANGUARDADALUZ("alerta Raide")
print("alerta fora da guilda abre boas-vindas:", welcome._shown)
ns.db.export = nil
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.Data(1794409200, raw:gsub("%s+$","")), "GUILD", "Maren-Forever")
ns.Comm.RequestLatest()
print("fora da guilda: dados", ns.db.export == nil and "ignorados" or "aceitos", "envios", #comms - commsBefore)
for _, c in ipairs(comms) do print("comm:", c) end
return output, ns, comms, { chat = chat, warnings = warnings, sounds = sounds }, tells
