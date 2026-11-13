-- Painel Início da janela do addon: mensagem do dia e informações da guilda
-- (com os links clicáveis para copiar), próximo evento e membros online.
local _, ns = ...

local L = ns.L

local Theme, Text, Time = ns.Theme, ns.Text, ns.Time
local HomePanel = {}

local LINK_TYPE = "vdlurl"
local RIGHT_W = 320
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

  -- Quem mais joga com a guilda (só quem ainda está na guilda)
  local lines = self.guild.rankLines
  if #lines > 0 then
    local inGuild = {}
    for _, entry in ipairs(ns.Flavor.GuildRoster()) do inGuild[entry.name] = true end
    local totals = {}
    for person, seconds in pairs(ns.GuildTogether.Totals()) do
      if inGuild[person] then totals[person] = seconds end
    end
    local ranking = ns.Together.Ranking(totals, #lines)
    local _, mine = ns.GuildTogether.PersonTotal(ns.Guild.PlayerName() or "")
    for i, line in ipairs(lines) do
      local item = ranking[i]
      if item then
        local name = Text.Escape(item.name)
        if item.name == mine then name = Theme.Code("goldLight") .. name .. "|r" end
        line.name:SetText(i .. ".  " .. name)
        line.time:SetText(Theme.Code("gold") .. ns.Together.Format(item.seconds) .. "|r")
      elseif i == 1 then
        line.name:SetText(Theme.Code("textMuted") .. L["Ninguém ainda."] .. "|r")
        line.time:SetText("")
      else
        line.name:SetText("")
        line.time:SetText("")
      end
    end
  end
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
  motd:SetPoint("TOPLEFT")
  motd:SetSize(leftW, 140)
  motd.holder = LinkedText(motd)
  motd.holder.scroll:SetPoint("TOPLEFT", motd.title, "BOTTOMLEFT", 0, -10 + TEXT_TOP)
  motd.holder.scroll:SetPoint("BOTTOMRIGHT", -PAD - SCROLLBAR_W, PAD)
  self.motd = motd

  -- Informações da guilda
  local info = Card(frame, L["Informações da guilda"])
  info:SetPoint("TOPLEFT", motd, "BOTTOMLEFT", 0, -GAP)
  info:SetSize(leftW, height - 140 - GAP)
  info.hint = Theme.Text(info, "small", "textMuted")
  info.hint:SetPoint("TOPRIGHT", -PAD, -18)
  info.hint:SetText(L["Clique num link para copiar"])
  info.holder = LinkedText(info)
  info.holder.scroll:SetPoint("TOPLEFT", info.title, "BOTTOMLEFT", 0, -10 + TEXT_TOP)
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
  nextEvent:SetPoint("TOPRIGHT")
  nextEvent:SetSize(RIGHT_W, 200)
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
  guild:SetPoint("TOPRIGHT", nextEvent, "BOTTOMRIGHT", 0, -GAP)
  guild:SetSize(RIGHT_W, height - 200 - GAP)
  guild.counts = Theme.Text(guild, "body")
  guild.counts:SetPoint("TOPLEFT", guild.title, "BOTTOMLEFT", 0, -10)
  guild.player = Theme.Text(guild, "body")
  guild.player:SetPoint("TOPLEFT", guild.counts, "BOTTOMLEFT", 0, -6)
  guild.player:SetPoint("RIGHT", -PAD, 0)

  -- Ranking do tempo com a guilda: quantas linhas couberem no cartão (até 5).
  guild.rankLines = {}
  local rankCount = math.max(0, math.min(5, math.floor((height - 200 - GAP - 132) / 20)))
  if rankCount > 0 then
    local rankTitle = Theme.Text(guild, "smallStrong", "goldDeep")
    rankTitle:SetPoint("TOPLEFT", guild.player, "BOTTOMLEFT", 0, -14)
    rankTitle:SetText(L["MAIS TEMPO JOGANDO COM A GUILDA"])
    local previous = rankTitle
    for i = 1, rankCount do
      local name = Theme.Text(guild, "body")
      name:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, i == 1 and -6 or -2)
      name:SetPoint("RIGHT", -PAD - 90, 0)
      name:SetWordWrap(false)
      local time = Theme.Text(guild, "body")
      time:SetPoint("TOP", name, "TOP")
      time:SetPoint("RIGHT", -PAD, 0)
      time:SetJustifyH("RIGHT")
      guild.rankLines[i] = { name = name, time = time }
      previous = name
    end
  end
  self.guild = guild

  return self
end

ns.HomePanel = HomePanel
