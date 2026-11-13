-- Modal de importação: colar a string, validar, ver o resumo e confirmar.
local _, ns = ...

local L = ns.L

local Theme, Time, Text = ns.Theme, ns.Time, ns.Text
local ImportDialog = {}

local frame
local prepared -- importação validada, à espera da confirmação

local function Brasilia() return ns.Config.BRASILIA_OFFSET end

local function Names(list, limit)
  local names = {}
  for i = 1, math.min(#list, limit) do names[i] = Text.Escape(list[i].event.title) end
  if #list > limit then names[#names + 1] = string.format(L["e mais %d"], #list - limit) end
  return table.concat(names, ", ")
end

local function Summary(p)
  local export, diff = p.export, p.diff
  local lastDay = export.windowEnd - 86400
  local lines = {
    Theme.Code("gold") .. L["Exportação válida"] .. "|r",
    string.format(L["Gerada em %s"], Time.FormatDateTime(export.exportNumber, Brasilia())) .. " " .. L["(Brasília)"],
    string.format(L["Janela: %s a %s"], Time.FormatDate(export.windowStart, Brasilia()),
      Time.FormatDate(lastDay, Brasilia()))
      .. "  ·  " .. string.format(L["%d evento(s) na exportação"], export.count),
    "",
  }
  local rows = {
    { L["Novos"], diff.created, "success" },
    { L["Alterados"], diff.updated, "azure" },
    { L["Cancelados"], diff.cancelled, "cancel" },
    { L["Removidos"], diff.removed, "warning" },
  }
  for _, row in ipairs(rows) do
    local line = Theme.Code(row[3]) .. row[1] .. ": " .. #row[2] .. "|r"
    if #row[2] > 0 then line = line .. "  " .. Theme.Code("textMuted") .. Names(row[2], 4) .. "|r" end
    lines[#lines + 1] = line
  end
  lines[#lines + 1] = Theme.Code("textMuted") .. string.format(L["Sem alteração: %d"], diff.unchanged)
    .. "  ·  " .. string.format(L["Fora da janela (mantidos): %d"], diff.outside) .. "|r"
  return table.concat(lines, "\n")
end

local function SetMessage(text, color)
  frame.message:SetText(text)
  frame.message:SetTextColor(unpack(Theme.colors[color or "text"]))
end

local function Reset()
  prepared = nil
  frame.confirm:Disable()
  SetMessage(L["Cole a string gerada em \"Exportar para o addon\" no site e clique em Validar."], "textMuted")
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
  ns.Print(string.format(L["Importação concluída: %d novo(s), %d alterado(s), %d cancelado(s), %d removido(s)."],
    #diff.created, #diff.updated, #diff.cancelled, #diff.removed))

  if ns.Guild.IsPlayerTrusted() then
    ns.Comm.Broadcast()
  else
    ns.Print(L["Seu cargo não está entre os aceitos pela guilda; a exportação não foi enviada aos membros."])
  end
end

local function Build()
  frame = Theme.Window("VanguardaDaLuzImportDialog", 620, 500, L["Importar eventos"])
  frame:SetFrameStrata("DIALOG")

  local help = Theme.Text(frame, "body", "textMuted")
  help:SetPoint("TOPLEFT", 16, -68)
  help:SetPoint("TOPRIGHT", -16, -68)
  help:SetText(L["No site, abra Administração de eventos > Exportar para o addon, clique em Copiar e cole "
    .. "abaixo com Ctrl+V."])

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

  local confirm = Theme.Button(frame, L["Confirmar importação"], "primary", 180)
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
    Reset()
    edit:SetFocus()
  end)

  frame:SetScript("OnShow", function()
    Reset()
    edit:SetFocus()
  end)
end

function ImportDialog.Show()
  if not ns.Guild.IsMember() then
    ns.WelcomeFrame.Show()
    return
  end
  if not ns.Guild.IsPlayerTrusted() then
    ns.Print(L["Somente o Grão Lorde e os Lordes podem importar eventos."])
    return
  end
  if not frame then Build() end
  frame:Show()
end

ns.ImportDialog = ImportDialog
