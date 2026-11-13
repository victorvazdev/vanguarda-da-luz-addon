-- Botão no minimapa (arrastável em volta dele) e entrada no compartimento de
-- addons (AddonCompartmentFunc no .toc). Clique abre a janela no Início;
-- clique direito abre um menu de atalhos.
local _, ns = ...

local Theme = ns.Theme
local MinimapButton = {}
local button
local menu
local MENU_WIDTH = 196
local MENU_CLOSE_DELAY = 2 -- segundos com o mouse fora do menu até ele fechar

local function Tooltip(owner)
  GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
  GameTooltip:AddLine("Vanguarda da Luz", 0.95, 0.79, 0.30)
  if ns.Guild.IsMember() then
    GameTooltip:AddLine("Clique: abrir o addon", 0.95, 0.93, 0.87)
    GameTooltip:AddLine("Clique direito: atalhos", 0.95, 0.93, 0.87)
  else
    GameTooltip:AddLine("Clique: convite para a guilda", 0.95, 0.93, 0.87)
  end
  GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Menu de atalhos

local function Items()
  local items = {
    { label = "Início", action = function() ns.MainFrame.Open("home") end },
    { label = "Eventos", action = function() ns.MainFrame.Open("events") end },
    { label = "Profissões", action = function() ns.MainFrame.Open("professions") end },
    { label = "Sincronizar", action = function() ns.Comm.RequestLatest() end },
  }
  if ns.Guild.IsPlayerTrusted() then
    items[#items + 1] = { label = "Administração", action = function() ns.MainFrame.Open("admin") end }
  end
  local hidden = ns.db.settings.minimap.hide
  items[#items + 1] = {
    label = hidden and "Mostrar botão do minimapa" or "Esconder botão do minimapa",
    action = function() MinimapButton.Toggle() end,
  }
  return items
end

local function CloseMenu()
  if menu then menu:Hide() end
end

-- Fecha sozinho quando o mouse fica um tempo fora do menu e do botão.
local function MenuOnUpdate(self, elapsed)
  if self:IsMouseOver() or (button and button:IsShown() and button:IsMouseOver()) then
    self.away = 0
    return
  end
  self.away = (self.away or 0) + elapsed
  if self.away >= MENU_CLOSE_DELAY then self:Hide() end
end

local function BuildMenu()
  menu = CreateFrame("Frame", "VanguardaDaLuzMinimapMenu", UIParent, "BackdropTemplate")
  menu:SetWidth(MENU_WIDTH + 12)
  menu:SetFrameStrata("FULLSCREEN_DIALOG")
  menu:SetClampedToScreen(true)
  Theme.Backdrop(menu, "surfaceRaised", "goldDeep")
  menu:Hide()
  menu:SetScript("OnUpdate", MenuOnUpdate)
  menu:SetScript("OnShow", function(self) self.away = 0 end)
  table.insert(UISpecialFrames, "VanguardaDaLuzMinimapMenu") -- Esc fecha
  menu.buttons = {}
end

local function OpenMenu()
  if not menu then BuildMenu() end
  local items = Items()
  for i, item in ipairs(items) do
    local b = menu.buttons[i]
    if not b then
      b = Theme.Button(menu, "", "ghost", MENU_WIDTH)
      b:SetHeight(24)
      b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 26)
      b.label:ClearAllPoints()
      b.label:SetPoint("LEFT", 10, 0)
      b:SetScript("OnClick", function(self)
        CloseMenu()
        self.action()
      end)
      menu.buttons[i] = b
    end
    b.action = item.action
    b:SetText(item.label)
    b:Show()
  end
  for i = #items + 1, #menu.buttons do menu.buttons[i]:Hide() end
  menu:SetHeight(12 + #items * 26 - 2)

  menu:ClearAllPoints()
  if button and button:IsShown() then
    menu:SetPoint("TOPRIGHT", button, "BOTTOMLEFT", 8, 8)
  else
    -- Aberto pelo compartimento de addons: junto do cursor.
    local scale = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    menu:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
  end
  menu:Show()
end

local function OnClick(_, mouseButton)
  if not ns.Guild.IsMember() then
    ns.MainFrame.Toggle() -- fora da guilda: boas-vindas
  elseif mouseButton == "RightButton" then
    if menu and menu:IsShown() then CloseMenu() else OpenMenu() end
  else
    CloseMenu()
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
  if ns.db.settings.minimap.hide then
    ns.Print("Botão do minimapa escondido. Use /vdl minimapa para mostrar de novo.")
  end
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
