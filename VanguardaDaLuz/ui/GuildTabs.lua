-- Abas do addon na janela "Guilda e comunidades" da interface padrão: Eventos,
-- Profissões e Administração (só Grão Lorde e Lordes), abaixo dos botões
-- laterais da Blizzard.
--
-- Para não interferir na janela da Blizzard, o addon só acrescenta: os botões
-- são próprios, e o painel do addon fica por cima da área de conteúdo, sem
-- esconder nem alterar os quadros dela. Os nomes dos quadros estão em
-- Flavor.guildWindow.
local _, ns = ...

local Theme = ns.Theme
local GuildTabs = {}

local INSET = 10 -- margem do painel dentro da área coberta

local host, overlay
local tabs = {}         -- [nome] = botão
local order = {}        -- nomes na ordem dos botões
local panels = {}       -- [nome] = painel criado
local active = nil      -- aba do addon aberta
local restore = {}      -- botões da Blizzard que estavam marcados
local ours = {}         -- [botão] = true, para não confundir com os da Blizzard
local hooked = {}       -- botões da Blizzard com o clique já observado

local TABS = {
  { key = "events", tooltip = "Eventos da guilda" },
  { key = "professions", tooltip = "Profissões da guilda" },
  { key = "admin", tooltip = "Administração do addon", trusted = true },
}

local function Spec() return ns.Flavor.guildWindow end

-- Marca ou desmarca um botão do addon (o brilho é uma textura própria).
local function Mark(tab, value)
  tab:SetChecked(value)
  tab.checkedGlow:SetShown(value)
end

local function Visible(key)
  local spec = Spec()
  local anchor = host and host[spec.lastTab]
  if not (anchor and anchor:IsShown() and ns.Guild.IsMember()) then return false end
  -- Janela minimizada: não há espaço para o painel.
  if (host:GetWidth() or 0) < spec.minWidth then return false end
  if key == "admin" then return ns.Guild.IsPlayerTrusted() end
  return true
end

local function Deactivate() end -- definida abaixo

-- Recalcula a posição dos botões no próximo quadro, quando a Blizzard já
-- terminou de mostrar e esconder os dela (vários avisos viram um só cálculo).
local pending = false
local function ScheduleUpdate()
  if pending then return end
  pending = true
  C_Timer.After(0, function()
    pending = false
    GuildTabs.Update()
  end)
end

