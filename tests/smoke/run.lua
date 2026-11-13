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
      SetPoint = function(self, _, rel) if type(rel) == "table" then self._rel = rel end end,
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
_G.UISpecialFrames, _G.SlashCmdList = {}, {}
_G.Mixin = function(o) return o end
_G.BackdropTemplateMixin = {}
_G.CreateColor = function() return {} end
_G.geterrorhandler = function() return error end
_G.securecallfunction = function(f, ...) return f(...) end
local now = 1794410000
_G.GetServerTime = function() return now end
_G.GetTime = function() return 0 end
_G.IsInGuild = function() return true end
_G.InCombatLockdown = function() return false end
_G.GetGuildInfo = function() return "Vanguarda da Luz", "Lorde", 1 end
-- O nome do jogador no roster é diferente de UnitName("player").
local roster = {
  { "Maren-Forever", "Lorde", 1, [17] = "Player-2", level = 30, class = "Ladina", zone = "Pantanal",
    online = true, classFile = "ROGUE" },
  { "Tester Vaz", "Lorde", 1, [17] = "Player-1", level = 33, class = "Paladino", zone = "Desolação",
    online = true, classFile = "PALADIN" },
  { "Ana Clara", "Escudeiro", 4, level = 34, class = "Maga", zone = "Vale Gris", online = false,
    classFile = "MAGE" },
}
_G.GetNumGuildMembers = function() return #roster end
_G.GetGuildRosterInfo = function(i)
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
_G.Enum = { ClubMemberPresence = { Unknown = 0, Online = 1, OnlineMobile = 2, Offline = 3, Away = 4, Busy = 5 } }
-- Lista da guilda (C_Club): nível da profissão sempre 1, como no WoW Forever.
local club = {
  { name = "Tester Vaz", presence = 1, profession1Name = "Mineração", profession1Rank = 1,
    profession2Name = "Ferraria", profession2Rank = 1 },
  { name = "Maren-Forever", presence = 4, profession1Name = "Alquimia", profession1Rank = 1 },
  { name = "Aelin Ashryvrr", presence = 3, profession1Name = "Esfolamento", profession1Rank = 1,
    profession2Name = "Couraria", profession2Rank = 1 },
}
_G.C_Club = {
  GetGuildClubId = function() return "clube" end,
  GetClubMembers = function() local ids = {} for i = 1, #club do ids[i] = i end return ids end,
  GetMemberInfo = function(_, id) return club[id] end,
}
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
_G.GetGuildRosterMOTD = function() return "Raide sexta | tragam poções" end
_G.GetGuildInfoText = function() return "Site: https://vanguarda-da-luz.web.app\nDiscord: www.discord.gg/abc." end
local tells = {}
_G.ChatFrame_SendTell = function(name) tells[#tells + 1] = name end
local timers = {}
_G.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end, NewTicker = function() end }
_G.C_AddOns = { GetAddOnMetadata = function() return "0.1.0" end,
  IsAddOnLoaded = function(name) return name == "Blizzard_Communities" end }
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
  SendChatMessage = function(m, chatType) chat[#chat + 1] = chatType .. " " .. m end,
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
infoPanel.original._scripts.OnClick(infoPanel.original)
print("original da Blizzard:", GT.overlay._shown)
cf.GuildInfoTab._scripts.OnClick(cf.GuildInfoTab)
RunTimers()
print("informações de novo:", GT.overlay._shown)
gt.events._scripts.OnClick(gt.events)
print("eventos a partir de informações:", GT.overlay._shown, gt.events._checked, cf.GuildInfoTab._checked,
  infoPanel.frame._shown)
cf.GuildInfoTab:SetChecked(false)
cf.RosterTab:SetChecked(true)
cf.RosterTab._scripts.OnClick(cf.RosterTab)
RunTimers()
print("membros depois:", GT.overlay._shown, GT.panels.members and GT.panels.members.frame._shown)
local membersCover = GT.panels.members
local coverRow = membersCover.inner.rows[1]
print("lista na guilda:", coverRow.name._text, "|", coverRow.rank._text, "| dica:", membersCover.hint._shown,
  "| tempo:", membersCover.inner.columns.time ~= nil, rawget(membersCover.inner.headers, "time") ~= nil)
membersCover.original._scripts.OnClick(membersCover.original)
print("membros original:", GT.overlay._shown)
cf.RosterTab._scripts.OnClick(cf.RosterTab)
RunTimers()
print("membros de novo:", GT.overlay._shown)
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
roster[1].status = 1; ns.GuildTogether.Tick() -- ausente no roster
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
print("ranking:", #hp.guild.rankLines, hp.guild.rankLines[1].name._text, hp.guild.rankLines[1].time._text,
  hp.guild.rankLines[2].name._text)
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
_G.C_PartyInfo = { InviteUnit = function(name) invites[#invites + 1] = name end }
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
memberMenu._scripts.OnEvent(memberMenu, "GLOBAL_MOUSE_DOWN")
print("menu fecha fora:", memberMenu._shown)
mp.headers.level._scripts.OnClick(mp.headers.level)
print("ordem nível:", mp.rows[1].level._text, mp.rows[2].level._text, mp.rows[3].level._text)
mp.headers.level._scripts.OnClick(mp.headers.level)
print("ordem nível desc:", mp.rows[1].level._text, mp.rows[2].level._text, mp.rows[3].level._text)
mp.headers.level._scripts.OnClick(mp.headers.level)
mp.online._scripts.OnClick(mp.online)
print("membros só online:", mp.online._text, mp.rows[3]._shown)
_G.VanguardaDaLuzMainFrame:Hide()
-- Configurações
ns.MainFrame.Open("settings")
local sp = _G.VanguardaDaLuzMainFrame.panels.settings
print("configurações:", sp.frame._shown, sp.main.value, sp.minimap.value, sp.features.events.value, sp.mainNote._text)
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
print("abas sem cargo:", mainFrame.tabs.admin._shown, mainFrame.tabs.settings._rel == mainFrame.tabs.members)
GT.panels.members:Refresh()
print("dica membros sem cargo:", GT.panels.members.hint._shown, GT.panels.members.hint._text)
GT.panels.info:Refresh()
print("dica informações sem cargo:", GT.panels.info.hint._text)
local sf = mainFrame.panels.settings.features
print("opção administração sem cargo:", sf.admin._shown, sf.info._rel == sf.professions)
mainFrame:Hide()
mm:Hide()
dialog:Hide()
SlashCmdList.VANGUARDADALUZ("importar")
print("importar sem cargo abre:", dialog._shown)
_G.GetGuildInfo = trustedInfo
mainFrame:Hide()
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
