-- Janela principal: calendário mensal, eventos do dia e detalhe do evento.
-- Datas no horário de Brasília; o horário do servidor aparece quando é outro.
local _, ns = ...

local Theme, Time, Text = ns.Theme, ns.Time, ns.Text
local MainFrame = {}

local WIDTH, HEIGHT = 820, 560
local CELL_W, CELL_H, GAP = 66, 58, 2
local MAX_DAY_LABELS = 2
local MAX_DAY_EVENTS = 6

local frame
local view = {}      -- { year, month } exibido
local selected = {}  -- { year, month, day, eventId }
local cells = {}
local eventButtons = {}

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

local function InfoLine()
  local export = ns.db.export
  if not export then
    return "Nenhuma exportação recebida ainda. Os eventos chegam do Grão Lorde ou de um Lorde da guilda."
  end
  local generated = Time.FormatDateTime(export.exportNumber, Brasilia())
  local received = Time.FormatDateTime(export.receivedAt, Brasilia())
  local from = export.source == "guild" and export.sender
    and (" de " .. Ambiguate(export.sender, "short")) or " por importação"
  return "Gerado no site em " .. generated .. "  ·  Recebido em " .. received .. from
    .. "  ·  Horários de Brasília"
end

---------------------------------------------------------------------------
-- Detalhe do evento
---------------------------------------------------------------------------

local function ShowDetail(event)
  local d = frame.detail
  if not event then
    d.title:SetText("")
    d.status:SetText("")
    d.when:SetText("")
    d.organizer:SetText("")
    d.description:SetText("")
    return
  end
  d.title:SetText(Text.Escape(event.title))
  d.title:SetTextColor(unpack(Theme.colors[event.status == "cancelado" and "cancel" or "heading"]))
  if event.status == "cancelado" then
    d.status:SetText(Theme.Code("cancel") .. "CANCELADO|r")
  else
    d.status:SetText(Theme.Code("success") .. "Confirmado no site|r")
  end
  d.when:SetText(Time.FormatLongDate(event.startsAt, Brasilia()) .. "\n" .. TimesLine(event))
  d.organizer:SetText(Theme.Code("textMuted") .. "Organizador:|r " .. Text.Escape(event.organizer))
  d.description:SetText(Text.Escape(event.description))
end

---------------------------------------------------------------------------
-- Lista de eventos do dia
---------------------------------------------------------------------------