-- Botões laterais da Blizzard: os conhecidos pelo nome e qualquer outro botão
-- de 32x32 alinhado com eles (no WoW Forever há um 5º, o de idioma da guilda,
-- e outros podem aparecer conforme o cargo). Observa o clique de cada um.
local function BlizzardTabs()
  local spec = Spec()
  local list, seen = {}, {}
  local function Add(tab)
    if tab and not seen[tab] and not ours[tab] then
      seen[tab] = true
      list[#list + 1] = tab
      if not hooked[tab] then
        hooked[tab] = true
        tab:HookScript("OnClick", function() Deactivate() end)
        tab:HookScript("OnShow", ScheduleUpdate)
        tab:HookScript("OnHide", ScheduleUpdate)
      end
    end
  end
  for _, name in ipairs(spec.tabs) do Add(host[name]) end
  local left = host[spec.lastTab]:GetLeft()
  for _, child in ipairs({ host:GetChildren() }) do
    if child.GetObjectType and child:GetObjectType() == "CheckButton" then
      local w, h = child:GetSize()
      local x = child:GetLeft()
      if w and h and math.abs(w - 32) < 1 and math.abs(h - 32) < 1 and x and left and math.abs(x - left) < 2 then
        Add(child)
      end
    end
  end
  return list
end

-- Botão da Blizzard visível mais baixo: os do addon ficam abaixo dele.
local function LowestBlizzardTab()
  local lowest = host[Spec().lastTab]
  local bottom = lowest:GetBottom()
  for _, tab in ipairs(BlizzardTabs()) do
    local b = tab:IsShown() and tab:GetBottom()
    if b and (not bottom or b < bottom) then lowest, bottom = tab, b end
  end
  return lowest
end

-- Tamanho útil do painel dentro da área coberta.
local function PanelSize()
  local w, h = overlay:GetWidth() or 0, overlay:GetHeight() or 0
  if w < 300 or h < 250 then w, h = 640, 380 end
  return w - 2 * INSET, h - 2 * INSET
end

local function CreatePanel(key)
  local w, h = PanelSize()
  local panel
  if key == "events" then
    panel = ns.CalendarPanel.Create(overlay, w, "compact", h)
  elseif key == "professions" then
    panel = ns.ProfessionsPanel.Create(overlay, w, h)
  else
    panel = ns.AdminPanel.Create(overlay, w, h)
  end
  panel.frame:SetPoint("TOPLEFT", INSET, -INSET)
  panels[key] = panel
  return panel
end

function GuildTabs.Refresh()
  if active and overlay:IsShown() then panels[active]:Refresh() end
end

function Deactivate()
  if not active then return end
  active = nil
  restore = {}
  overlay:Hide()
  for _, tab in pairs(tabs) do Mark(tab, false) end
end

-- Fecha o painel e devolve a marcação aos botões da Blizzard.
local function Close()
  if not active then return end
  local marked = restore
  Deactivate()
  for _, tab in ipairs(marked) do tab:SetChecked(true) end
end

local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5,
  FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }

-- Põe o painel acima de tudo o que a janela da guilda mostra. Alguns quadros
-- dela (barra de rolagem e caixa de texto do bate-papo) ficam em camadas mais
-- altas que a própria janela, então a camada é medida ao abrir o painel.
local function Raise()
  local strata, level = host:GetFrameStrata() or "MEDIUM", host:GetFrameLevel() or 0
  local function Visit(frame)
    for _, child in ipairs({ frame:GetChildren() }) do
      if child ~= overlay and child:IsShown() then
        local s, l = child:GetFrameStrata(), child:GetFrameLevel() or 0
        if s and (STRATA[s] or 0) > (STRATA[strata] or 0) then
          strata, level = s, l
        elseif s == strata and l > level then
          level = l
        end
        Visit(child)
      end
    end
  end
  Visit(host)
  overlay:SetFrameStrata(strata)
  overlay:SetFrameLevel(math.min(level + 10, 9000))
end

local function Activate(key)
  if not Visible(key) then return end
  -- Guarda a marcação da Blizzard só ao abrir o painel, não ao trocar de aba.
  if not active then
    restore = {}
    for _, tab in ipairs(BlizzardTabs()) do
      if tab:GetChecked() then restore[#restore + 1] = tab end
      tab:SetChecked(false)
    end
  end
  active = key
  for name, tab in pairs(tabs) do Mark(tab, name == key) end
  local panel = panels[key] or CreatePanel(key)
  for name, other in pairs(panels) do other.frame:SetShown(name == key) end
  Raise()
  overlay:Show()
  if key == "professions" then ns.Guild.RequestRoster() end
  panel:Refresh()
end

-- Mostra os botões quando a guilda está selecionada (junto com o último botão
-- da Blizzard) e fecha o painel quando eles somem.
function GuildTabs.Update()
  if not host then return end
  local first = tabs[order[1]]
  first:ClearAllPoints()
  first:SetPoint("TOPLEFT", LowestBlizzardTab(), "BOTTOMLEFT", 0, -Spec().tabGap)
  for _, key in ipairs(order) do tabs[key]:SetShown(Visible(key)) end
  if active and not Visible(active) then Close() end
end

-- Botão lateral no mesmo estilo dos da Blizzard (moldura do livro de feitiços).
local function CreateTab(spec, previous)
  local tab = CreateFrame("CheckButton", "VanguardaDaLuzGuildTab_" .. spec.key, host)
  tab:SetSize(32, 32)
  tab:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -Spec().tabGap)
  local frameArt = tab:CreateTexture(nil, "BACKGROUND")
  frameArt:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
  frameArt:SetSize(64, 64)
  frameArt:SetPoint("TOPLEFT", -3, 11)
  local icon = tab:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  icon:SetTexture(Spec().icons[spec.key] or (ns.path .. "assets\\logo-64"))
  -- Brilho por cima do ícone (modo ADD), sem cobri-lo.
  local highlight = tab:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetAllPoints()
  highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
  highlight:SetBlendMode("ADD")
  local checked = tab:CreateTexture(nil, "OVERLAY")
  checked:SetAllPoints()
  checked:SetTexture("Interface\\Buttons\\CheckButtonHilight")
  checked:SetBlendMode("ADD")
  checked:Hide()
  tab.checkedGlow = checked
  tab:SetScript("OnClick", function()
    if active == spec.key then
      Mark(tab, true)
    else
      Mark(tab, false) -- o clique inverte a marcação; Activate marca de novo
      Activate(spec.key)
    end
  end)
  tab:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(spec.tooltip)
    GameTooltip:Show()
  end)
  tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
  tab:Hide()
  return tab
