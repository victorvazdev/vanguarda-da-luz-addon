-- Item level e main/alt na lista de membros da janela "Guilda e comunidades".
--
-- Cada linha ganha um texto curto à direita ("231 · Alt") e o tooltip da linha
-- ganha o texto completo ("Item level 231 · Alt de Victor Vaz"). O addon só
-- acrescenta: observa SetMember das linhas com hooksecurefunc, cria o próprio
-- texto e não altera os textos da Blizzard. Nomes em Flavor.guildWindow.
local _, ns = ...

local Theme = ns.Theme
local GuildRoster = {}

local host, list
local labels = setmetatable({}, { __mode = "k" })  -- [linha] = texto do addon
local names = setmetatable({}, { __mode = "k" })   -- [linha] = membro exibido
local hooked = setmetatable({}, { __mode = "k" })  -- [linha] = true

local function Spec() return ns.Flavor.guildWindow end

local function GuildSelected()
  return ns.Store.GuildFeature("roster") and ns.Guild.IsMember() and ns.Flavor.IsGuildClubSelected(host)
end

local function Paint(row)
  local label = labels[row]
  if not label then return end
  local name = GuildSelected() and names[row]
  local text = name and ns.Members.Short(name, ns.GuildMembers.Get(name)) or nil
  label:SetText(text or "")
  label:SetShown(text ~= nil)
end

local function OnEnter(row)
  local name = GuildSelected() and names[row]
  local detail = name and ns.Members.Detail(name, ns.GuildMembers.Get(name)) or nil
  if not detail then return end
  -- Acrescenta ao tooltip da Blizzard; sem ele, mostra um próprio.
  if not (GameTooltip:IsShown() and GameTooltip:GetOwner() == row) then
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(name)
  end
  GameTooltip:AddLine(detail, 0.95, 0.79, 0.30)
  GameTooltip:Show()
end

local function OnSetMember(row, memberInfo)
  names[row] = type(memberInfo) == "table" and memberInfo.name or nil
  if not labels[row] then
    local label = Theme.Text(row, "small", "gold", "OVERLAY")
    label:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    label:SetJustifyH("RIGHT")
    labels[row] = label
    row:HookScript("OnEnter", OnEnter)
  end
  Paint(row)
end

-- Observa uma linha criada antes do gancho no mixin.
local function HookRow(row)
  if hooked[row] or not row.SetMember then return end
  hooked[row] = true
  hooksecurefunc(row, "SetMember", OnSetMember)
end

-- Linhas visíveis da lista.
local function ForEachRow(fn)
  local box = list and list.ScrollBox
  if box and box.ForEachFrame then box:ForEachFrame(fn) end
end

function GuildRoster.Refresh()
  ForEachRow(function(row)
    HookRow(row)
    Paint(row)
  end)
end

local function Setup()
  if host then return end
  local spec = Spec()
  host = _G[spec.frame]
  list = host and host[spec.memberList]
  if not list then
    host = nil
    return
  end
  -- Linhas criadas depois daqui já vêm com o gancho do mixin.
  local mixin = _G[spec.memberEntryMixin]
  if mixin and mixin.SetMember then
    hooksecurefunc(mixin, "SetMember", function(row, ...)
      hooked[row] = true
      OnSetMember(row, ...)
    end)
  end
  GuildRoster.labels = labels -- para o teste de fumaça
  list:HookScript("OnShow", GuildRoster.Refresh)
  ns.On("MEMBERS_UPDATED", GuildRoster.Refresh)
  ns.On("SETTINGS_UPDATED", GuildRoster.Refresh)
  GuildRoster.Refresh()
end

-- A janela da guilda só carrega na primeira vez que é aberta.
function GuildRoster.Init()
  local addon = Spec().addon
  if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(addon) then
    Setup()
    return
  end
  local events = CreateFrame("Frame")
  events:SetScript("OnEvent", function(self, _, name)
    if name == addon then
      self:UnregisterEvent("ADDON_LOADED")
      Setup()
    end
  end)
  events:RegisterEvent("ADDON_LOADED")
end

ns.GuildRoster = GuildRoster
