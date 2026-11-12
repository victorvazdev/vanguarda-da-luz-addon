-- Botão no minimapa (arrastável em volta dele) e entrada no compartimento de
-- addons (AddonCompartmentFunc no .toc).
local _, ns = ...

local MinimapButton = {}
local button

local function Tooltip(owner)
  GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
  GameTooltip:AddLine("Vanguarda da Luz", 0.95, 0.79, 0.30)
  if ns.Guild.IsMember() then
    GameTooltip:AddLine("Clique: abrir o calendário", 0.95, 0.93, 0.87)
    GameTooltip:AddLine("Clique direito: importar eventos", 0.95, 0.93, 0.87)
  else
    GameTooltip:AddLine("Clique: convite para a guilda", 0.95, 0.93, 0.87)
  end
  GameTooltip:Show()
end

local function OnClick(_, mouseButton)
  if mouseButton == "RightButton" then
    ns.ImportDialog.Show()
  else
    ns.MainFrame.Toggle()
  end
end

local function Place()
  local angle = math.rad(ns.db.settings.minimap.angle or 210)
  local radius = (Minimap:GetWidth() / 2) + 5
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OnDragUpdate()
  local mx, my = Minimap:GetCenter()
  local scale = Minimap:GetEffectiveScale()
  local cx, cy = GetCursorPosition()
  cx, cy = cx / scale, cy / scale
  ns.db.settings.minimap.angle = math.deg(math.atan2(cy - my, cx - mx))
  Place()
end

function MinimapButton.Init()
  button = CreateFrame("Button", "VanguardaDaLuzMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local background = button:CreateTexture(nil, "BACKGROUND")
  background:SetSize(24, 24)
  background:SetPoint("CENTER")
  background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER")
  icon:SetTexture(ns.path .. "assets\\logo-64")

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

  button:SetScript("OnClick", OnClick)
  button:SetScript("OnEnter", Tooltip)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
  button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", OnDragUpdate) end)
  button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

  Place()
  button:SetShown(not ns.db.settings.minimap.hide)
end

function MinimapButton.Toggle()
  ns.db.settings.minimap.hide = not ns.db.settings.minimap.hide
  button:SetShown(not ns.db.settings.minimap.hide)
end

-- Funções globais do compartimento de addons (nomes definidos no .toc).
function VanguardaDaLuz_OnAddonCompartmentClick(_, mouseButton)
  OnClick(nil, mouseButton)
end

function VanguardaDaLuz_OnAddonCompartmentEnter(_, menuButton)
  Tooltip(menuButton)
end

function VanguardaDaLuz_OnAddonCompartmentLeave()
  GameTooltip:Hide()
end

ns.MinimapButton = MinimapButton
