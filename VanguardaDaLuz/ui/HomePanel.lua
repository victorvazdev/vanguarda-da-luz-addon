-- Painel Início: mensagem do dia e informações da guilda (com os links
-- clicáveis para copiar), próximo evento e o cartão Guilda (membros online e
-- rankings).
--
-- Na janela do addon, o cartão Guilda fica no espaço grande da esquerda e as
-- informações da guilda à direita. Na janela da guilda (`compact`, cobrindo a
-- aba Informações da Blizzard) as informações ficam no espaço grande e o
-- cartão Guilda à direita, sem espaço para o ranking. O cartão Guilda mostra um ranking por vez (tempo
-- com a guilda, abates honrosos ou ouro doado ao banco), escolhido nos botões
-- em cima dele; a escolha fica em db.settings.homeRanking.
local _, ns = ...

local L = ns.L

local Theme, Text, Time = ns.Theme, ns.Text, ns.Time
local HomePanel = {}

local LINK_TYPE = "vdlurl"
local RIGHT_W = 320
local NEXT_H = 200         -- cartão "Próximo evento" na janela da guilda
local NEXT_H_WIDE = 170    -- na janela do addon: sobra altura para o ranking
local RANK_MAX = 10        -- linhas do ranking "Mais tempo jogando com a guilda"
local RANK_LINE_H = 19     -- altura de cada linha do ranking
local RANK_HEADER_H = 164  -- título, contagem, "Jogando com", botões e título do ranking
local RANK_BUTTON_H = 22   -- botões que trocam o ranking
local RANK_BUTTON_MAX_W = 110
local RANK_VALUE_W = 170   -- coluna do valor (tempo, abates ou ouro com prata e cobre) no ranking
local MOTD_H = 140
local GAP = 16
local PAD = 16
local SCROLLBAR_W = 24 -- barra de rolagem do UIPanelScrollFrameTemplate, à direita

local Panel = {}
Panel.__index = Panel

local function Card(parent, title)
  local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  Theme.Backdrop(card, "surface", "border")
  card.title = Theme.Text(card, "heading", "gold")
  card.title:SetPoint("TOPLEFT", PAD, -14)
  card.title:SetPoint("RIGHT", -PAD, 0)
  card.title:SetText(title)
  return card
end

-- Mostra o link na caixa de cópia, já selecionado.
function Panel:ShowCopy(url)
  local copy = self.copy
  copy.url = url
  copy.edit:SetText(url)
  copy:Show()
  -- Clique fora da caixa fecha (o evento só é observado com ela aberta).
  if self.hyperlinks then pcall(copy.RegisterEvent, copy, "GLOBAL_MOUSE_DOWN") end
  copy.edit:SetFocus()
  copy.edit:HighlightText()
end

-- Ajusta a altura da área rolável ao texto e volta ao topo.
local TEXT_TOP = 4 -- folga no topo: a área rolável corta o que passa da borda

local function Fit(holder)
  holder:SetHeight(holder.text:GetStringHeight() + TEXT_TOP + 4)
  holder.scroll:SetVerticalScroll(0)
end

-- Texto com os links clicáveis num quadro com hyperlinks.
local function SetLinkedText(holder, raw)
  local text = raw ~= "" and raw or nil
  if not text then
    holder.text:SetText(Theme.Code("textMuted") .. L["Nada definido."] .. "|r")
    Fit(holder)
    return {}
  end
  holder.text:SetText(Text.Linkify(text, LINK_TYPE, Theme.Code("azure")))
  Fit(holder)
  return Text.FindLinks(text)
end

-- Preenche as linhas de um ranking. `value(item)` dá o texto da coluna da
-- direita; `mine` é a pessoa do jogador (em destaque).
local function FillRanking(lines, ranking, mine, value)
  for i, line in ipairs(lines) do
    local item = ranking[i]
    if item then
      local name = Text.Escape(item.name)
      if item.name == mine then name = Theme.Code("goldLight") .. name .. "|r" end
      line.name:SetText(i .. ".  " .. name)
      line.value:SetText(Theme.Code("gold") .. value(item) .. "|r")
    elseif i == 1 then
      line.name:SetText(Theme.Code("textMuted") .. L["Ninguém ainda."] .. "|r")
      line.value:SetText("")
    else
      line.name:SetText("")
      line.value:SetText("")
    end
  end
