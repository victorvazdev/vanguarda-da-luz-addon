-- Painel Configurações da janela do addon: main da conta, botão do minimapa,
-- atalho de teclado, funcionalidades do addon na janela da guilda e membros no
-- mapa-múndi.
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
  self.mapShare:SetValue(ns.GuildMap.IsSharing())
  self.mapShow:SetValue(ns.GuildMap.IsShown())
  self:RefreshKey()
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

-- Botão do atalho e a nota abaixo dele.
function Panel:RefreshKey()
  local combo = ns.Keybind.Get()
  self.clearKey:SetEnabled(combo ~= nil and not self.capturing)
  if self.capturing then
    self.key:SetText(L["Pressione uma tecla…"])
    self.keyNote:SetText(L["Esc cancela. Pode combinar com Shift, Ctrl ou Alt."])
    return
  end
  self.key:SetText(combo and ns.Keybind.Text(combo) or L["Nenhum"])
  local conflict = ns.Keybind.Conflict(combo)
  if ns.Keybind.IsPending() then
    self.keyNote:SetText(L["Será aplicado ao sair do combate."])
  elseif conflict then
    self.keyNote:SetText(string.format(L["Esta tecla também está em \"%s\" nos atalhos do jogo; "
      .. "o addon tem prioridade."], conflict))
  else
    self.keyNote:SetText(L["Clique no botão e pressione a tecla."])
  end
end

-- Liga ou desliga a captura da próxima tecla.
function Panel:Capture(on)
  self.capturing = on
  self.key:EnableKeyboard(on)
  self:RefreshKey()
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

  -- Atalho de teclado
  local shortcut = Card(frame, L["Atalho"], L["Tecla para abrir e fechar a janela do addon. Fica salva na conta."])
  shortcut:SetPoint("TOPLEFT", minimap, "BOTTOMLEFT", 0, -GAP)
  shortcut:SetSize(colW, 130)
  self.key = Theme.Button(shortcut, L["Nenhum"], "outline", 180)
  self.key:SetPoint("TOPLEFT", shortcut.text, "BOTTOMLEFT", 0, -12)
  self.key:SetScript("OnClick", function() self:Capture(not self.capturing) end)
  self.key:SetScript("OnKeyDown", function(_, key)
    if not self.capturing then return end
    if key == "ESCAPE" then
      self:Capture(false)
      return
    end
    local combo = ns.Keys.Build(key, {
      alt = IsAltKeyDown(), ctrl = IsControlKeyDown(), shift = IsShiftKeyDown(),
      meta = IsMetaKeyDown and IsMetaKeyDown(),
    })
    if not combo then return end -- só o modificador: espera a tecla
    self.capturing = false
    self.key:EnableKeyboard(false)
    ns.Keybind.Set(combo)
    self:RefreshKey()
  end)
  -- Pôr um OnKeyDown liga o teclado no botão: ele pegaria as teclas com a aba
  -- aberta, sem o clique. O teclado só fica ligado durante a captura.
  self.key:EnableKeyboard(false)
  self.clearKey = Theme.Button(shortcut, L["Limpar"], "ghost", 80)
  self.clearKey:SetPoint("LEFT", self.key, "RIGHT", 8, 0)
  self.clearKey:SetScript("OnClick", function() ns.Keybind.Set(nil) end)
  self.keyNote = Theme.Text(shortcut, "small", "textMuted")
  self.keyNote:SetPoint("TOPLEFT", self.key, "BOTTOMLEFT", 0, -8)
  self.keyNote:SetPoint("RIGHT", -PAD, 0)
  -- Sair da tela cancela a captura.
  frame:SetScript("OnHide", function() if self.capturing then self:Capture(false) end end)

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

  -- Mapa-múndi
  local map = Card(frame, L["Mapa"], L["Membros online com o addon aparecem no mapa-múndi como um quadrado na cor "
    .. "da classe. Em instâncias o jogo não dá a posição."])
  map:SetPoint("TOPLEFT", guild, "BOTTOMLEFT", 0, -GAP)
  map:SetSize(colW, 96 + 2 * ROW)
  self.mapShare = Theme.Toggle(map, L["Compartilhar minha posição com a guilda"], toggleW, function(value)
    ns.GuildMap.SetSharing(value)
  end)
  self.mapShare:SetPoint("TOPLEFT", map.text, "BOTTOMLEFT", 0, -12)
  self.mapShow = Theme.Toggle(map, L["Mostrar os membros no mapa"], toggleW, function(value)
    ns.GuildMap.SetShown(value)
  end)
  self.mapShow:SetPoint("TOPLEFT", self.mapShare, "BOTTOMLEFT", 0, -(ROW - 26))

  return self
end

ns.SettingsPanel = SettingsPanel
