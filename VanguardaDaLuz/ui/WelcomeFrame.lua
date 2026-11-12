-- Janela para quem não está na guilda: logo, nome e o convite do Discord.
-- É a única janela que o addon mostra para essas pessoas.
local _, ns = ...

local Theme = ns.Theme
local WelcomeFrame = {}

local frame

-- O jogo não deixa addons copiarem para a área de transferência: o link fica
-- selecionado num campo de texto para a pessoa usar Ctrl+C.
local function SelectLink()
  frame.link:SetText(ns.Config.DISCORD_URL)
  frame.link:SetFocus()
  frame.link:HighlightText()
end

local function Build()
  frame = Theme.Window("VanguardaDaLuzWelcomeFrame", 440, 250, ns.Config.GUILD_NAME)
  frame:SetFrameStrata("DIALOG")

  local text = Theme.Text(frame, "body")
  text:SetPoint("TOPLEFT", 16, -74)
  text:SetPoint("TOPRIGHT", -16, -74)
  text:SetSpacing(3)
  text:SetText("Você ainda não faz parte da guilda " .. ns.Config.GUILD_NAME .. ". "
    .. "Entre no nosso Discord para conhecer a guilda:")

  local box = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  box:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -14)
  box:SetPoint("RIGHT", -16, 0)
  box:SetHeight(32)
  Theme.Backdrop(box, "bgDeep", "borderField")

  local link = CreateFrame("EditBox", nil, box)
  link:SetPoint("TOPLEFT", 10, 0)
  link:SetPoint("BOTTOMRIGHT", -10, 0)
  link:SetAutoFocus(false)
  link:SetFontObject(Theme.Font("bodyStrong"))
  link:SetTextColor(unpack(Theme.colors.gold))
  -- Somente leitura: qualquer edição volta ao link selecionado.
  link:SetScript("OnTextChanged", function(_, userInput) if userInput then SelectLink() end end)
  link:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  link:SetScript("OnMouseUp", function(self) self:HighlightText() end)
  link:SetScript("OnEscapePressed", function() frame:Hide() end)
  link:SetScript("OnEnterPressed", function() frame:Hide() end)
  frame.link = link

  local hint = Theme.Text(frame, "small", "textMuted")
  hint:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -8)
  hint:SetText("O link já está selecionado: use Ctrl+C para copiar.")

  local close = Theme.Button(frame, "Fechar", "primary", 110)
  close:SetPoint("BOTTOMRIGHT", -16, 14)
  close:SetScript("OnClick", function() frame:Hide() end)

  frame:SetScript("OnShow", SelectLink)
end

function WelcomeFrame.Toggle()
  if not frame then Build() end
  frame:SetShown(not frame:IsShown())
end

function WelcomeFrame.Show()
  if not frame then Build() end
  frame:Show()
end

ns.WelcomeFrame = WelcomeFrame