local function RenderDay()
  local list = ns.Store.EventsOn(selected.year, selected.month, selected.day)
  local y, m, day = selected.year, selected.month, selected.day
  local ts = Time.FromFields(y, m, day, 12, 0, Brasilia())
  frame.dayTitle:SetText(Time.FormatLongDate(ts, Brasilia()))

  local chosen
  for i = 1, MAX_DAY_EVENTS do
    local button, event = eventButtons[i], list[i]
    if event then
      button.event = event
      button.time:SetText(Time.FormatClock(event.startsAt, Brasilia()))
      button.name:SetText(Text.Escape(event.title))
      button.name:SetTextColor(unpack(Theme.colors[event.status == "cancelado" and "cancel" or "text"]))
      button.badge:SetText(event.status == "cancelado" and "Cancelado" or "")
      local isSelected = selected.eventId == event.id
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
    selected.eventId = chosen.id
    Theme.Backdrop(eventButtons[1], "surfaceRaised", "gold")
  end
  frame.noEvents:SetShown(#list == 0)
  frame.detail:SetShown(chosen ~= nil)
  ShowDetail(chosen)
end

---------------------------------------------------------------------------
-- Grade do mês
---------------------------------------------------------------------------

local function RenderMonth()
  local monthName = string.gsub(Time.MONTHS[view.month], "^%l", string.upper)
  frame.monthTitle:SetText(monthName .. " de " .. view.year)
  local first = Time.FirstWeekday(view.year, view.month)
  local days = Time.DaysInMonth(view.year, view.month)
  local ty, tm, td = Today()

  for i, cell in ipairs(cells) do
    local day = i - first + 1
    if day >= 1 and day <= days then
      cell.day = day
      cell.number:SetText(day)
      local events = ns.Store.EventsOn(view.year, view.month, day)
      for k = 1, MAX_DAY_LABELS do
        local label, event = cell.labels[k], events[k]
        if event then
          label:SetText(Text.Escape(event.title))
          label:SetTextColor(unpack(Theme.colors[StatusColor(event)]))
        else
          label:SetText("")
        end
      end
      cell.more:SetText(#events > MAX_DAY_LABELS and ("+" .. (#events - MAX_DAY_LABELS)) or "")
      local isToday = view.year == ty and view.month == tm and day == td
      local isSelected = view.year == selected.year and view.month == selected.month and day == selected.day
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
      for k = 1, MAX_DAY_LABELS do cell.labels[k]:SetText("") end
      cell.more:SetText("")
      cell.marker:Hide()
      Theme.Backdrop(cell, "bgDeep", "bgDeep")
      cell:Disable()
    end
  end
end

function MainFrame.Refresh()
  if not frame or not frame:IsShown() then return end
  frame.info:SetText(InfoLine())
  RenderMonth()
  RenderDay()
  -- O botão Alerta só aparece para os cargos aceitos.
  local trusted = ns.Guild.IsPlayerTrusted()
  frame.alertButton:SetShown(trusted)
  frame.sync:SetPoint("RIGHT", trusted and frame.alertButton or frame.syncButton, "LEFT", -12, 0)
  frame.sync:SetText(Theme.Code("textMuted") .. ns.Comm.Status() .. "|r")
end

local function SelectDay(day)
  selected.year, selected.month, selected.day, selected.eventId = view.year, view.month, day, nil
  MainFrame.Refresh()
end

local function ChangeMonth(delta)
  view.year, view.month = Time.AddMonths(view.year, view.month, delta)
  MainFrame.Refresh()
end

---------------------------------------------------------------------------
-- Construção
---------------------------------------------------------------------------

local function Build()
  frame = Theme.Window("VanguardaDaLuzMainFrame", WIDTH, HEIGHT, "Vanguarda da Luz")
  frame:SetScript("OnShow", MainFrame.Refresh)

  local subtitle = Theme.Text(frame, "small", "textMuted")
  subtitle:SetPoint("TOPLEFT", frame.heading, "BOTTOMLEFT", 0, -2)
  subtitle:SetText("Calendário da guilda  ·  " .. ns.Flavor.label)

  local info = Theme.Text(frame, "small", "textMuted")
  info:SetPoint("TOPLEFT", 16, -66)
  info:SetPoint("TOPRIGHT", -16, -66)
  frame.info = info

  -- Navegação do mês
  local grid = CreateFrame("Frame", nil, frame)
  grid:SetSize(7 * CELL_W + 6 * GAP, 6 * CELL_H + 5 * GAP + 56)
  grid:SetPoint("TOPLEFT", 16, -90)

  local prev = Theme.Button(grid, "‹", "outline", 32)
  prev:SetPoint("TOPLEFT")
  prev:SetScript("OnClick", function() ChangeMonth(-1) end)
  local nextButton = Theme.Button(grid, "›", "outline", 32)
  nextButton:SetPoint("TOPRIGHT")
  nextButton:SetScript("OnClick", function() ChangeMonth(1) end)
  local monthTitle = Theme.Text(grid, "heading", "gold")
  monthTitle:SetPoint("TOP", 0, -6)
  monthTitle:SetJustifyH("CENTER")
  frame.monthTitle = monthTitle
  local todayButton = Theme.Button(grid, "Hoje", "ghost", 56)
  todayButton:SetPoint("RIGHT", nextButton, "LEFT", -6, 0)
  todayButton:SetScript("OnClick", function()
    view.year, view.month = Today()
    local _, _, d = Today()
    SelectDay(d)
  end)

  for i = 1, 7 do
    local label = Theme.Text(grid, "smallStrong", "textMuted")
    label:SetWidth(CELL_W)
    label:SetJustifyH("CENTER")
    label:SetPoint("TOPLEFT", (i - 1) * (CELL_W + GAP), -38)
    label:SetText(Time.WEEKDAYS_SHORT[i])
  end

  for i = 1, 42 do
    local col, row = (i - 1) % 7, math.floor((i - 1) / 7)
    local cell = CreateFrame("Button", nil, grid, "BackdropTemplate")
    cell:SetSize(CELL_W, CELL_H)
    cell:SetPoint("TOPLEFT", col * (CELL_W + GAP), -56 - row * (CELL_H + GAP))
    cell.number = Theme.Text(cell, "day")
    cell.number:SetPoint("TOPLEFT", 4, -3)
    cell.marker = cell:CreateTexture(nil, "OVERLAY")
    cell.marker:SetSize(6, 6)
    cell.marker:SetPoint("TOPRIGHT", -4, -5)
    cell.marker:SetColorTexture(unpack(Theme.colors.gold))
    cell.labels = {}
    for k = 1, MAX_DAY_LABELS do
      local label = Theme.Text(cell, "small")
      label:SetPoint("TOPLEFT", 4, -4 - k * 13)
      label:SetPoint("RIGHT", -3, 0)
      label:SetWordWrap(false)
      label:SetHeight(12)
      cell.labels[k] = label
    end
    cell.more = Theme.Text(cell, "small", "textMuted")
    cell.more:SetPoint("BOTTOMRIGHT", -4, 3)
    cell:SetScript("OnClick", function(self) if self.day then SelectDay(self.day) end end)
    cells[i] = cell
  end

  -- Coluna da direita: eventos do dia e detalhe
  local side = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  side:SetPoint("TOPLEFT", grid, "TOPRIGHT", 14, 0)
  side:SetPoint("BOTTOMRIGHT", -16, 56)
  Theme.Backdrop(side, "surface", "border")

  local dayTitle = Theme.Text(side, "heading", "heading")
  dayTitle:SetPoint("TOPLEFT", 12, -10)
  dayTitle:SetPoint("TOPRIGHT", -12, -10)
  frame.dayTitle = dayTitle

  local noEvents = Theme.Text(side, "body", "textMuted")
  noEvents:SetPoint("TOPLEFT", dayTitle, "BOTTOMLEFT", 0, -10)
  noEvents:SetText("Nenhum evento neste dia.")
  frame.noEvents = noEvents

  for i = 1, MAX_DAY_EVENTS do
    local button = CreateFrame("Button", nil, side, "BackdropTemplate")
    button:SetHeight(24)
    button:SetPoint("TOPLEFT", 10, -34 - (i - 1) * 26)
    button:SetPoint("RIGHT", -10, 0)
    button.time = Theme.Text(button, "smallStrong", "gold")
    button.time:SetPoint("LEFT", 6, 0)
    button.badge = Theme.Text(button, "small", "cancel")
    button.badge:SetPoint("RIGHT", -6, 0)
    button.name = Theme.Text(button, "body")
    button.name:SetPoint("LEFT", 46, 0)
    button.name:SetPoint("RIGHT", button.badge, "LEFT", -4, 0)
    button.name:SetWordWrap(false)
    button:SetScript("OnClick", function(self)
      selected.eventId = self.event and self.event.id
      RenderDay()
    end)
    button:Hide()
    eventButtons[i] = button
  end

  local detail = CreateFrame("Frame", nil, side)
  detail:SetPoint("TOPLEFT", 12, -34 - MAX_DAY_EVENTS * 26 - 8)
  detail:SetPoint("BOTTOMRIGHT", -12, 10)
  frame.detail = detail
  local line = Theme.Divider(detail)
  line:SetPoint("TOPLEFT")
  line:SetPoint("TOPRIGHT")
  detail.title = Theme.Text(detail, "heading", "heading")
  detail.title:SetPoint("TOPLEFT", 0, -10)
  detail.title:SetPoint("RIGHT")
  detail.status = Theme.Text(detail, "smallStrong")
  detail.status:SetPoint("TOPLEFT", detail.title, "BOTTOMLEFT", 0, -4)
  detail.when = Theme.Text(detail, "body")
  detail.when:SetPoint("TOPLEFT", detail.status, "BOTTOMLEFT", 0, -6)
  detail.when:SetPoint("RIGHT")
  detail.organizer = Theme.Text(detail, "body")
  detail.organizer:SetPoint("TOPLEFT", detail.when, "BOTTOMLEFT", 0, -6)
  detail.description = Theme.ScrollText(detail, "body")
  detail.description:SetPoint("TOPLEFT", detail.organizer, "BOTTOMLEFT", 0, -8)
  detail.description:SetPoint("BOTTOMRIGHT", -22, 0)

  -- Rodapé
  local sync = Theme.Text(frame, "small", "textMuted")
  sync:SetPoint("BOTTOMLEFT", 16, 20)
  sync:SetWordWrap(false)
  frame.sync = sync

  local importButton = Theme.Button(frame, "Importar", "primary", 110)
  importButton:SetPoint("BOTTOMRIGHT", -16, 14)
  importButton:SetScript("OnClick", function() ns.ImportDialog.Show() end)

  local syncButton = Theme.Button(frame, "Sincronizar", "outline", 110)
  syncButton:SetPoint("RIGHT", importButton, "LEFT", -8, 0)
  syncButton:SetScript("OnClick", function() ns.Comm.RequestLatest() end)
  frame.syncButton = syncButton

  local alertButton = Theme.Button(frame, "Alerta", "outline", 90)
  alertButton:SetPoint("RIGHT", syncButton, "LEFT", -8, 0)
  alertButton:SetScript("OnClick", function() ns.AlertDialog.Show() end)
  frame.alertButton = alertButton

  ns.On("DATA_UPDATED", MainFrame.Refresh)
  ns.On("SYNC_STATUS", MainFrame.Refresh)
end

function MainFrame.Toggle()
  if not frame then Build() end
  if frame:IsShown() then
    frame:Hide()
  else
    if not view.year then
      view.year, view.month = Today()
      selected.year, selected.month, selected.day = Today()
    end
    frame:Show()
  end
end

ns.MainFrame = MainFrame
