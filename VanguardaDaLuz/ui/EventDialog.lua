-- Formulário de evento (Grão Lorde e Lordes): criar um evento no jogo ou
-- editar um evento ativo que ainda não começou, do jogo ou do site. Vagas e
-- visitantes só aparecem nos eventos criados no jogo: o addon não sabe os do
-- site (a string VDL1 não os traz). Gravação em game/GuildEvents.lua.
local _, ns = ...

local L = ns.L

local Theme, Time = ns.Theme, ns.Time
local EventDialog = {}

local frame
local editing = nil -- ID do evento em edição (nil = novo)

local function Brasilia() return ns.Config.BRASILIA_OFFSET end

-- Campo de texto com rótulo em cima. Retorna a caixa de edição.
local function Field(parent, label, width, maxLetters)
  local caption = Theme.Text(parent, "smallStrong", "goldDeep")
  caption:SetText(label)
  local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  box:SetSize(width, 30)
  box:SetPoint("TOPLEFT", caption, "BOTTOMLEFT", 0, -4)
  Theme.Backdrop(box, "bgDeep", "borderField")
  local edit = CreateFrame("EditBox", nil, box)
  edit:SetPoint("TOPLEFT", 8, 0)
  edit:SetPoint("BOTTOMRIGHT", -8, 0)
  edit:SetAutoFocus(false)
  edit:SetFontObject(Theme.Font("body"))
  edit:SetTextColor(unpack(Theme.colors.text))
  if maxLetters then edit:SetMaxLetters(maxLetters) end
  edit:SetScript("OnEscapePressed", function() frame:Hide() end)
  edit:SetScript("OnTabPressed", function(self) if self.nextField then self.nextField:SetFocus() end end)
  box:EnableMouse(true)
  box:SetScript("OnMouseDown", function() edit:SetFocus() end)
  edit.caption, edit.box = caption, box
  return edit
end

local function SetMessage(text, color)
  frame.message:SetText(text or "")
  frame.message:SetTextColor(unpack(Theme.colors[color or "cancel"]))
end

local function Save()
  local startsAt, code = ns.GuildEvents.StartsAt(frame.date:GetText(), frame.clock:GetText())
  if not startsAt then
    SetMessage(ns.GuildEvents.ErrorText(code))
    return
  end
  local event, err = ns.GuildEvents.Save(editing, {
    title = frame.title:GetText(),
    description = frame.description:GetText(),
    organizer = frame.organizer:GetText(),
    startsAt = startsAt,
    max = tonumber(frame.max:GetText()),
    guests = frame.guests:GetValue(),
  })
  if not event then
    SetMessage(err)
    return
  end
  ns.Print(string.format(editing and L["Evento alterado: %s. Ele vai para o site no próximo backup."]
    or L["Evento criado: %s. Ele vai para o site no próximo backup."], ns.Text.Escape(event.title)))
  frame:Hide()
  if frame.onSaved then frame.onSaved(event) end
end

