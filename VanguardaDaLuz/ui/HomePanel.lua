-- Painel Início da janela do addon: mensagem do dia e informações da guilda
-- (com os links clicáveis para copiar), próximo evento e membros online.
local _, ns = ...

local Theme, Text, Time = ns.Theme, ns.Text, ns.Time
local HomePanel = {}

local LINK_TYPE = "vdlurl"
local RIGHT_W = 320
local GAP = 16
local PAD = 16

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
  copy.edit:SetFocus()
  copy.edit:HighlightText()
end

-- Texto com os links clicáveis num quadro com hyperlinks.
local function SetLinkedText(holder, raw)
  local text = raw ~= "" and raw or nil
  if not text then
    holder.text:SetText(Theme.Code("textMuted") .. "Nada definido.|r")
    return {}
  end
  holder.text:SetText(Text.Linkify(text, LINK_TYPE, Theme.Code("azure")))
  return Text.FindLinks(text)
end

function Panel:Refresh()
  SetLinkedText(self.motd.holder, ns.Guild.Motd())
  local links = SetLinkedText(self.info.holder, ns.Guild.InfoText())
  -- Ajuda e caixa de cópia: sem suporte a hyperlinks, a caixa já mostra o primeiro link.
  self.info.hint:SetShown(#links > 0 and self.hyperlinks)
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
      .. Time.FormatClock(event.startsAt, offset) .. " (Brasília)")
    local confirmed = #ns.Presence.Confirmed(event.id)
    local mine = ns.Presence.Status(event.id) == 1
    n.attendance:SetText(string.format("%d confirmado(s) no jogo", confirmed)
      .. (mine and (Theme.Code("success") .. "  ·  você vai|r") or ""))
    n.open:Show()
  else
    n.name:SetText(Theme.Code("textMuted") .. "Nenhum evento marcado.|r")
    n.when:SetText("")
    n.attendance:SetText("")
    n.open:Hide()
  end

  -- Guilda
  local total, online = ns.Guild.Counts()
  self.guild.counts:SetText(string.format("%d membro(s)  ·  %s%d online|r",
    total, Theme.Code("success"), online))
  self.guild.player:SetText(Theme.Code("textMuted") .. "Jogando com|r " .. Text.Escape(ns.Guild.PlayerName() or "?"))
end

local function LinkedText(parent)
  local holder = CreateFrame("Frame", nil, parent)
  local text = Theme.Text(holder, "body")
  text:SetPoint("TOPLEFT")
  text:SetPoint("TOPRIGHT")
  text:SetSpacing(3)
  holder.text = text
  return holder
end

-- Cria o painel dentro de `parent`, com `width` x `height`. `onOpenEvent(event)`
-- é chamado pelo botão "Ver no calendário".
function HomePanel.Create(parent, width, height, onOpenEvent)
  local self = setmetatable({}, Panel)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetSize(width, height)
  self.frame = frame
  local leftW = width - RIGHT_W - GAP

  -- Mensagem do dia
  local motd = Card(frame, "Mensagem do dia")
  motd:SetPoint("TOPLEFT")
  motd:SetSize(leftW, 140)
  motd.holder = LinkedText(motd)
  motd.holder:SetPoint("TOPLEFT", motd.title, "BOTTOMLEFT", 0, -10)
  motd.holder:SetPoint("BOTTOMRIGHT", -PAD, PAD)
  self.motd = motd

  -- Informações da guilda
  local info = Card(frame, "Informações da guilda")
  info:SetPoint("TOPLEFT", motd, "BOTTOMLEFT", 0, -GAP)
  info:SetSize(leftW, height - 140 - GAP)
  info.hint = Theme.Text(info, "small", "textMuted")
  info.hint:SetPoint("TOPRIGHT", -PAD, -18)
  info.hint:SetText("Clique num link para copiar")
  info.holder = LinkedText(info)
  info.holder:SetPoint("TOPLEFT", info.title, "BOTTOMLEFT", 0, -10)
  info.holder:SetPoint("BOTTOMRIGHT", -PAD, PAD + 64)
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
      GameTooltip:SetText("Clique para copiar o link")
      GameTooltip:Show()
    end)
    holder:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
  end

  local copy = CreateFrame("Frame", nil, info)
  copy:SetPoint("BOTTOMLEFT", PAD, PAD)
  copy:SetPoint("BOTTOMRIGHT", -PAD, PAD)
  copy:SetHeight(52)
  local copyLabel = Theme.Text(copy, "small", "textMuted")
  copyLabel:SetPoint("TOPLEFT")
  copyLabel:SetText("Link selecionado: pressione Ctrl+C para copiar")
  local box = CreateFrame("Frame", nil, copy, "BackdropTemplate")
  box:SetPoint("TOPLEFT", copyLabel, "BOTTOMLEFT", 0, -4)
  box:SetPoint("RIGHT")
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
  edit:SetScript("OnEscapePressed", function(e) e:ClearFocus() end)
  edit:SetScript("OnEnterPressed", function(e) e:ClearFocus() end)
  copy.edit = edit
  copy:Hide()
  self.copy = copy

  -- Próximo evento
  local nextEvent = Card(frame, "Próximo evento")
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
  nextEvent.open = Theme.Button(nextEvent, "Ver no calendário", "primary", RIGHT_W - 2 * PAD)
  nextEvent.open:SetPoint("BOTTOMLEFT", PAD, PAD)
  nextEvent.open:SetScript("OnClick", function()
    if nextEvent.event and onOpenEvent then onOpenEvent(nextEvent.event) end
  end)
  self.nextEvent = nextEvent

  -- Guilda
  local guild = Card(frame, "Guilda")
  guild:SetPoint("TOPRIGHT", nextEvent, "BOTTOMRIGHT", 0, -GAP)
  guild:SetSize(RIGHT_W, height - 200 - GAP)
  guild.counts = Theme.Text(guild, "body")
  guild.counts:SetPoint("TOPLEFT", guild.title, "BOTTOMLEFT", 0, -10)
  guild.player = Theme.Text(guild, "body")
  guild.player:SetPoint("TOPLEFT", guild.counts, "BOTTOMLEFT", 0, -6)
  guild.player:SetPoint("RIGHT", -PAD, 0)
  self.guild = guild

  return self
end

ns.HomePanel = HomePanel
