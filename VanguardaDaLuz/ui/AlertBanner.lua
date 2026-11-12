-- Aviso de raide no centro da tela, com o som padrão. Usa o quadro de aviso
-- de raide da interface padrão e, se ele não existir, uma faixa própria.
local _, ns = ...

local Theme, Text = ns.Theme, ns.Text
local AlertBanner = {}

local banner
local shownAt = 0

local function BuildBanner()
  banner = CreateFrame("Frame", "VanguardaDaLuzAlertBanner", UIParent)
  banner:SetFrameStrata("FULLSCREEN_DIALOG")
  banner:SetSize(720, 60)
  banner:SetPoint("TOP", 0, -180)
  banner:EnableMouse(false)
  local text = Theme.Text(banner, "title", "gold")
  text:SetPoint("TOPLEFT")
  text:SetPoint("TOPRIGHT")
  text:SetJustifyH("CENTER")
  text:SetShadowOffset(1, -1)
  banner.text = text
  banner:Hide()
end

local function ShowBanner(line)
  if not banner then BuildBanner() end
  banner.text:SetText(line)
  banner:Show()
  shownAt = GetTime()
  local mine = shownAt
  C_Timer.After(ns.Config.ALERT_DISPLAY_SECONDS, function()
    if shownAt == mine then banner:Hide() end
  end)
end

-- text já vem limpo (logic/Alert.lua), sem "|".
function AlertBanner.Show(text, sender)
  local line = Text.Escape(sender or "") .. ": " .. text
  local gold = Theme.colors.gold
  if not ns.Flavor.ShowRaidWarning(line, { r = gold[1], g = gold[2], b = gold[3] }) then
    ShowBanner(line)
  end
  ns.Flavor.PlayRaidWarningSound()
end

ns.AlertBanner = AlertBanner
