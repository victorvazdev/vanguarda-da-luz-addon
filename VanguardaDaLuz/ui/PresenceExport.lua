-- Exportar presenças: gera a string VDLP1 (docs/formato-string-presencas.md)
-- para um administrador colar no site. Só para os cargos aceitos.
local _, ns = ...

local L = ns.L

local Theme = ns.Theme
local PresenceExport = {}

local frame
local current = "" -- string gerada ao abrir

local function Select()
  frame.edit:SetText(current)
  frame.edit:SetFocus()
  frame.edit:HighlightText()
end

local function Build()
  frame = Theme.Window("VanguardaDaLuzPresenceExport", 560, 330, L["Exportar presenças"])
  frame:SetFrameStrata("DIALOG")

  local help = Theme.Text(frame, "body")
  help:SetPoint("TOPLEFT", 16, -70)
  help:SetPoint("TOPRIGHT", -16, -70)
  help:SetSpacing(3)
  help:SetText(L["Confirmações e cancelamentos do jogo nos eventos que ainda não começaram. "
    .. "Copie com Ctrl+C e cole no site, na administração de eventos."])

  local box = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  box:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -12)
  box:SetPoint("RIGHT", -16, 0)
  box:SetHeight(130)
  Theme.Backdrop(box, "bgDeep", "borderField")

  local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 8, -8)
  scroll:SetPoint("BOTTOMRIGHT", -28, 8)
  local edit = CreateFrame("EditBox", nil, scroll)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(false)
  edit:SetFontObject(Theme.Font("small"))
  edit:SetTextColor(unpack(Theme.colors.text))
  edit:SetWidth(480)
  edit:SetMaxLetters(0)
  if edit.SetMaxBytes then edit:SetMaxBytes(0) end
  -- Somente leitura: qualquer edição volta à string selecionada.
  edit:SetScript("OnTextChanged", function(_, userInput) if userInput then Select() end end)
  edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  edit:SetScript("OnEscapePressed", function() frame:Hide() end)
  scroll:SetScrollChild(edit)
  frame.edit = edit

  local summary = Theme.Text(frame, "small", "textMuted")
  summary:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -8)
  summary:SetPoint("RIGHT", -16, 0)
  frame.summary = summary

  local close = Theme.Button(frame, L["Fechar"], "primary", 110)
  close:SetPoint("BOTTOMRIGHT", -16, 14)
  close:SetScript("OnClick", function() frame:Hide() end)

  frame:SetScript("OnShow", function()
    current = ns.Presence.ExportString()
    local data = ns.PresenceCodec.Decode(current)
    local events, confirmed, cancelled = 0, 0, 0
    for _, list in pairs(data and data.store or {}) do
      events = events + 1
      for _, record in pairs(list) do
        if record.s == 1 then confirmed = confirmed + 1 else cancelled = cancelled + 1 end
      end
    end
    summary:SetText(string.format(L["%d evento(s)  ·  %d confirmação(ões)  ·  %d cancelamento(s)"],
      events, confirmed, cancelled))
    Select()
  end)
end

function PresenceExport.Show()
  if not ns.Guild.IsMember() then
    ns.WelcomeFrame.Show()
    return
  end
  if not ns.Guild.IsPlayerTrusted() then
    ns.Print(L["Somente o Grão Lorde e os Lordes podem exportar as presenças."])
    return
  end
  if not frame then Build() end
  frame:Show()
end

ns.PresenceExport = PresenceExport
