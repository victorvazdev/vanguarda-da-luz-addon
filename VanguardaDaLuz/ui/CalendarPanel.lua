-- Painel do calendário: grade do mês, eventos do dia e detalhe do evento com a
-- presença. Usado na janela do addon (layout "wide") e na aba Eventos da
-- janela da guilda ("compact"). Datas no horário de Brasília; o horário do
-- servidor aparece quando é outro.
local _, ns = ...

local Theme, Time, Text = ns.Theme, ns.Time, ns.Text
local CalendarPanel = {}

local LAYOUTS = {
  -- Janela do addon: células com os títulos dos eventos.
  wide = { cellW = 76, cellH = 66, gap = 4, gridTop = 60, labels = 2, sideGap = 16,
    cardPad = 16, rowH = 26, rowStep = 30 },
  -- Janela da guilda: células com o número do dia e a quantidade de eventos.
  compact = { cellW = 42, cellH = 46, gap = 2, gridTop = 50, labels = 0, sideGap = 12,
    cardPad = 10, rowH = 22, rowStep = 25 },
}
local MAX_DAY_EVENTS = 6

local function Brasilia() return ns.Config.BRASILIA_OFFSET end

local function Today()
  local f = Time.Fields(GetServerTime(), Brasilia())
  return f.year, f.month, f.day
end

local function StatusColor(event)
  return event.status == "cancelado" and "cancel" or "gold"
end

-- Linha de horários: Brasília e, se diferente, o servidor.
local function TimesLine(event)
  local brasilia = Time.FormatClock(event.startsAt, Brasilia()) .. " (Brasília)"
  local offset = Time.ServerOffset(C_DateAndTime.GetCurrentCalendarTime(), GetServerTime())
  if offset == Brasilia() then return brasilia end
  local f = Time.Fields(event.startsAt, offset)
  local b = Time.Fields(event.startsAt, Brasilia())
  local server = Time.FormatClock(event.startsAt, offset)
  if f.day ~= b.day then server = string.format("%02d/%02d ", f.day, f.month) .. server end
  return brasilia .. "  ·  " .. server .. " (servidor, " .. Time.FormatOffset(offset) .. ")"
end

-- Linha da última exportação recebida (usada pelas janelas que mostram o painel).
function CalendarPanel.InfoLine()
  local export = ns.db.export
  if not export then
    return "Nenhuma exportação recebida ainda. Os eventos chegam do Grão Lorde ou de um Lorde da guilda."
  end
  local generated = Time.FormatDateTime(export.exportNumber, Brasilia())
  local received = Time.FormatDateTime(export.receivedAt, Brasilia())
  local from = export.source == "guild" and export.sender
    and (" de " .. Ambiguate(export.sender, "short")) or " por importação"
  return "Gerado no site em " .. generated .. "  ·  Recebido em " .. received .. from
end

local Panel = {}
Panel.__index = Panel

---------------------------------------------------------------------------
-- Detalhe do evento
---------------------------------------------------------------------------

