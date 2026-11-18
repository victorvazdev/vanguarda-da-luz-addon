-- Janela da mensagem de recrutamento: escrever o texto (compartilhado com o
-- Grão Lorde e os Lordes), escolher o canal do chat e enviar com um clique.
-- Só para cargos aceitos. Regras em game/GuildRecruit.lua.
local _, ns = ...

local L = ns.L

local Theme, Recruit = ns.Theme, ns.Recruit
local RecruitDialog = {}

local frame

local function SetMessage(text, color)
  frame.message:SetText(text)
  frame.message:SetTextColor(unpack(Theme.colors[color or "textMuted"]))
end

-- "Salva por Fulano em 17/11 20:15."
function RecruitDialog.SavedLine(record)
  if not record then return L["Nenhuma mensagem salva ainda."] end
  local when = ns.Time.FormatDateTime(record.at, ns.Config.BRASILIA_OFFSET)
  return string.format(L["Salva por %s em %s."], record.by, when)
end

local function Update()
  local raw = frame.edit:GetText()
  local clean, code = Recruit.Validate(raw)
  frame.counter:SetText(#Recruit.Clean(raw) .. "/" .. Recruit.MAX_BYTES)
  frame.save:SetEnabled(clean ~= nil)
  frame.send:SetEnabled(clean ~= nil)
  frame.channel:SetText(string.format(L["Canal: %s"], ns.GuildRecruit.ChannelLabel(ns.GuildRecruit.Channel())))
  if code == "long" then
    SetMessage(ns.GuildRecruit.ErrorText(code), "cancel")
  else
    SetMessage(RecruitDialog.SavedLine(ns.GuildRecruit.Get()))
  end
end

local function Save()
  local record, err = ns.GuildRecruit.Save(frame.edit:GetText())
  if not record then
    SetMessage(err, "cancel")
    return nil
  end
  Update()
  return record
end

-- Envia o texto salvo no canal escolhido e avisa no chat do jogador.
function RecruitDialog.SendNow()
  local ok, result = ns.GuildRecruit.Send()
  if ok then
    ns.Print(string.format(L["Mensagem de recrutamento enviada em %s."], ns.GuildRecruit.ChannelLabel(result)))
  else
    ns.Print(result)
  end
  return ok, result
end

local function SaveAndSend()
  if not Save() then return end
  local ok, result = RecruitDialog.SendNow()
  if ok then
    frame:Hide()
  else
    SetMessage(result, "cancel")
  end
end

local function Build()
  frame = Theme.Window("VanguardaDaLuzRecruitDialog", 560, 270, L["Mensagem de recrutamento"])
  frame:SetFrameStrata("DIALOG")

  local box = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  box:SetPoint("TOPLEFT", 16, -74)
  box:SetPoint("TOPRIGHT", -16, -74)
  box:SetHeight(76)
  Theme.Backdrop(box, "bgDeep", "borderField")

  local edit = CreateFrame("EditBox", nil, box)
  edit:SetPoint("TOPLEFT", 8, -6)
  edit:SetPoint("BOTTOMRIGHT", -8, 18)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(false)
  edit:SetFontObject(Theme.Font("body"))
  edit:SetTextColor(unpack(Theme.colors.text))
  edit:SetScript("OnEscapePressed", function() frame:Hide() end)
  edit:SetScript("OnEnterPressed", function() if frame.save:IsEnabled() then Save() end end)
  edit:SetScript("OnTextChanged", Update)
  box:EnableMouse(true)
  box:SetScript("OnMouseDown", function() edit:SetFocus() end)
  frame.edit = edit

  local counter = Theme.Text(box, "small", "textMuted")
  counter:SetPoint("BOTTOMRIGHT", -8, 4)
  frame.counter = counter

  local channel = Theme.Button(frame, "", "outline", 200)
  channel:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -10)
  channel:SetScript("OnClick", function()
    ns.GuildRecruit.NextChannel()
    Update()
  end)
  frame.channel = channel

  local hint = Theme.Text(frame, "small", "textMuted")
  hint:SetPoint("LEFT", channel, "RIGHT", 10, 0)
  hint:SetPoint("RIGHT", -16, 0)
  hint:SetText(L["Clique para trocar de canal. O envio é sempre um clique seu, com 60 s entre envios."])

  local message = Theme.Text(frame, "small")
  message:SetPoint("TOPLEFT", channel, "BOTTOMLEFT", 0, -10)
  message:SetPoint("RIGHT", -16, 0)
  frame.message = message

  local send = Theme.Button(frame, L["Salvar e enviar"], "primary", 140)
  send:SetPoint("BOTTOMRIGHT", -16, 14)
  send:SetScript("OnClick", SaveAndSend)
  frame.send = send

  local save = Theme.Button(frame, L["Salvar"], "outline", 100)
  save:SetPoint("RIGHT", send, "LEFT", -8, 0)
  save:SetScript("OnClick", Save)
  frame.save = save

  local cancel = Theme.Button(frame, L["Fechar"], "ghost", 90)
  cancel:SetPoint("RIGHT", save, "LEFT", -8, 0)
  cancel:SetScript("OnClick", function() frame:Hide() end)

  frame:SetScript("OnShow", function()
    local record = ns.GuildRecruit.Get()
    edit:SetText(record and record.text or "")
    Update()
    edit:SetFocus()
  end)
end

function RecruitDialog.Show()
  if not ns.Guild.IsMember() then
    ns.WelcomeFrame.Show()
    return
  end
  if not ns.GuildRecruit.CanUse() then
    ns.Print(L["Somente o Grão Lorde e os Lordes podem usar a mensagem de recrutamento."])
    return
  end
  if not frame then Build() end
  frame:Show()
end

ns.RecruitDialog = RecruitDialog
