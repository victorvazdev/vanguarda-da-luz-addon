-- Popup ao logar: "Este personagem é o seu main?", quando a conta ainda não
-- tem main na guilda. Regras de quando perguntar em game/GuildMembers.lua.
local _, ns = ...

local L = ns.L

local Theme = ns.Theme
local MainPrompt = {}

local frame

local function Later()
  ns.Print(L["Você pode definir o main depois em Configurações ou com /vdl main."])
end

local function Build()
  frame = Theme.Window("VanguardaDaLuzMainPrompt", 460, 230, L["Seu main"])
  frame:SetFrameStrata("DIALOG")

  local question = Theme.Text(frame, "heading")
  question:SetPoint("TOPLEFT", 16, -74)
  question:SetPoint("TOPRIGHT", -16, -74)
  frame.question = question

  local text = Theme.Text(frame, "body", "textMuted")
  text:SetPoint("TOPLEFT", question, "BOTTOMLEFT", 0, -10)
  text:SetPoint("RIGHT", -16, 0)
  text:SetSpacing(3)
  text:SetText(L["O main é o personagem principal da conta. Os outros personagens desta conta na guilda "
    .. "aparecem como alts dele na lista de membros e somam o tempo com a guilda."])

  local yes = Theme.Button(frame, L["Sim, é o meu main"], "primary", 160)
  yes:SetPoint("BOTTOMRIGHT", -16, 14)
  yes:SetScript("OnClick", function()
    frame:Hide()
    ns.GuildMembers.SetMain()
  end)

  local no = Theme.Button(frame, L["Não"], "outline", 80)
  no:SetPoint("RIGHT", yes, "LEFT", -8, 0)
  no:SetScript("OnClick", function()
    frame:Hide()
    ns.GuildMembers.DeclineMain()
    Later()
  end)

  local never = Theme.Button(frame, L["Não perguntar mais"], "ghost", 150)
  never:SetPoint("BOTTOMLEFT", 16, 14)
  never:SetScript("OnClick", function()
    frame:Hide()
    ns.GuildMembers.StopAskingMain()
    Later()
  end)
end

-- Mostra o popup se for o caso.
function MainPrompt.ShowIfNeeded()
  if not ns.GuildMembers.ShouldAskMain() then return end
  if not frame then Build() end
  frame.question:SetText(string.format(L["%s é o seu main?"], ns.Text.Escape(ns.Guild.PlayerName())))
  frame:Show()
end

ns.MainPrompt = MainPrompt
