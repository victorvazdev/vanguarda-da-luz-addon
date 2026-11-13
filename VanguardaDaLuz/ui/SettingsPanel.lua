-- Painel Configurações da janela do addon: main da conta, botão do minimapa e
-- funcionalidades do addon na janela da guilda.
local _, ns = ...

local L = ns.L

local Theme = ns.Theme
local SettingsPanel = {}

local GAP = 16
local PAD = 16
local ROW = 32

local Panel = {}
Panel.__index = Panel

local function Card(parent, title, description)
  local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  Theme.Backdrop(card, "surface", "border")
  card.title = Theme.Text(card, "heading", "gold")
  card.title:SetPoint("TOPLEFT", PAD, -14)
  card.title:SetPoint("RIGHT", -PAD, 0)
  card.title:SetText(title)
  card.text = Theme.Text(card, "small", "textMuted")
  card.text:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -6)
  card.text:SetPoint("RIGHT", -PAD, 0)
  card.text:SetText(description)
  return card
end

function Panel:Refresh()
  local name = ns.Guild.PlayerName()
  self.main:SetValue(ns.GuildMembers.IsMain())
  self.main:SetEnabled(name ~= nil)
  local current = ns.db.settings.main
  if current and current ~= name then
    self.mainNote:SetText(string.format(L["Main atual da conta: %s. Este personagem aparece como alt."],
      ns.Text.Escape(current)))
  elseif current then
    self.mainNote:SetText(L["Os outros personagens desta conta na guilda aparecem como alts deste."])
  else
    self.mainNote:SetText(L["Nenhum main definido nesta conta."])
  end
  self.minimap:SetValue(ns.MinimapButton.IsShown())
  -- Opções visíveis, uma abaixo da outra (Administração só para Grão Lorde e Lordes).
  local trusted = ns.Guild.IsPlayerTrusted()
  local previous, count = self.guild.text, 0
  for _, feature in ipairs(ns.Store.GUILD_FEATURES) do
    local toggle = self.features[feature.key]
    local visible = trusted or not feature.trusted
    toggle:SetShown(visible)
    toggle:SetValue(ns.Store.GuildFeature(feature.key))
    if visible then
      toggle:ClearAllPoints()
      toggle:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, count == 0 and -12 or -(ROW - 26))
      previous, count = toggle, count + 1
    end
  end
  self.guild:SetHeight(96 + count * ROW)
end

-- Cria o painel dentro de `parent`, com `width` x `height`.
function SettingsPanel.Create(parent, width, height)
  local self = setmetatable({ features = {} }, Panel)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetSize(width, height)
  self.frame = frame
  local colW = math.floor((width - GAP) / 2)
  local toggleW = colW - 2 * PAD

  -- Personagem
  local character = Card(frame, L["Personagem"],
    L["O item level e o main/alt aparecem na lista de Membros da janela da guilda."])
  character:SetPoint("TOPLEFT")
  character:SetSize(colW, 150)
  self.main = Theme.Toggle(character, L["Este personagem é o meu main"], toggleW, function(value)
    if value then ns.GuildMembers.SetMain() else ns.GuildMembers.ClearMain() end
  end)
  self.main:SetPoint("TOPLEFT", character.text, "BOTTOMLEFT", 0, -12)
  self.mainNote = Theme.Text(character, "small", "textMuted")
  self.mainNote:SetPoint("TOPLEFT", self.main, "BOTTOMLEFT", 30, -4)
  self.mainNote:SetPoint("RIGHT", -PAD, 0)

  -- Minimapa
  local minimap = Card(frame, L["Minimapa"], L["O compartimento de addons e /vdl continuam abrindo o addon."])
  minimap:SetPoint("TOPLEFT", character, "BOTTOMLEFT", 0, -GAP)
  minimap:SetSize(colW, 110)
  self.minimap = Theme.Toggle(minimap, L["Mostrar o botão no minimapa"], toggleW, function(value)
    ns.MinimapButton.SetShown(value)
  end)
  self.minimap:SetPoint("TOPLEFT", minimap.text, "BOTTOMLEFT", 0, -12)

  -- Janela da guilda
  local guild = Card(frame, L["Janela da guilda"],
    L["O que o addon acrescenta à janela Guilda e comunidades (J). Desligado, a janela fica como a da Blizzard."])
  guild:SetPoint("TOPRIGHT")
  guild:SetSize(colW, 96 + #ns.Store.GUILD_FEATURES * ROW)
  self.guild = guild
  -- A posição de cada opção é definida em Refresh, conforme o cargo.
  for _, feature in ipairs(ns.Store.GUILD_FEATURES) do
    self.features[feature.key] = Theme.Toggle(guild, feature.label, toggleW, function(value)
      ns.Store.SetGuildFeature(feature.key, value)
    end)
  end

  return self
end

ns.SettingsPanel = SettingsPanel