end

function Panel:Refresh()
  SetLinkedText(self.motd.holder, ns.Guild.Motd())
  local links = SetLinkedText(self.info.holder, ns.Guild.InfoText())
  -- Ajuda e caixa de cópia: sem suporte a hyperlinks, a caixa já mostra o primeiro link.
  self.info.hint:SetShown(#links > 0 and self.hyperlinks and not self.compact)
  if #links > 0 and not self.hyperlinks then
    self:ShowCopy(links[1].url)
  elseif #links == 0 then
    self.copy:Hide()
  end

  ns.GuildTextEdit.Refresh()
  self.motd.hint:SetShown(not self.compact and ns.GuildTextEdit.CanEditAny("open"))

  -- Próximo evento
  local now = GetServerTime()
  local event = ns.Store.NextEvent(now)
  local n = self.nextEvent
  n.event = event
  if event then
    n.name:SetText(Text.Escape(event.title))
    local offset = ns.Config.BRASILIA_OFFSET
    n.when:SetText(Time.FormatLongDate(event.startsAt, offset) .. "\n"
      .. Time.FormatClock(event.startsAt, offset) .. " " .. L["(Brasília)"])
    local confirmed = #ns.Presence.Confirmed(event.id)
    local mine = ns.Presence.Status(event.id) == 1
    n.attendance:SetText(string.format(L["%d confirmado(s) no jogo"], confirmed)
      .. (mine and (Theme.Code("success") .. "  ·  " .. L["você vai"] .. "|r") or ""))
    n.open:Show()
  else
    n.name:SetText(Theme.Code("textMuted") .. L["Nenhum evento marcado."] .. "|r")
    n.when:SetText("")
    n.attendance:SetText("")
    n.open:Hide()
  end

  -- Guilda
  local total, online = ns.Guild.Counts()
  self.guild.counts:SetText(string.format(L["%d membro(s)"], total) .. "  ·  " .. Theme.Code("success")
    .. string.format(L["%d online"], online) .. "|r")
  self.guild.player:SetText(Theme.Code("textMuted") .. L["Jogando com"] .. "|r "
    .. Text.Escape(ns.Guild.PlayerName() or "?"))

  self:RefreshRanking()
end

-- Rankings do cartão Guilda: botão, título, total por pessoa, lista e valor.
local RANKINGS = {
  { key = "together", label = L["Tempo"], title = L["MAIS TEMPO JOGANDO COM A GUILDA"],
    totals = function() return ns.GuildTogether.Totals() end,
    list = function(totals, limit) return ns.Together.Ranking(totals, limit) end,
    value = function(item) return ns.Together.Format(item.seconds) end },
  { key = "kills", label = L["Abates"], title = L["MAIS ABATES HONROSOS"],
    totals = function() return ns.GuildKills.Totals() end,
    list = function(totals, limit) return ns.Kills.Ranking(totals, limit) end,
    value = function(item) return tostring(item.kills) end },
  { key = "gold", label = L["Ouro"], title = L["MAIS OURO DOADO AO BANCO"],
    totals = function() return ns.GuildDonations.Totals() end,
    list = function(totals, limit) return ns.Donations.Ranking(totals, limit) end,
    value = function(item) return ns.Flavor.MoneyText(item.amount) end },
}

-- Ranking escolhido (o primeiro se não houver escolha).
local function SelectedRanking()
  local key = ns.db.settings.homeRanking
  for _, ranking in ipairs(RANKINGS) do
    if ranking.key == key then return ranking end
  end
  return RANKINGS[1]
end

function HomePanel.SelectRanking(key)
  ns.db.settings.homeRanking = key ~= RANKINGS[1].key and key or nil
  ns.Fire("SETTINGS_UPDATED")
end

-- Ranking escolhido: só quem ainda está na guilda; a pessoa do jogador em
-- destaque.
function Panel:RefreshRanking()
  local guild = self.guild
  local selected = SelectedRanking()
  for key, button in pairs(guild.rankButtons) do
    -- Os não escolhidos com borda, para parecerem botões (o "ghost" não tem).
    button:SetKind(key == selected.key and "primary" or "outline")
  end
  if #guild.rankLines == 0 then return end
  guild.rankTitle:SetText(selected.title)
  local inGuild = ns.Flavor.GuildRosterIndex().byName
  local totals = {}
  for person, value in pairs(selected.totals()) do
    if inGuild[person] then totals[person] = value end
  end
  local _, mine = ns.GuildTogether.PersonTotal(ns.Guild.PlayerName() or "")
  FillRanking(guild.rankLines, selected.list(totals, #guild.rankLines), mine, selected.value)
end

-- Texto com rolagem quando não cabe no cartão. Retorna o quadro que recebe os
-- hyperlinks (com .text e .scroll); a barra só aparece quando há o que rolar.
local function LinkedText(parent)
  local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  local holder = CreateFrame("Frame", nil, scroll)
  holder:SetSize(1, 1)
  scroll:SetScrollChild(holder)
  local text = Theme.Text(holder, "body")
  text:SetPoint("TOPLEFT", 0, -TEXT_TOP)
  text:SetSpacing(3)
  holder.text = text
  holder.scroll = scroll
  scroll:SetScript("OnSizeChanged", function(_, w)
    holder:SetWidth(w)
    text:SetWidth(w)
    Fit(holder)
  end)
  scroll:HookScript("OnScrollRangeChanged", function(s, _, range)
    if s.ScrollBar then s.ScrollBar:SetShown((range or 0) > 0) end
  end)
  return holder
end

-- Botões dos rankings, título e linhas no cartão Guilda, com `width` de
-- largura. Preenche guild.rankButtons, guild.rankTitle e guild.rankLines.
-- Sem espaço para linhas (`count` = 0), nada aparece.
local function BuildRanking(panel, guild, width, count)
  guild.rankButtons, guild.rankLines = {}, {}
  if count == 0 then return end
  local buttonW = math.min(RANK_BUTTON_MAX_W, math.floor((width - 2 * 6) / #RANKINGS))
  local previous
  for _, ranking in ipairs(RANKINGS) do
    local button = Theme.Button(guild, ranking.label, "outline", buttonW)
    button:SetHeight(RANK_BUTTON_H)
    if previous then
      button:SetPoint("LEFT", previous, "RIGHT", 6, 0)
    else
      button:SetPoint("TOPLEFT", guild.player, "BOTTOMLEFT", 0, -12)
    end
    button:SetScript("OnClick", function()
      HomePanel.SelectRanking(ranking.key)
      panel:RefreshRanking()
    end)
    guild.rankButtons[ranking.key] = button
    previous = button
  end
  local title = Theme.Text(guild, "smallStrong", "goldDeep")
  title:SetPoint("TOPLEFT", guild.player, "BOTTOMLEFT", 0, -12 - RANK_BUTTON_H - 10)
  title:SetWidth(width)
  title:SetWordWrap(false)
  guild.rankTitle = title
  local above = title
  for i = 1, count do
    local name = Theme.Text(guild, "body")
    name:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, i == 1 and -6 or -2)
    name:SetWidth(width - RANK_VALUE_W)
    name:SetWordWrap(false)
    local value = Theme.Text(guild, "body")
    value:SetPoint("TOP", name, "TOP")
    value:SetPoint("LEFT", name, "RIGHT")
    value:SetWidth(RANK_VALUE_W)
    value:SetJustifyH("RIGHT")
    guild.rankLines[i] = { name = name, value = value }
    above = name
  end
end

-- Cria o painel dentro de `parent`, com `width` x `height`. `onOpenEvent(event)`
-- é chamado pelo botão L["Ver no calendário"]. `compact` (janela da guilda) esconde
-- a dica de copiar, que não cabe ao lado do título.
function HomePanel.Create(parent, width, height, onOpenEvent, compact)
  local self = setmetatable({ compact = compact }, Panel)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetSize(width, height)
  self.frame = frame
  local leftW = width - RIGHT_W - GAP

  -- Mensagem do dia
  local motd = Card(frame, L["Mensagem do dia"])
  -- Cartões em pixels inteiros: a borda de cima não some (ver Theme.PixelSize).
  Theme.PixelPoint(motd, "TOPLEFT", frame, "TOPLEFT")
  Theme.PixelSize(motd, leftW, MOTD_H)
  motd.hint = Theme.Text(motd, "small", "textMuted")
  motd.hint:SetPoint("TOPRIGHT", -PAD, -18)
  motd.hint:SetText(L["Clique no texto para editar na janela da guilda"])
  motd.hint:Hide()
  motd.holder = LinkedText(motd)
  motd.holder.scroll:SetPoint("TOPLEFT", motd.title, "BOTTOMLEFT", 0, -10 + TEXT_TOP)
  motd.holder.scroll:SetPoint("BOTTOMRIGHT", -PAD - SCROLLBAR_W, PAD)
  self.motd = motd

  -- Espaços embaixo: o grande da esquerda e o da direita, embaixo do
  -- próximo evento.
  local nextH = compact and NEXT_H or NEXT_H_WIDE
  local function BigSlot(card)
    Theme.PixelPoint(card, "TOPLEFT", frame, "TOPLEFT", 0, -(MOTD_H + GAP))
    Theme.PixelSize(card, leftW, height - MOTD_H - GAP)
    return leftW, height - MOTD_H - GAP
  end
  local function RightSlot(card)
    Theme.PixelPoint(card, "TOPRIGHT", frame, "TOPRIGHT", 0, -(nextH + GAP))
    Theme.PixelSize(card, RIGHT_W, height - nextH - GAP)
    return RIGHT_W, height - nextH - GAP
  end

  -- Informações da guilda
  local info = Card(frame, L["Informações da guilda"])
  info.hint = Theme.Text(info, "small", "textMuted")
  info.hint:SetText(L["Clique num link para copiar"])
  info.holder = LinkedText(info)
  if compact then
    BigSlot(info)
    info.hint:SetPoint("TOPRIGHT", -PAD, -18)
    info.holder.scroll:SetPoint("TOPLEFT", info.title, "BOTTOMLEFT", 0, -10 + TEXT_TOP)
  else
    -- Cartão estreito: a dica fica embaixo do título.
    RightSlot(info)
    info.hint:SetPoint("TOPLEFT", info.title, "BOTTOMLEFT", 0, -4)
    info.hint:SetPoint("RIGHT", -PAD, 0)
    info.holder.scroll:SetPoint("TOPLEFT", info.hint, "BOTTOMLEFT", 0, -8 + TEXT_TOP)
  end
  info.holder.scroll:SetPoint("BOTTOMRIGHT", -PAD - SCROLLBAR_W, PAD)
  self.info = info

  -- Links: o jogo não copia sozinho para a área de transferência, então o
  -- clique põe o link numa caixa já selecionada para o Ctrl+C.
  self.hyperlinks = info.holder.SetHyperlinksEnabled ~= nil
  for _, holder in ipairs({ motd.holder, info.holder }) do
    if holder.SetHyperlinksEnabled then holder:SetHyperlinksEnabled(true) end
    holder:SetScript("OnHyperlinkClick", function(_, link)
      local url = string.match(link or "", "^" .. LINK_TYPE .. ":(.+)$")
      if url then self:ShowCopy(url) end
    end)
    holder:SetScript("OnHyperlinkEnter", function(h)
      GameTooltip:SetOwner(h, "ANCHOR_CURSOR")
      GameTooltip:SetText(L["Clique para copiar o link"])
      GameTooltip:Show()
    end)
    holder:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
  end

  -- O Grão Lorde e os Lordes editam clicando no texto: na janela da guilda,
  -- abre a edição; na janela do addon, abre a janela da guilda.
  local mode = compact and "edit" or "open"
  ns.GuildTextEdit.Attach(motd, motd.holder, "motd", mode)
  ns.GuildTextEdit.Attach(info, info.holder, "info", mode)

  -- Caixa de cópia por cima do texto, no pé do cartão. Fecha ao clicar fora
  -- dela (a caixa perde o foco), com Esc ou Enter.
  local copy = CreateFrame("Frame", nil, info, "BackdropTemplate")
  copy:SetPoint("BOTTOMLEFT", 8, 8)
  copy:SetPoint("BOTTOMRIGHT", -8, 8)
  copy:SetHeight(70)
  copy:SetFrameLevel((info:GetFrameLevel() or 0) + 20)
  copy:EnableMouse(true)
  Theme.Backdrop(copy, "surfaceRaised", "gold")
  local copyLabel = Theme.Text(copy, "small", "textMuted")
  copyLabel:SetPoint("TOPLEFT", 10, -10)
  copyLabel:SetText(L["Link selecionado: pressione Ctrl+C para copiar"])
  local box = CreateFrame("Frame", nil, copy, "BackdropTemplate")
  box:SetPoint("TOPLEFT", copyLabel, "BOTTOMLEFT", 0, -4)
  box:SetPoint("RIGHT", -10, 0)
  box:SetHeight(30)
  Theme.Backdrop(box, "bgDeep", "borderField")
  local edit = CreateFrame("EditBox", nil, box)
  edit:SetPoint("TOPLEFT", 8, -4)
  edit:SetPoint("BOTTOMRIGHT", -8, 4)
  edit:SetAutoFocus(false)
  edit:SetFontObject(Theme.Font("body"))
  edit:SetTextColor(unpack(Theme.colors.text))
  -- Somente leitura: qualquer edição volta ao link selecionado.
  edit:SetScript("OnTextChanged", function(e, userInput)
    if userInput then
      e:SetText(copy.url or "")
      e:HighlightText()
    end
  end)
  edit:SetScript("OnEditFocusGained", function(e) e:HighlightText() end)
  edit:SetScript("OnMouseUp", function(e) e:HighlightText() end)
  edit:SetScript("OnEditFocusLost", function()
    if self.hyperlinks then copy:Hide() end
  end)
  copy:SetScript("OnEvent", function()
    if not copy:IsMouseOver() then
      edit:ClearFocus()
      copy:Hide()
    end
  end)
  copy:SetScript("OnHide", function() copy:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)
  edit:SetScript("OnEscapePressed", function(e) e:ClearFocus() end)
  edit:SetScript("OnEnterPressed", function(e) e:ClearFocus() end)
  copy.edit = edit
  copy:Hide()
  self.copy = copy

  -- Próximo evento
  local nextEvent = Card(frame, L["Próximo evento"])
  Theme.PixelPoint(nextEvent, "TOPRIGHT", frame, "TOPRIGHT")
  Theme.PixelSize(nextEvent, RIGHT_W, nextH)
  nextEvent.name = Theme.Text(nextEvent, "bodyStrong", "heading")
  nextEvent.name:SetPoint("TOPLEFT", nextEvent.title, "BOTTOMLEFT", 0, -10)
  nextEvent.name:SetPoint("RIGHT", -PAD, 0)
  nextEvent.when = Theme.Text(nextEvent, "body")
  nextEvent.when:SetPoint("TOPLEFT", nextEvent.name, "BOTTOMLEFT", 0, -6)
  nextEvent.when:SetPoint("RIGHT", -PAD, 0)
  nextEvent.attendance = Theme.Text(nextEvent, "small", "textMuted")
  nextEvent.attendance:SetPoint("TOPLEFT", nextEvent.when, "BOTTOMLEFT", 0, -6)
  nextEvent.attendance:SetPoint("RIGHT", -PAD, 0)
  nextEvent.open = Theme.Button(nextEvent, L["Ver no calendário"], "primary", RIGHT_W - 2 * PAD)
  nextEvent.open:SetPoint("BOTTOMLEFT", PAD, PAD)
  nextEvent.open:SetScript("OnClick", function()
    if nextEvent.event and onOpenEvent then onOpenEvent(nextEvent.event) end
  end)
  self.nextEvent = nextEvent

  -- Guilda
  local guild = Card(frame, L["Guilda"])
  local guildW, guildH
  if compact then guildW, guildH = RightSlot(guild) else guildW, guildH = BigSlot(guild) end
  guild.counts = Theme.Text(guild, "body")
  guild.counts:SetPoint("TOPLEFT", guild.title, "BOTTOMLEFT", 0, -10)
  guild.player = Theme.Text(guild, "body")
  guild.player:SetPoint("TOPLEFT", guild.counts, "BOTTOMLEFT", 0, -6)
  guild.player:SetPoint("RIGHT", -PAD, 0)

  -- Ranking: quantas linhas couberem no cartão (até 10).
  local rankCount = math.max(0, math.min(RANK_MAX, math.floor((guildH - RANK_HEADER_H) / RANK_LINE_H)))
  self.guild = guild
  BuildRanking(self, guild, guildW - 2 * PAD, rankCount)

  return self
end

ns.HomePanel = HomePanel
