-- Painel do calendário: grade do mês, eventos do dia e detalhe do evento com a
-- presença. Usado na janela do addon (layout "wide") e na aba Eventos da
-- janela da guilda ("compact"). Datas no horário de Brasília; o horário do
-- servidor aparece quando é outro.
local _, ns = ...

local Theme, Time, Text, L = ns.Theme, ns.Time, ns.Text, ns.L
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
local PERSON_H = 24 -- linha de cada confirmado

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
  local brasilia = Time.FormatClock(event.startsAt, Brasilia()) .. " " .. L["(Brasília)"]
  local offset = Time.ServerOffset(C_DateAndTime.GetCurrentCalendarTime(), GetServerTime())
  if offset == Brasilia() then return brasilia end
  local f = Time.Fields(event.startsAt, offset)
  local b = Time.Fields(event.startsAt, Brasilia())
  local server = Time.FormatClock(event.startsAt, offset)
  if f.day ~= b.day then server = string.format("%02d/%02d ", f.day, f.month) .. server end
  return brasilia .. "  ·  " .. server .. " " .. string.format(L["(servidor, %s)"], Time.FormatOffset(offset))
end

-- Linha da última exportação recebida (usada pelas janelas que mostram o painel).
function CalendarPanel.InfoLine()
  local export = ns.db.export
  if not export then
    return L["Nenhuma exportação recebida ainda. Os eventos chegam do Grão Lorde ou de um Lorde da guilda."]
  end
  local generated = Time.FormatDateTime(export.exportNumber, Brasilia())
  local received = Time.FormatDateTime(export.receivedAt, Brasilia())
  local from = export.source == "guild" and export.sender
    and string.format(L[" de %s"], Ambiguate(export.sender, "short")) or L[" por importação"]
  return string.format(L["Gerado no site em %s  ·  Recebido em %s%s"], generated, received, from)
end

local Panel = {}
Panel.__index = Panel

---------------------------------------------------------------------------
-- Detalhe do evento
---------------------------------------------------------------------------

-- Rótulos curtos do botão de grupo de cada confirmado.
local GROUP_LABELS = {
  INVITE = L["Convidar"], SUGGEST_INVITE = L["Sugerir"], REQUEST_INVITE = L["Pedir"],
}

-- Linha de um confirmado: nome na cor da classe, item level e main/alt, e o
-- botão de grupo (convidar, sugerir ou pedir para entrar).
function Panel:PersonRow(i)
  local d = self.detail
  local row = d.people.rows[i]
  if row then return row end
  row = CreateFrame("Frame", nil, d.people)
  row:SetHeight(PERSON_H)
  row:SetPoint("TOPLEFT", 0, -(i - 1) * PERSON_H)
  row:SetPoint("RIGHT")
  row.button = Theme.Button(row, L["Convidar"], "outline", 76)
  row.button:SetHeight(20)
  row.button:SetPoint("RIGHT", 0, 0)
  row.button:SetScript("OnClick", function(b)
    ns.MembersPanel.DoGroupInvite(b.name, b.kind)
  end)
  row.state = Theme.Text(row, "small", "textMuted")
  row.state:SetPoint("RIGHT", -4, 0)
  row.name = Theme.Text(row, "body")
  row.name:SetPoint("LEFT", 0, 0)
  row.name:SetWordWrap(false)
  row.detail = Theme.Text(row, "small", "textMuted")
  row.detail:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
  row.detail:SetPoint("RIGHT", row.button, "LEFT", -6, 0)
  row.detail:SetWordWrap(false)
  d.people.rows[i] = row
  return row
end

