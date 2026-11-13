-- Modal do alerta de raide: escrever o texto, conferir como fica no chat da
-- guilda e enviar. Só para cargos aceitos.
local _, ns = ...

local L = ns.L

local Theme, Text, Alert = ns.Theme, ns.Text, ns.Alert
local AlertDialog = {}

local frame

local function SetMessage(text, color)
  frame.message:SetText(text)
  frame.message:SetTextColor(unpack(Theme.colors[color or "textMuted"]))
end

local function Update()
  local config = ns.Config
  local raw = frame.edit:GetText()
  local clean = Alert.Clean(raw)
  frame.counter:SetText(Text.Length(clean) .. "/" .. config.ALERT_MAX_CHARS)
  local _, code = Alert.Validate(raw, config)
  if clean == "" then
    frame.preview:SetText("")
  else
    frame.preview:SetText(Theme.Code("textMuted") .. L["No chat da guilda:"] .. "|r "
      .. Text.Escape(Alert.ChatLine(clean, config)))
  end
  frame.send:SetEnabled(code == nil)
  if code == "long" then
    SetMessage(L[Alert.ERRORS.long], "cancel")
  else
    SetMessage(L["O alerta aparece na tela de quem tem o addon e no chat da guilda para todos."])
  end
end

local function Send()
  local ok, err = ns.Warning.Send(frame.edit:GetText())
  if not ok then
    SetMessage(err, "cancel")
    return
  end
  frame.edit:SetText("")
  frame:Hide()
end

local function Build()
  frame = Theme.Window("VanguardaDaLuzAlertDialog", 520, 250, L["Alerta de raide"])
  frame:SetFrameStrata("DIALOG")

  local box = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  box:SetPoint("TOPLEFT", 16, -74)
  box:SetPoint("TOPRIGHT", -16, -74)
  box:SetHeight(32)
  Theme.Backdrop(box, "bgDeep", "borderField")

  local edit = CreateFrame("EditBox", nil, box)
  edit:SetPoint("TOPLEFT", 8, 0)
  edit:SetPoint("BOTTOMRIGHT", -56, 0)
  edit:SetAutoFocus(false)
  edit:SetFontObject(Theme.Font("body"))
  edit:SetTextColor(unpack(Theme.colors.text))
  edit:SetMaxLetters(ns.Config.ALERT_MAX_CHARS)
  edit:SetScript("OnEscapePressed", function() frame:Hide() end)
  edit:SetScript("OnEnterPressed", function() if frame.send:IsEnabled() then Send() end end)
  edit:SetScript("OnTextChanged", Update)
  box:EnableMouse(true)
  box:SetScript("OnMouseDown", function() edit:SetFocus() end)
  frame.edit = edit

  local counter = Theme.Text(box, "small", "textMuted")
  counter:SetPoint("RIGHT", -8, 0)
  frame.counter = counter

  local preview = Theme.Text(frame, "body")
  preview:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -12)
  preview:SetPoint("RIGHT", -16, 0)
  frame.preview = preview

  local message = Theme.Text(frame, "small")
  message:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -10)
  message:SetPoint("RIGHT", -16, 0)
  frame.message = message

  local send = Theme.Button(frame, L["Enviar alerta"], "primary", 140)
  send:SetPoint("BOTTOMRIGHT", -16, 14)
  send:SetScript("OnClick", Send)
  frame.send = send

  local cancel = Theme.Button(frame, L["Cancelar"], "ghost", 90)
  cancel:SetPoint("RIGHT", send, "LEFT", -8, 0)
  cancel:SetScript("OnClick", function() frame:Hide() end)

  frame:SetScript("OnShow", function()
    Update()
    edit:SetFocus()
  end)
end

function AlertDialog.Show()
  if not ns.Guild.IsMember() then
    ns.WelcomeFrame.Show()
    return
  end
  if not ns.Guild.IsPlayerTrusted() then
    ns.Print(L["Somente o Grão Lorde e os Lordes podem enviar alertas."])
    return
  end
  if not frame then Build() end
  frame:Show()
end

ns.AlertDialog = AlertDialog