-- Lista de presença do jogo e botão de confirmar/cancelar.
function Panel:ShowAttendance(event)
  local d, L = self.detail, self.layout
  local names = ns.Presence.Confirmed(event.id)
  local escaped = {}
  for i, name in ipairs(names) do escaped[i] = Text.Escape(name) end
  local line = Theme.Code("textMuted") .. "Confirmados no jogo (" .. #names .. "):|r "
  d.attendance:SetText(line .. (#names > 0 and table.concat(escaped, ", ") or "ninguém ainda"))
  local open = ns.Presence.IsOpen(event)
  d.attend:SetShown(open)
  -- Sem botão, a área com rolagem desce até o pé do cartão.
  d.body:SetPoint("BOTTOMRIGHT", -L.cardPad - 18, open and (L.cardPad + 28 + 10) or L.cardPad)
  if open then
    d.attend.eventId = event.id
    d.attend:SetText(ns.Presence.Status(event.id) == 1 and "Cancelar presença" or "Confirmar presença")
  end
end

function Panel:ShowDetail(event)
  local d = self.detail
  if not event then return end
  d.title:SetText(Text.Escape(event.title))
  d.title:SetTextColor(unpack(Theme.colors[event.status == "cancelado" and "cancel" or "heading"]))
  if event.status == "cancelado" then
    d.status:SetText(Theme.Code("cancel") .. "CANCELADO|r")
  else
    d.status:SetText(Theme.Code("success") .. "ATIVO|r")
  end
  d.when:SetText(Time.FormatLongDate(event.startsAt, Brasilia()) .. "\n" .. TimesLine(event))
  d.organizer:SetText(Text.Escape(event.organizer))
  self:ShowAttendance(event)
  local description = Text.Escape(event.description or "")
  d.description:SetText(description ~= "" and description
    or (Theme.Code("textMuted") .. "Sem descrição.|r"))
  d.body:Layout()
end

---------------------------------------------------------------------------
-- Lista de eventos do dia
---------------------------------------------------------------------------

function Panel:RenderDay()
  local s, L = self.selected, self.layout
  local list = ns.Store.EventsOn(s.year, s.month, s.day)
  local ts = Time.FromFields(s.year, s.month, s.day, 12, 0, Brasilia())
  self.dayTitle:SetText(Time.FormatLongDate(ts, Brasilia()))

  local chosen
  for i = 1, MAX_DAY_EVENTS do
    local button, event = self.eventButtons[i], list[i]
    if event then
      button.event = event
      button.time:SetText(Time.FormatClock(event.startsAt, Brasilia()))
      button.name:SetText(Text.Escape(event.title))
      button.name:SetTextColor(unpack(Theme.colors[event.status == "cancelado" and "cancel" or "text"]))
      button.badge:SetText(event.status == "cancelado" and "Cancelado" or "")
      local isSelected = s.eventId == event.id
      Theme.Backdrop(button, isSelected and "surfaceRaised" or "surface", isSelected and "gold" or "border")
      if isSelected then chosen = event end
      button:Show()
    else
      button.event = nil
      button:Hide()
    end
  end
  if not chosen and list[1] then
    chosen = list[1]
    s.eventId = chosen.id
    Theme.Backdrop(self.eventButtons[1], "surfaceRaised", "gold")
  end
  self.noEvents:SetShown(#list == 0)
  -- O cartão do dia só ocupa a altura dos eventos que o dia tem.
  local rows = math.min(#list, MAX_DAY_EVENTS)
  local top = L.cardPad + 30
  self.dayCard:SetHeight(top + (rows > 0 and rows * L.rowStep or 20) + L.cardPad - 4)
  self.detail:SetShown(chosen ~= nil)
  self:ShowDetail(chosen)
end

---------------------------------------------------------------------------
-- Grade do mês
---------------------------------------------------------------------------

function Panel:RenderMonth()
  local v, s, L = self.view, self.selected, self.layout
  local monthName = string.gsub(Time.MONTHS[v.month], "^%l", string.upper)
  self.monthTitle:SetText(monthName .. " de " .. v.year)
  local first = Time.FirstWeekday(v.year, v.month)
  local days = Time.DaysInMonth(v.year, v.month)
  local ty, tm, td = Today()

  for i, cell in ipairs(self.cells) do
    local day = i - first + 1
    if day >= 1 and day <= days then
      cell.day = day
      cell.number:SetText(day)
      local events = ns.Store.EventsOn(v.year, v.month, day)
      for k = 1, L.labels do
        local label, event = cell.labels[k], events[k]
        if event then
          label:SetText(Text.Escape(event.title))
          label:SetTextColor(unpack(Theme.colors[StatusColor(event)]))
        else
          label:SetText("")
        end
      end
      local hidden = #events - L.labels
      if L.labels == 0 then
        cell.more:SetText(#events > 1 and ("×" .. #events) or "")
      else
        cell.more:SetText(hidden > 0 and ("+" .. hidden) or "")
      end
      local isToday = v.year == ty and v.month == tm and day == td
      local isSelected = v.year == s.year and v.month == s.month and day == s.day
      local bg = (#events > 0) and "surfaceRaised" or "surface"
      Theme.Backdrop(cell, isSelected and "azureDeep" or bg,
        isSelected and "azure" or (isToday and "gold" or "border"))
      cell.number:SetTextColor(unpack(Theme.colors[isToday and "gold" or "textMuted"]))
      cell.marker:SetShown(#events > 0)
      cell:Enable()
      cell:SetAlpha(1)
    else
      cell.day = nil
      cell.number:SetText("")
      for k = 1, L.labels do cell.labels[k]:SetText("") end
      cell.more:SetText("")
      cell.marker:Hide()
      Theme.Backdrop(cell, "bgDeep", "bgDeep")
      cell:Disable()
    end
  end
end

function Panel:Refresh()
  if not self.view.year then
    self.view.year, self.view.month = Today()
    self.selected.year, self.selected.month, self.selected.day = Today()
  end
  self:RenderMonth()
  self:RenderDay()
end

function Panel:SelectDay(day)
  local s, v = self.selected, self.view
  s.year, s.month, s.day, s.eventId = v.year, v.month, day, nil
  self:Refresh()
end

-- Mostra um dia (e, opcionalmente, um evento dele).
function Panel:ShowDate(year, month, day, eventId)
  self.view.year, self.view.month = year, month
  local s = self.selected
  s.year, s.month, s.day, s.eventId = year, month, day, eventId
  self:Refresh()
end

function Panel:ChangeMonth(delta)
  self.view.year, self.view.month = Time.AddMonths(self.view.year, self.view.month, delta)
  self:Refresh()
end

---------------------------------------------------------------------------
-- Construção
---------------------------------------------------------------------------

-- Corpo do detalhe com rolagem: seções empilhadas, cada uma com rótulo e texto.
-- body:Layout() recalcula a altura depois de trocar os textos.
local function DetailBody(parent)
  local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  local child = CreateFrame("Frame", nil, scroll)
  child:SetSize(1, 1)
  scroll:SetScrollChild(child)

  local strings, values = {}, {}
  local previous
  function scroll.Add(labelText)
    local label = Theme.Text(child, "smallStrong", "goldDeep")
    label:SetText(labelText)
    if previous then
      label:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -12)
    else
      label:SetPoint("TOPLEFT")
    end
    local value = Theme.Text(child, "body")
    value:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
    strings[#strings + 1], strings[#strings + 2] = label, value
    values[#values + 1] = value
    previous = value
    return value
  end

  scroll:SetScript("OnSizeChanged", function(self, w)
    child:SetWidth(w)
    for _, fs in ipairs(strings) do fs:SetWidth(w) end
    self:Layout()
  end)
  function scroll:Layout()
    local height = 0
    for _, fs in ipairs(strings) do height = height + (fs:GetStringHeight() or 0) end
    child:SetHeight(height + #values * 4 + (#values - 1) * 12 + 4)
    self:SetVerticalScroll(0)
  end
  return scroll
end

function Panel:BuildGrid(gridW, gridH)
  local L = self.layout
  local grid = CreateFrame("Frame", nil, self.frame)
  grid:SetSize(gridW, gridH)
  grid:SetPoint("TOPLEFT")

  local prev = Theme.Button(grid, "‹", "outline", 32)
  prev:SetPoint("TOPLEFT")
  prev:SetScript("OnClick", function() self:ChangeMonth(-1) end)
  local nextButton = Theme.Button(grid, "›", "outline", 32)
  nextButton:SetPoint("TOPRIGHT")
  nextButton:SetScript("OnClick", function() self:ChangeMonth(1) end)
  local todayButton = Theme.Button(grid, "Hoje", "ghost", L.labels > 0 and 60 or 48)
  todayButton:SetPoint("RIGHT", nextButton, "LEFT", -6, 0)
  todayButton:SetScript("OnClick", function()
    self.view.year, self.view.month = Today()
    local _, _, d = Today()
    self:SelectDay(d)
  end)
  local monthTitle = Theme.Text(grid, "heading", "gold")
  monthTitle:SetPoint("LEFT", prev, "RIGHT", 8, 0)
  monthTitle:SetPoint("RIGHT", todayButton, "LEFT", -6, 0)
  monthTitle:SetJustifyH("CENTER")
  monthTitle:SetWordWrap(false)
  self.monthTitle = monthTitle

  for i = 1, 7 do
    local label = Theme.Text(grid, "smallStrong", "textMuted")
    label:SetWidth(L.cellW)
    label:SetJustifyH("CENTER")
    label:SetPoint("TOPLEFT", (i - 1) * (L.cellW + L.gap), -(L.gridTop - 20))
    label:SetText(Time.WEEKDAYS_SHORT[i])
  end

  for i = 1, 42 do
    local col, row = (i - 1) % 7, math.floor((i - 1) / 7)
    local cell = CreateFrame("Button", nil, grid, "BackdropTemplate")
    cell:SetSize(L.cellW, L.cellH)
    cell:SetPoint("TOPLEFT", col * (L.cellW + L.gap), -L.gridTop - row * (L.cellH + L.gap))
    cell.number = Theme.Text(cell, "day")
    cell.number:SetPoint("TOPLEFT", 5, -4)
    cell.marker = cell:CreateTexture(nil, "OVERLAY")
    cell.marker:SetSize(6, 6)
    cell.marker:SetPoint("TOPRIGHT", -5, -7)
    cell.marker:SetColorTexture(unpack(Theme.colors.gold))
    cell.more = Theme.Text(cell, "small", "textMuted")
    if L.labels > 0 then
      cell.more:SetPoint("RIGHT", cell.marker, "LEFT", -4, 0)
    else
      cell.more:SetPoint("BOTTOMRIGHT", -4, 4)
    end
    cell.labels = {}
    for k = 1, L.labels do
      local label = Theme.Text(cell, "small")
      label:SetPoint("TOPLEFT", 6, -7 - k * 15)
      label:SetPoint("RIGHT", -4, 0)
      label:SetWordWrap(false)
      label:SetHeight(14)
      cell.labels[k] = label
    end
    cell:SetScript("OnClick", function(c) if c.day then self:SelectDay(c.day) end end)
    self.cells[i] = cell
  end
  return grid
end

function Panel:BuildSide(grid, sideW, height)
  local L = self.layout
  local side = CreateFrame("Frame", nil, self.frame)
  side:SetSize(sideW, height)
  side:SetPoint("TOPLEFT", grid, "TOPRIGHT", L.sideGap, 0)

  local dayCard = CreateFrame("Frame", nil, side, "BackdropTemplate")
  dayCard:SetPoint("TOPLEFT")
  dayCard:SetPoint("TOPRIGHT")
  dayCard:SetHeight(70)
  Theme.Backdrop(dayCard, "surface", "border")
  self.dayCard = dayCard

  local dayTitle = Theme.Text(dayCard, "heading", "heading")
  dayTitle:SetPoint("TOPLEFT", L.cardPad, -L.cardPad + 2)
  dayTitle:SetPoint("TOPRIGHT", -L.cardPad, -L.cardPad + 2)
  dayTitle:SetWordWrap(false)
  self.dayTitle = dayTitle

  local top = L.cardPad + 30
  local noEvents = Theme.Text(dayCard, "body", "textMuted")
  noEvents:SetPoint("TOPLEFT", L.cardPad, -top)
  noEvents:SetText("Nenhum evento neste dia.")
  self.noEvents = noEvents

  for i = 1, MAX_DAY_EVENTS do
    local button = CreateFrame("Button", nil, dayCard, "BackdropTemplate")
    button:SetHeight(L.rowH)
    button:SetPoint("TOPLEFT", L.cardPad - 4, -top - (i - 1) * L.rowStep)
    button:SetPoint("RIGHT", -(L.cardPad - 4), 0)
    button.time = Theme.Text(button, "smallStrong", "gold")
    button.time:SetPoint("LEFT", 8, 0)
    button.badge = Theme.Text(button, "small", "cancel")
    button.badge:SetPoint("RIGHT", -8, 0)
    button.name = Theme.Text(button, "body")
    button.name:SetPoint("LEFT", 52, 0)
    button.name:SetPoint("RIGHT", button.badge, "LEFT", -6, 0)
    button.name:SetWordWrap(false)
    button:SetScript("OnClick", function(b)
      self.selected.eventId = b.event and b.event.id
      self:RenderDay()
    end)
    button:Hide()
    self.eventButtons[i] = button
  end

  local detail = CreateFrame("Frame", nil, side, "BackdropTemplate")
  detail:SetPoint("TOPLEFT", dayCard, "BOTTOMLEFT", 0, -10)
  detail:SetPoint("BOTTOMRIGHT")
  Theme.Backdrop(detail, "surface", "border")
  self.detail = detail

  detail.status = Theme.Text(detail, "smallStrong")
  detail.status:SetPoint("TOPRIGHT", -L.cardPad, -L.cardPad - 1)
  detail.title = Theme.Text(detail, "heading", "heading")
  detail.title:SetPoint("TOPLEFT", L.cardPad, -L.cardPad + 2)
  detail.title:SetPoint("RIGHT", detail.status, "LEFT", -10, 0)
  local line = Theme.Divider(detail)
  line:SetPoint("TOPLEFT", detail.title, "BOTTOMLEFT", 0, -8)
  line:SetPoint("RIGHT", -L.cardPad, 0)

  local body = DetailBody(detail)
  body:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -10)
  body:SetPoint("BOTTOMRIGHT", -L.cardPad - 18, L.cardPad)
  detail.body = body
  detail.when = body.Add("QUANDO")
  detail.organizer = body.Add("ORGANIZADOR")
  detail.attendance = body.Add("PRESENÇA")
  detail.description = body.Add("DESCRIÇÃO")

  detail.attend = Theme.Button(detail, "Confirmar presença", "primary", 170)
  detail.attend:SetPoint("BOTTOMLEFT", L.cardPad, L.cardPad)
  detail.attend:SetScript("OnClick", function(b)
    local ok, err = ns.Presence.Toggle(b.eventId)
    if not ok then ns.Print(err) end
  end)
end

-- Cria o painel dentro de `parent`, com a largura `width` e o layout "wide" ou
-- "compact". A altura vem do layout (panel.height); `height` (opcional) ajusta
-- a altura das células ao espaço disponível. Quem usa o painel chama
-- panel:Refresh() quando ele está visível.
function CalendarPanel.Create(parent, width, layoutName, height)
  local L = {}
  for k, v in pairs(LAYOUTS[layoutName or "wide"]) do L[k] = v end
  local fit = height and math.floor((height - L.gridTop - 5 * L.gap) / 6)
  if layoutName == "compact" then
    -- Metade da largura para a grade, e a altura disponível para as linhas.
    L.cellW = math.max(L.cellW, math.floor((width * 0.5 - 6 * L.gap) / 7))
    if fit then L.cellH = math.max(L.cellH, fit) end
  elseif fit then
    L.cellH = fit
  end
  local self = setmetatable({
    layout = L, view = {}, selected = {}, cells = {}, eventButtons = {},
  }, Panel)
  local gridW = 7 * L.cellW + 6 * L.gap
  height = L.gridTop + 6 * L.cellH + 5 * L.gap
  self.height = height
  self.frame = CreateFrame("Frame", nil, parent)
  self.frame:SetSize(width, height)
  local grid = self:BuildGrid(gridW, height)
  self:BuildSide(grid, width - gridW - L.sideGap, height)
  return self
end

ns.CalendarPanel = CalendarPanel
