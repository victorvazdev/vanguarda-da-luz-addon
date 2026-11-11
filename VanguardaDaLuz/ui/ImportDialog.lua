-- Modal de importação: colar a string, validar, ver o resumo e confirmar.
local _, ns = ...

local Theme, Time, Text = ns.Theme, ns.Time, ns.Text
local ImportDialog = {}

local frame
local prepared -- importação validada, à espera da confirmação

local function Brasilia() return ns.Config.BRASILIA_OFFSET end

local function Names(list, limit)
  local names = {}
  for i = 1, math.min(#list, limit) do names[i] = Text.Escape(list[i].event.title) end
  if #list > limit then names[#names + 1] = "e mais " .. (#list - limit) end
  return table.concat(names, ", ")
end

local function Summary(p)
  local export, diff = p.export, p.diff
  local lastDay = export.windowEnd - 86400
  local lines = {
    Theme.Code("gold") .. "Exportação válida|r",
    "Gerada em " .. Time.FormatDateTime(export.exportNumber, Brasilia()) .. " (Brasília)",
    "Janela: " .. Time.FormatDateTime(export.windowStart, Brasilia()):sub(1, 10)
      .. " a " .. Time.FormatDateTime(lastDay, Brasilia()):sub(1, 10)
      .. "  ·  " .. export.count .. " evento(s) na exportação",
    "",
  }
  local rows = {
    { "Novos", diff.created, "success" },
    { "Alterados", diff.updated, "azure" },
    { "Cancelados", diff.cancelled, "cancel" },
    { "Removidos", diff.removed, "warning" },
  }
  for _, row in ipairs(rows) do
    local line = Theme.Code(row[3]) .. row[1] .. ": " .. #row[2] .. "|r"
    if #row[2] > 0 then line = line .. "  " .. Theme.Code("textMuted") .. Names(row[2], 4) .. "|r" end
    lines[#lines + 1] = line
  end
  lines[#lines + 1] = Theme.Code("textMuted") .. "Sem alteração: " .. diff.unchanged
    .. "  ·  Fora da janela (mantidos): " .. diff.outside .. "|r"
  return table.concat(lines, "\n")
end

local function SetMessage(text, color)
  frame.message:SetText(text)
  frame.message:SetTextColor(unpack(Theme.colors[color or "text"]))
end

local function Reset()
  prepared = nil
  frame.confirm:Disable()
  SetMessage("Cole a string gerada em \"Exportar para o addon\" no site e clique em Validar.", "textMuted")
end

local function Validate()
  local raw = frame.edit:GetText()
  local p, message = ns.Store.Prepare(raw)
  if not p then
    prepared = nil
    frame.confirm:Disable()
    SetMessage(message, "cancel")
    return
  end
  prepared = p
  SetMessage(Summary(p))
  frame.confirm:Enable()
end

local function Confirm()
  if not prepared then return end
  local diff = ns.Store.Commit(prepared, "import", UnitName("player"))
  prepared = nil
  frame.edit:SetText("")
  frame:Hide()
  ns.Print(string.format("Importação concluída: %d novo(s), %d alterado(s), %d cancelado(s), %d removido(s).",
    #diff.created, #diff.updated, #diff.cancelled, #diff.removed))

  local canEdit, reason = ns.Guild.CanEditCalendar()
  if canEdit then
    ns.Calendar.Plan(diff)
    if #ns.Calendar.PendingList() > 0 then ns.PendingFrame.Show() end
  else
    ns.Print("Somente o calendário do addon foi atualizado. " .. (reason or ""))
  end

  if ns.Guild.IsPlayerTrusted() then
    ns.Comm.Broadcast()
  else
    ns.Print("Seu cargo não está entre os aceitos pela guilda; a exportação não foi enviada aos membros.")
  end
end

local function Build()
  frame = Theme.Window("VanguardaDaLuzImportDialog", 620, 500, "Importar eventos")
  frame:SetFrameStrata("DIALOG")

  local help = Theme.Text(frame, "body", "textMuted")
  help:SetPoint("TOPLEFT", 16, -68)
  help:SetPoint("TOPRIGHT", -16, -68)
  help:SetText("No site, abra Administração de eventos > Exportar para o addon, clique em Copiar e cole "
    .. "abaixo com Ctrl+V.")

  local box = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  box:SetPoint("TOPLEFT", 16, -100)
  box:SetPoint("TOPRIGHT", -16, -100)
  box:SetHeight(150)
  Theme.Backdrop(box, "bgDeep", "borderField")

  local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 8, -8)
  scroll:SetPoint("BOTTOMRIGHT", -28, 8)
  local edit = CreateFrame("EditBox", nil, scroll)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(false)
  edit:SetFontObject(Theme.Font("small"))
  edit:SetTextColor(unpack(Theme.colors.text))
  edit:SetWidth(540)
  edit:SetMaxLetters(0)
  if edit.SetMaxBytes then edit:SetMaxBytes(0) end
  edit:SetScript("OnEscapePressed", function() frame:Hide() end)
  edit:SetScript("OnTextChanged", function(_, userInput) if userInput then Reset() end end)
  scroll:SetScrollChild(edit)
  box:EnableMouse(true)
  box:SetScript("OnMouseDown", function() edit:SetFocus() end)
  frame.edit = edit

  local message = Theme.Text(frame, "body")
  message:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -12)
  message:SetPoint("RIGHT", -16, 0)
  message:SetSpacing(3)
  frame.message = message

  local confirm = Theme.Button(frame, "Confirmar importação", "primary", 180)
  confirm:SetPoint("BOTTOMRIGHT", -16, 14)
  confirm:SetScript("OnClick", Confirm)
  frame.confirm = confirm

  local validate = Theme.Button(frame, "Validar", "outline", 100)
  validate:SetPoint("RIGHT", confirm, "LEFT", -8, 0)
  validate:SetScript("OnClick", Validate)

  local clear = Theme.Button(frame, "Limpar", "ghost", 80)
  clear:SetPoint("BOTTOMLEFT", 16, 14)
  clear:SetScript("OnClick", function()
    edit:SetText("")
    Reset()
    edit:SetFocus()
  end)

  frame:SetScript("OnShow", function()
    Reset()
    edit:SetFocus()
  end)
end

function ImportDialog.Show()
  if not frame then Build() end
  frame:Show()
end

ns.ImportDialog = ImportDialog