local function Build()
  frame = Theme.Window("VanguardaDaLuzEventDialog", 580, 540, L["Novo evento"])
  frame:SetFrameStrata("DIALOG")
  local inner = 580 - 32

  local title = Field(frame, L["TÍTULO"], inner, ns.GameEvents.LIMITS.title)
  title.caption:SetPoint("TOPLEFT", 16, -72)
  frame.title = title

  local date = Field(frame, L["DATA (dd/mm/aaaa)"], 150)
  date.caption:SetPoint("TOPLEFT", title.box, "BOTTOMLEFT", 0, -12)
  frame.date = date
  local clock = Field(frame, L["HORA DE BRASÍLIA"], 120)
  clock.caption:SetPoint("LEFT", date.caption, "LEFT", 166, 0)
  frame.clock = clock
  local organizer = Field(frame, L["ORGANIZADOR"], inner - 166 - 136, ns.GameEvents.LIMITS.organizer)
  organizer.caption:SetPoint("LEFT", clock.caption, "LEFT", 136, 0)
  frame.organizer = organizer

  local max = Field(frame, L["VAGAS"], 100, 3)
  max.caption:SetPoint("TOPLEFT", date.box, "BOTTOMLEFT", 0, -12)
  max:SetNumeric(true)
  frame.max = max
  local guests = Theme.Toggle(frame, L["Aceita visitantes"], 220)
  guests:SetPoint("LEFT", max.box, "RIGHT", 16, 0)
  frame.guests = guests
  local limitsNote = Theme.Text(frame, "small", "textMuted")
  limitsNote:SetPoint("TOPLEFT", date.box, "BOTTOMLEFT", 0, -14)
  limitsNote:SetPoint("RIGHT", -16, 0)
  limitsNote:SetText(L["Vagas e visitantes deste evento são definidos no site."])
  frame.limitsNote = limitsNote

  local caption = Theme.Text(frame, "smallStrong", "goldDeep")
  caption:SetPoint("TOPLEFT", max.box, "BOTTOMLEFT", 0, -12)
  caption:SetText(L["DESCRIÇÃO"])
  local box = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  box:SetPoint("TOPLEFT", caption, "BOTTOMLEFT", 0, -4)
  box:SetSize(inner, 130)
  Theme.Backdrop(box, "bgDeep", "borderField")
  local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 8, -8)
  scroll:SetPoint("BOTTOMRIGHT", -28, 8)
  local description = CreateFrame("EditBox", nil, scroll)
  description:SetMultiLine(true)
  description:SetAutoFocus(false)
  description:SetFontObject(Theme.Font("body"))
  description:SetTextColor(unpack(Theme.colors.text))
  description:SetWidth(inner - 44)
  description:SetMaxLetters(ns.GameEvents.LIMITS.description)
  description:SetScript("OnEscapePressed", function() frame:Hide() end)
  scroll:SetScrollChild(description)
  box:EnableMouse(true)
  box:SetScript("OnMouseDown", function() description:SetFocus() end)
  frame.description = description

  title.nextField, date.nextField, clock.nextField = date, clock, organizer
  organizer.nextField, max.nextField = max, description

  local message = Theme.Text(frame, "body", "cancel")
  message:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -10)
  message:SetPoint("RIGHT", -16, 0)
  frame.message = message

  local save = Theme.Button(frame, L["Salvar"], "primary", 140)
  save:SetPoint("BOTTOMRIGHT", -16, 14)
  save:SetScript("OnClick", Save)
  frame.save = save
  local cancel = Theme.Button(frame, L["Fechar"], "ghost", 90)
  cancel:SetPoint("RIGHT", save, "LEFT", -8, 0)
  cancel:SetScript("OnClick", function() frame:Hide() end)
  local note = Theme.Text(frame, "small", "textMuted")
  note:SetPoint("BOTTOMLEFT", 16, 20)
  note:SetPoint("RIGHT", cancel, "LEFT", -12, 0)
  note:SetText(L["Vai para a guilda na hora e para o site no próximo backup."])
end

local function Open(event, year, month, day, onSaved)
  if not ns.Guild.IsMember() then
    ns.WelcomeFrame.Show()
    return
  end
  if not ns.GuildEvents.CanEdit() then
    ns.Print(L["Somente o Grão Lorde e os Lordes podem criar e alterar eventos."])
    return
  end
  if not frame then Build() end
  editing = event and event.id or nil
  frame.onSaved = onSaved
  local withLimits = not event or event.origin == "jogo"
  frame.heading:SetText(event and L["Editar evento"] or L["Novo evento"])
  if event then
    local f = Time.Fields(event.startsAt, Brasilia())
    frame.title:SetText(event.title)
    frame.date:SetText(string.format("%02d/%02d/%04d", f.day, f.month, f.year))
    frame.clock:SetText(Time.FormatClock(event.startsAt, Brasilia()))
    frame.organizer:SetText(event.organizer or "")
    frame.description:SetText(event.description or "")
    frame.max:SetText(tostring(event.max or ns.GameEvents.MAX_ATTENDEES.default))
    frame.guests:SetValue(event.guests ~= false)
  else
    frame.title:SetText("")
    frame.date:SetText(string.format("%02d/%02d/%04d", day, month, year))
    frame.clock:SetText(ns.Config.NEW_EVENT_CLOCK)
    frame.organizer:SetText(ns.Guild.PlayerName() or "")
    frame.description:SetText("")
    frame.max:SetText(tostring(ns.GameEvents.MAX_ATTENDEES.default))
    frame.guests:SetValue(true)
  end
  for _, widget in ipairs({ frame.max.caption, frame.max.box, frame.guests }) do widget:SetShown(withLimits) end
  frame.limitsNote:SetShown(not withLimits)
  SetMessage(nil)
  frame:Show()
  frame.title:SetFocus()
end

-- Novo evento, com a data já preenchida (o dia selecionado no calendário).
-- `onSaved(evento)` é chamado depois de gravar.
function EventDialog.ShowNew(year, month, day, onSaved)
  Open(nil, year, month, day, onSaved)
end

function EventDialog.ShowEdit(event, onSaved)
  Open(event, nil, nil, nil, onSaved)
end

ns.EventDialog = EventDialog
