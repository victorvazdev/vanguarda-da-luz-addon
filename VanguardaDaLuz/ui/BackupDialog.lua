-- Backup (Grão Lorde e Lordes): gerar a string VDLB1 para guardar no site e
-- restaurar uma string copiada do site. Regras em game/Backup.lua.
local _, ns = ...

local L = ns.L

local Theme, Time = ns.Theme, ns.Time
local BackupDialog = {}

local exportFrame, restoreFrame
local current = ""  -- string gerada ao abrir
local prepared      -- backup validado, à espera da confirmação

local function Brasilia() return ns.Config.BRASILIA_OFFSET end

-- Caixa de texto com rolagem para a string.
local function StringBox(frame, anchor, height, onChanged)
  local box = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  box:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
  box:SetPoint("RIGHT", -16, 0)
  box:SetHeight(height)
  Theme.Backdrop(box, "bgDeep", "borderField")
  local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 8, -8)
  scroll:SetPoint("BOTTOMRIGHT", -28, 8)
  local edit = CreateFrame("EditBox", nil, scroll)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(false)
  edit:SetFontObject(Theme.Font("small"))
  edit:SetTextColor(unpack(Theme.colors.text))
  edit:SetWidth(520)
  edit:SetMaxLetters(0)
  if edit.SetMaxBytes then edit:SetMaxBytes(0) end
  edit:SetScript("OnEscapePressed", function() frame:Hide() end)
  edit:SetScript("OnTextChanged", onChanged)
  scroll:SetScrollChild(edit)
  box:EnableMouse(true)
  box:SetScript("OnMouseDown", function() edit:SetFocus() end)
  return box, edit
end

-- "2 evento(s) · 3 presença(s) · ..." de BackupCodec.Counts.
local function CountsLine(c)
  return string.format(L["%d evento(s) do jogo  ·  %d presença(s)  ·  %d profissão(ões)  ·  "
    .. "%d item level(s)  ·  %d tempo(s) junto"], c.events, c.attendance, c.professions, c.members, c.together)
end

---------------------------------------------------------------------------
-- Gerar
---------------------------------------------------------------------------

local function SelectExport()
  exportFrame.edit:SetText(current)
  exportFrame.edit:SetFocus()
  exportFrame.edit:HighlightText()
end

local function BuildExport()
  local frame = Theme.Window("VanguardaDaLuzBackupExport", 580, 340, L["Gerar backup"])
  frame:SetFrameStrata("DIALOG")
  exportFrame = frame

  local help = Theme.Text(frame, "body")
  help:SetPoint("TOPLEFT", 16, -70)
  help:SetPoint("TOPRIGHT", -16, -70)
  help:SetSpacing(3)
  help:SetText(L["Eventos criados ou alterados no jogo, presenças, profissões, item level, main e tempo jogado "
    .. "junto. Copie com Ctrl+C e cole no site, em Administração > Backup do addon."])

  local box, edit = StringBox(frame, help, 130, function(_, userInput) if userInput then SelectExport() end end)
  edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  frame.edit = edit

  local summary = Theme.Text(frame, "small", "textMuted")
  summary:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -8)
  summary:SetPoint("RIGHT", -16, 0)
  frame.summary = summary

  local close = Theme.Button(frame, L["Fechar"], "primary", 110)
  close:SetPoint("BOTTOMRIGHT", -16, 14)
  close:SetScript("OnClick", function() frame:Hide() end)

  frame:SetScript("OnShow", function()
    current = ns.Backup.ExportString()
    summary:SetText(CountsLine(ns.BackupCodec.Counts(ns.BackupCodec.Decode(current))))
    SelectExport()
  end)
end

---------------------------------------------------------------------------
-- Restaurar
---------------------------------------------------------------------------

local function SetMessage(text, color)
  restoreFrame.message:SetText(text)
  restoreFrame.message:SetTextColor(unpack(Theme.colors[color or "text"]))
end