end

local function Setup()
  if host then return end
  local spec = Spec()
  local frame = _G[spec.frame]
  local anchor = frame and frame[spec.lastTab]
  if not anchor then return end
  host = frame

  -- Área coberta: da lista de comunidades até a borda direita.
  overlay = CreateFrame("Frame", "VanguardaDaLuzGuildPanel", host, "BackdropTemplate")
  local list = host[spec.list]
  if list then
    overlay:SetPoint("TOPLEFT", list, "TOPRIGHT", 6, 0)
  else
    overlay:SetPoint("TOPLEFT", 170, -30)
  end
  overlay:SetPoint("BOTTOMRIGHT", -8, 8)
  overlay:SetFrameLevel((host:GetFrameLevel() or 0) + 100)
  overlay:EnableMouse(true)
  Theme.Backdrop(overlay, "bg", "goldDeep")
  overlay:Hide()
  GuildTabs.overlay = overlay

  local previous = anchor
  for _, tabSpec in ipairs(TABS) do
    local tab = CreateTab(tabSpec, previous)
    tabs[tabSpec.key] = tab
    ours[tab] = true
    order[#order + 1] = tabSpec.key
    previous = tab
  end
  GuildTabs.tabs = tabs

  -- Clique num botão da Blizzard: ela troca o conteúdo e o painel do addon sai
  -- (BlizzardTabs observa o clique de cada botão que encontra).
  BlizzardTabs()
  anchor:HookScript("OnShow", GuildTabs.Update)
  anchor:HookScript("OnHide", GuildTabs.Update)
  -- Os botões da Blizzard se arrumam depois de a janela aparecer e a cada
  -- troca de modo (Bate-papo, Membros...).
  host:HookScript("OnShow", function()
    GuildTabs.Update()
    ScheduleUpdate()
  end)
  if host.SetDisplayMode then hooksecurefunc(host, "SetDisplayMode", ScheduleUpdate) end
  host:HookScript("OnSizeChanged", GuildTabs.Update)
  host:HookScript("OnHide", Close)

  ns.On("DATA_UPDATED", GuildTabs.Refresh)
  ns.On("ATTENDANCE_UPDATED", GuildTabs.Refresh)
  ns.On("SYNC_STATUS", GuildTabs.Refresh)
  ns.On("PROFESSIONS_UPDATED", function()
    GuildTabs.Update()
    GuildTabs.Refresh()
  end)
  GuildTabs.Update()
end

-- A janela da guilda só carrega na primeira vez que é aberta.
function GuildTabs.Init()
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

ns.GuildTabs = GuildTabs