-- Quem confirmou presença, um por linha, com o botão de grupo na frente de
-- quem está online.
function Panel:ShowPeople(names)
  local people = self.detail.people
  local roster = {}
  for _, entry in ipairs(ns.Flavor.GuildRoster()) do roster[entry.name] = entry end
  for i, name in ipairs(names) do
    local row = self:PersonRow(i)
    local entry = roster[name]
    local online = entry and entry.online
    local color = online and ns.Flavor.ClassColorCode(entry.classFile)
    local text = Text.Escape(name)
    row.name:SetText(color and (color .. text .. "|r") or (Theme.Code("textMuted") .. text .. "|r"))
    row.detail:SetText(Text.Escape(ns.Members.Detail(name, ns.GuildMembers.Get(name)) or ""))
    local state
    if ns.Guild.IsPlayer(name) then
      state = L["você"]
    elseif not online then
      state = L["Offline"]
    elseif ns.Flavor.InGroupWith(name) then
      state = L["no grupo"]
    end
    if state then
      row.button:Hide()
      row.state:SetText(state)
      row.detail:SetPoint("RIGHT", row.state, "LEFT", -6, 0)
    else
      local kind = ns.MembersPanel.GroupKind(name, entry.guid)
      row.button.name, row.button.kind = name, kind
      row.button:SetText(GROUP_LABELS[kind] or GROUP_LABELS.INVITE)
      row.button:Show()
      row.state:SetText("")
      row.detail:SetPoint("RIGHT", row.button, "LEFT", -6, 0)
    end
    row:Show()
  end
  for i = #names + 1, #people.rows do people.rows[i]:Hide() end
  people:SetHeight(math.max(1, #names * PERSON_H))
end

-- Lista de presença do jogo e botão de confirmar/cancelar.
function Panel:ShowAttendance(event)
  local d, Lay = self.detail, self.layout
  local names = ns.Presence.Confirmed(event.id)
  local line = Theme.Code("textMuted") .. string.format(L["Confirmados no jogo (%d)"], #names) .. "|r"
  d.attendance:SetText(#names > 0 and line or (line .. " " .. L["ninguém ainda"]))
  self:ShowPeople(names)
  local open = ns.Presence.IsOpen(event)
  d.attend:SetShown(open)
  -- Editar e cancelar (Grão Lorde e Lordes), numa linha acima da presença.
  local editable = open and ns.GuildEvents.CanEdit() and ns.GuildEvents.IsChangeable(event)
  d.edit:SetShown(editable)
  d.cancel:SetShown(editable)
  d.cancel.eventId, d.cancel.armed = event.id, false
  d.cancel:SetText(L["Cancelar evento"])
  d.edit.event = event
  -- Excluir (evento cancelado), no lugar do botão de presença.
  local deletable = not open and ns.GuildEvents.CanEdit() and ns.GuildEvents.IsDeletable(event)
  d.delete:SetShown(deletable)
  d.delete.eventId, d.delete.armed = event.id, false
  d.delete:SetText(L["Excluir evento"])
  -- Sem botões, a área com rolagem desce até o pé do cartão.
  local bottom = Lay.cardPad + ((open or deletable) and (28 + 10) or 0) + (editable and (28 + 6) or 0)
  d.body:SetPoint("BOTTOMRIGHT", -Lay.cardPad - 18, bottom)
  if open then
    d.attend.eventId = event.id
    d.attend:SetText(ns.Presence.Status(event.id) == 1 and L["Cancelar presença"] or L["Confirmar presença"])
  end
end

function Panel:ShowDetail(event)
  local d = self.detail
  if not event then return end
  d.title:SetText(Text.Escape(event.title))
  d.title:SetTextColor(unpack(Theme.colors[event.status == "cancelado" and "cancel" or "heading"]))
  if event.status == "cancelado" then
    d.status:SetText(Theme.Code("cancel") .. L["CANCELADO"] .. "|r")
  else
    d.status:SetText(Theme.Code("success") .. L["ATIVO"] .. "|r")
  end
  d.when:SetText(Time.FormatLongDate(event.startsAt, Brasilia()) .. "\n" .. TimesLine(event))
  local organizer = Text.Escape(event.organizer)
  if event.pending then
    -- Criado ou alterado no jogo: ainda não está no site.
    local note = event.origin == "jogo" and L["Criado no jogo por %s · aguardando o site"]
      or L["Alterado no jogo por %s · aguardando o site"]
    organizer = organizer .. "\n" .. Theme.Code("warning") .. string.format(note, Text.Escape(event.by or "?")) .. "|r"
  end
  d.organizer:SetText(organizer)
  self:ShowAttendance(event)
  local description = Text.Escape(event.description or "")
  d.description:SetText(description ~= "" and description
    or (Theme.Code("textMuted") .. L["Sem descrição."] .. "|r"))
  d.body:Layout()
end

---------------------------------------------------------------------------
-- Lista de eventos do dia
---------------------------------------------------------------------------

function Panel:RenderDay()
  local s, Lay = self.selected, self.layout
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
      button.badge:SetText(event.status == "cancelado" and L["Cancelado"] or "")
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
  self.newEvent:SetShown(ns.GuildEvents.CanEdit())
  -- O cartão do dia só ocupa a altura dos eventos que o dia tem.
  local rows = math.min(#list, MAX_DAY_EVENTS)
  local top = Lay.cardPad + 30
  self.dayCard:SetHeight(top + (rows > 0 and rows * Lay.rowStep or 20) + Lay.cardPad - 4)
  self.detail:SetShown(chosen ~= nil)
  self:ShowDetail(chosen)
end

---------------------------------------------------------------------------
-- Grade do mês
---------------------------------------------------------------------------

function Panel:RenderMonth()
  local v, s, Lay = self.view, self.selected, self.layout
  self.monthTitle:SetText(Time.FormatMonth(v.year, v.month))
  local first = Time.FirstWeekday(v.year, v.month)
  local days = Time.DaysInMonth(v.year, v.month)
  local ty, tm, td = Today()

  for i, cell in ipairs(self.cells) do
    local day = i - first + 1
    if day >= 1 and day <= days then
      cell.day = day
      cell.number:SetText(day)
      local events = ns.Store.EventsOn(v.year, v.month, day)
      for k = 1, Lay.labels do
        local label, event = cell.labels[k], events[k]
        if event then
          label:SetText(Text.Escape(event.title))
          label:SetTextColor(unpack(Theme.colors[StatusColor(event)]))
        else
          label:SetText("")
        end
      end
      local hidden = #events - Lay.labels
      if Lay.labels == 0 then
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
      for k = 1, Lay.labels do cell.labels[k]:SetText("") end
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

-- Mostra o dia de um evento, com ele selecionado.
function Panel:ShowEvent(event)
  local f = Time.Fields(event.startsAt, Brasilia())
  self:ShowDate(f.year, f.month, f.day, event.id)
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

  local strings, values, frames = {}, {}, {}
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

  -- Quadro logo abaixo da última seção (sem rótulo), com altura própria.
  function scroll.AddFrame()
    local frame = CreateFrame("Frame", nil, child)
    frame:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -4)
    frame:SetPoint("RIGHT", child, "RIGHT")
    frame:SetHeight(1)
    frames[#frames + 1] = frame
    previous = frame
    return frame
  end

  scroll:SetScript("OnSizeChanged", function(self, w)
    child:SetWidth(w)
    for _, fs in ipairs(strings) do fs:SetWidth(w) end
    self:Layout()
  end)
  function scroll:Layout()
    local height = 0
    for _, fs in ipairs(strings) do height = height + (fs:GetStringHeight() or 0) end
    for _, frame in ipairs(frames) do height = height + (frame:GetHeight() or 0) + 4 end
    child:SetHeight(height + #values * 4 + (#values - 1) * 12 + 4)
    self:SetVerticalScroll(0)
  end
  return scroll
end

function Panel:BuildGrid(gridW, gridH)
  local Lay = self.layout
  local grid = CreateFrame("Frame", nil, self.frame)
  grid:SetSize(gridW, gridH)
  grid:SetPoint("TOPLEFT")

  local prev = Theme.Button(grid, "‹", "outline", 32)
  prev:SetPoint("TOPLEFT")
  prev:SetScript("OnClick", function() self:ChangeMonth(-1) end)
  local nextButton = Theme.Button(grid, "›", "outline", 32)
  nextButton:SetPoint("TOPRIGHT")
  nextButton:SetScript("OnClick", function() self:ChangeMonth(1) end)
  local todayButton = Theme.Button(grid, L["Hoje"], "ghost", Lay.labels > 0 and 60 or 48)
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
    label:SetWidth(Lay.cellW)
    label:SetJustifyH("CENTER")
    label:SetPoint("TOPLEFT", (i - 1) * (Lay.cellW + Lay.gap), -(Lay.gridTop - 20))
    label:SetText(Time.Names().WEEKDAYS_SHORT[i])
  end

  for i = 1, 42 do
    local col, row = (i - 1) % 7, math.floor((i - 1) / 7)
    local cell = CreateFrame("Button", nil, grid, "BackdropTemplate")
    cell:SetSize(Lay.cellW, Lay.cellH)
    cell:SetPoint("TOPLEFT", col * (Lay.cellW + Lay.gap), -Lay.gridTop - row * (Lay.cellH + Lay.gap))
    cell.number = Theme.Text(cell, "day")
    cell.number:SetPoint("TOPLEFT", 5, -4)
    cell.marker = cell:CreateTexture(nil, "OVERLAY")
    cell.marker:SetSize(6, 6)
    cell.marker:SetPoint("TOPRIGHT", -5, -7)
    cell.marker:SetColorTexture(unpack(Theme.colors.gold))
    cell.more = Theme.Text(cell, "small", "textMuted")
    if Lay.labels > 0 then
      cell.more:SetPoint("RIGHT", cell.marker, "LEFT", -4, 0)
    else
      cell.more:SetPoint("BOTTOMRIGHT", -4, 4)
    end
    cell.labels = {}
    for k = 1, Lay.labels do
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
  local Lay = self.layout
  local side = CreateFrame("Frame", nil, self.frame)
  side:SetSize(sideW, height)
  side:SetPoint("TOPLEFT", grid, "TOPRIGHT", Lay.sideGap, 0)

  local dayCard = CreateFrame("Frame", nil, side, "BackdropTemplate")
  dayCard:SetPoint("TOPLEFT")
  dayCard:SetPoint("TOPRIGHT")
  dayCard:SetHeight(70)
  Theme.Backdrop(dayCard, "surface", "border")
  self.dayCard = dayCard

  -- Novo evento no dia selecionado (Grão Lorde e Lordes).
  local newEvent = Theme.Button(dayCard, L["+ Evento"], "ghost", 80)
  newEvent:SetHeight(22)
  newEvent:SetPoint("TOPRIGHT", -(Lay.cardPad - 4), -Lay.cardPad + 6)
  newEvent:SetScript("OnClick", function()
    local s = self.selected
    ns.EventDialog.ShowNew(s.year, s.month, s.day, function(event) self:ShowEvent(event) end)
  end)
  self.newEvent = newEvent

  local dayTitle = Theme.Text(dayCard, "heading", "heading")
  dayTitle:SetPoint("TOPLEFT", Lay.cardPad, -Lay.cardPad + 2)
  dayTitle:SetPoint("RIGHT", newEvent, "LEFT", -6, 0)
  dayTitle:SetWordWrap(false)
  self.dayTitle = dayTitle

  local top = Lay.cardPad + 30
  local noEvents = Theme.Text(dayCard, "body", "textMuted")
  noEvents:SetPoint("TOPLEFT", Lay.cardPad, -top)
  noEvents:SetText(L["Nenhum evento neste dia."])
  self.noEvents = noEvents

  for i = 1, MAX_DAY_EVENTS do
    local button = CreateFrame("Button", nil, dayCard, "BackdropTemplate")
    button:SetHeight(Lay.rowH)
    button:SetPoint("TOPLEFT", Lay.cardPad - 4, -top - (i - 1) * Lay.rowStep)
    button:SetPoint("RIGHT", -(Lay.cardPad - 4), 0)
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
  detail.status:SetPoint("TOPRIGHT", -Lay.cardPad, -Lay.cardPad - 1)
  detail.title = Theme.Text(detail, "heading", "heading")
  detail.title:SetPoint("TOPLEFT", Lay.cardPad, -Lay.cardPad + 2)
  detail.title:SetPoint("RIGHT", detail.status, "LEFT", -10, 0)
  local line = Theme.Divider(detail)
  line:SetPoint("TOPLEFT", detail.title, "BOTTOMLEFT", 0, -8)
  line:SetPoint("RIGHT", -Lay.cardPad, 0)

  local body = DetailBody(detail)
  body:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -10)
  body:SetPoint("BOTTOMRIGHT", -Lay.cardPad - 18, Lay.cardPad)
  detail.body = body
  detail.when = body.Add(L["QUANDO"])
  detail.organizer = body.Add(L["ORGANIZADOR"])
  detail.attendance = body.Add(L["PRESENÇA"])
  detail.people = body.AddFrame()
  detail.people.rows = {}
  detail.description = body.Add(L["DESCRIÇÃO"])

  detail.attend = Theme.Button(detail, L["Confirmar presença"], "primary", 170)
  detail.attend:SetPoint("BOTTOMLEFT", Lay.cardPad, Lay.cardPad)
  detail.attend:SetScript("OnClick", function(b)
    local ok, err = ns.Presence.Toggle(b.eventId)
    if not ok then ns.Print(err) end
  end)

  detail.edit = Theme.Button(detail, L["Editar"], "outline", 90)
  detail.edit:SetPoint("BOTTOMLEFT", detail.attend, "TOPLEFT", 0, 6)
  detail.edit:SetScript("OnClick", function(b)
    ns.EventDialog.ShowEdit(b.event, function(event) self:ShowEvent(event) end)
  end)
  -- Cancelar e excluir pedem um segundo clique em até 5 segundos.
  local function TwoClicks(button, label, action)
    button:SetScript("OnClick", function(b)
      if not b.armed then
        b.armed = true
        b:SetText(L["Clique de novo"])
        C_Timer.After(5, function()
          if b.armed then
            b.armed = false
            b:SetText(L[label])
          end
        end)
        return
      end
      b.armed = false
      local ok, err = action(b.eventId)
      if not ok then ns.Print(err) end
    end)
  end
  detail.cancel = Theme.Button(detail, L["Cancelar evento"], "ghost", 170)
  detail.cancel:SetPoint("LEFT", detail.edit, "RIGHT", 8, 0)
  TwoClicks(detail.cancel, "Cancelar evento", ns.GuildEvents.Cancel)
  detail.delete = Theme.Button(detail, L["Excluir evento"], "ghost", 170)
  detail.delete:SetPoint("BOTTOMLEFT", Lay.cardPad, Lay.cardPad)
  TwoClicks(detail.delete, "Excluir evento", ns.GuildEvents.Delete)
end

-- Cria o painel dentro de `parent`, com a largura `width` e o layout "wide" ou
-- "compact". A altura vem do layout (panel.height); `height` (opcional) ajusta
-- a altura das células ao espaço disponível. Quem usa o painel chama
-- panel:Refresh() quando ele está visível.
function CalendarPanel.Create(parent, width, layoutName, height)
  local Lay = {}
  for k, v in pairs(LAYOUTS[layoutName or "wide"]) do Lay[k] = v end
  local fit = height and math.floor((height - Lay.gridTop - 5 * Lay.gap) / 6)
  if layoutName == "compact" then
    -- Metade da largura para a grade, e a altura disponível para as linhas.
    Lay.cellW = math.max(Lay.cellW, math.floor((width * 0.5 - 6 * Lay.gap) / 7))
    if fit then Lay.cellH = math.max(Lay.cellH, fit) end
  elseif fit then
    Lay.cellH = fit
  end
  local self = setmetatable({
    layout = Lay, view = {}, selected = {}, cells = {}, eventButtons = {},
  }, Panel)
  local gridW = 7 * Lay.cellW + 6 * Lay.gap
  height = Lay.gridTop + 6 * Lay.cellH + 5 * Lay.gap
  self.height = height
  self.frame = CreateFrame("Frame", nil, parent)
  self.frame:SetSize(width, height)
  local grid = self:BuildGrid(gridW, height)
  self:BuildSide(grid, width - gridW - Lay.sideGap, height)
  return self
end

ns.CalendarPanel = CalendarPanel