local function ResetRestore()
  prepared = nil
  restoreFrame.confirm:Disable()
  SetMessage(L["Cole a string copiada do site em Backup do addon e clique em Validar."], "textMuted")
end

local function Validate()
  local data, err = ns.Backup.Prepare(restoreFrame.edit:GetText())
  if not data then
    prepared = nil
    restoreFrame.confirm:Disable()
    SetMessage(err, "cancel")
    return
  end
  prepared = data
  local by = data.generatedBy ~= "" and string.format(L[" por %s"], ns.Text.Escape(data.generatedBy)) or ""
  SetMessage(Theme.Code("gold") .. L["Backup válido"] .. "|r\n"
    .. string.format(L["Gerado em %s%s"], Time.FormatDateTime(data.generatedAt, Brasilia()) .. " "
      .. L["(Brasília)"], by) .. "\n" .. CountsLine(ns.BackupCodec.Counts(data)) .. "\n\n"
    .. Theme.Code("textMuted") .. L["A restauração só acrescenta dados mais novos que os do addon; "
      .. "nada é apagado."] .. "|r")
  restoreFrame.confirm:Enable()
end

local function Confirm()
  if not prepared then return end
  local c = ns.Backup.Restore(prepared)
  prepared = nil
  restoreFrame.edit:SetText("")
  restoreFrame:Hide()
  ns.Print(string.format(L["Backup restaurado: %d evento(s), %d presença(s), %d profissão(ões), "
    .. "%d item level(s) e %d tempo(s) junto atualizados."], c.events, c.attendance, c.professions, c.members,
    c.together))
end

local function BuildRestore()
  local frame = Theme.Window("VanguardaDaLuzBackupRestore", 580, 460, L["Restaurar backup"])
  frame:SetFrameStrata("DIALOG")
  restoreFrame = frame

  local help = Theme.Text(frame, "body", "textMuted")
  help:SetPoint("TOPLEFT", 16, -68)
  help:SetPoint("TOPRIGHT", -16, -68)
  help:SetText(L["No site, abra Administração > Backup do addon, copie a string de restauração e cole abaixo "
    .. "com Ctrl+V."])

  local box, edit = StringBox(frame, help, 130, function(_, userInput) if userInput then ResetRestore() end end)
  frame.edit = edit

  local message = Theme.Text(frame, "body")
  message:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -12)
  message:SetPoint("RIGHT", -16, 0)
  message:SetSpacing(3)
  frame.message = message

  local confirm = Theme.Button(frame, L["Restaurar"], "primary", 140)
  confirm:SetPoint("BOTTOMRIGHT", -16, 14)
  confirm:SetScript("OnClick", Confirm)
  frame.confirm = confirm
  local validate = Theme.Button(frame, L["Validar"], "outline", 100)
  validate:SetPoint("RIGHT", confirm, "LEFT", -8, 0)
  validate:SetScript("OnClick", Validate)
  local clear = Theme.Button(frame, L["Limpar"], "ghost", 80)
  clear:SetPoint("BOTTOMLEFT", 16, 14)
  clear:SetScript("OnClick", function()
    edit:SetText("")
    ResetRestore()
    edit:SetFocus()
  end)

  frame:SetScript("OnShow", function()
    ResetRestore()
    edit:SetFocus()
  end)
end

---------------------------------------------------------------------------

local function Allowed()
  if not ns.Guild.IsMember() then
    ns.WelcomeFrame.Show()
    return false
  end
  if not ns.Guild.IsPlayerTrusted() then
    ns.Print(L["Somente o Grão Lorde e os Lordes podem gerar e restaurar o backup."])
    return false
  end
  return true
end

function BackupDialog.ShowExport()
  if not Allowed() then return end
  if not exportFrame then BuildExport() end
  exportFrame:Show()
end

function BackupDialog.ShowRestore()
  if not Allowed() then return end
  if not restoreFrame then BuildRestore() end
  restoreFrame:Show()
end

ns.BackupDialog = BackupDialog
