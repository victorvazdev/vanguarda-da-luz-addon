-- Janela Profissões: o painel ui/ProfessionsPanel.lua numa janela própria.
-- Para todos os membros.
local _, ns = ...

local Theme = ns.Theme
local ProfessionsFrame = {}

local WIDTH, HEIGHT = 720, 580
local PAD = 20

local frame

function ProfessionsFrame.Refresh()
  if frame and frame:IsShown() then frame.panel:Refresh() end
end

local function Build()
  frame = Theme.Window("VanguardaDaLuzProfessionsFrame", WIDTH, HEIGHT, "Profissões da guilda")
  frame:SetFrameStrata("DIALOG")
  frame:SetScript("OnShow", function()
    ns.Guild.RequestRoster()
    ProfessionsFrame.Refresh()
  end)

  local panel = ns.ProfessionsPanel.Create(frame, WIDTH - 2 * PAD, HEIGHT - 74 - 62)
  panel.frame:SetPoint("TOPLEFT", PAD, -74)
  frame.panel = panel
  -- Atalhos usados pelo teste de fumaça.
  frame.rows, frame.count, frame.online = panel.rows, panel.count, panel.online

  local footerLine = Theme.Divider(frame)
  footerLine:SetPoint("BOTTOMLEFT", 12, 52)
  footerLine:SetPoint("BOTTOMRIGHT", -12, 52)

  local hint = Theme.Text(frame, "small", "textMuted")
  hint:SetPoint("BOTTOMLEFT", PAD, 22)
  hint:SetPoint("RIGHT", -150, 0)
  hint:SetText("Os níveis vêm do addon de cada membro. Sem o addon, o nível aparece como —.")

  local close = Theme.Button(frame, "Fechar", "primary", 110)
  close:SetPoint("BOTTOMRIGHT", -PAD, 14)
  close:SetScript("OnClick", function() frame:Hide() end)

  ns.On("PROFESSIONS_UPDATED", ProfessionsFrame.Refresh)
end

function ProfessionsFrame.Toggle()
  if not ns.Guild.IsMember() then
    ns.WelcomeFrame.Show()
    return
  end
  if not frame then Build() end
  frame:SetShown(not frame:IsShown())
end

ns.ProfessionsFrame = ProfessionsFrame
