-- Identidade visual do site (src/styles/_tokens.scss do vanguarda-da-luz-front)
-- e componentes básicos da interface.
local _, ns = ...

local Theme = {}

local function Hex(hex, alpha)
  return {
    tonumber(string.sub(hex, 2, 3), 16) / 255,
    tonumber(string.sub(hex, 4, 5), 16) / 255,
    tonumber(string.sub(hex, 6, 7), 16) / 255,
    alpha or 1,
  }
end

Theme.colors = {
  bg = Hex("#141210"),
  bgDeep = Hex("#0d0b09"),
  surface = Hex("#1c1915"),
  surfaceRaised = Hex("#241f18"),
  border = Hex("#3d3220"),
  borderField = Hex("#836d2f"),
  gold = Hex("#f2c94c"),
  goldLight = Hex("#ffe08a"),
  goldDeep = Hex("#c9962b"),
  bronze = Hex("#8a5a1c"),
  text = Hex("#f3ecdd"),
  textMuted = Hex("#d9cfbb"),
  heading = Hex("#fff6df"),
  cancel = Hex("#f2a488"),
  onGold = Hex("#141210"),
  azure = Hex("#7fa8ff"),
  azureDeep = Hex("#1b2a4a"),
  success = Hex("#9be08f"),
  warning = Hex("#f2b04c"),
  away = Hex("#f5d742"),   -- bolinha de ausente (AFK)
  busy = Hex("#f2786b"),   -- bolinha de ocupado (Não perturbe)
}

-- Cor no formato do chat: "|cffRRGGBB".
function Theme.Code(name)
  local c = Theme.colors[name]
  return string.format("|cff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255)
end

local FONT_PATH = ns.path .. "fonts\\"
local fonts = {}

-- Fontes: Cinzel nos títulos e Source Sans 3 no texto.
local FONT_SPECS = {
  title = { "Cinzel-Bold.ttf", 20, "heading" },
  heading = { "Cinzel-SemiBold.ttf", 15, "heading" },
  body = { "SourceSans3-Regular.ttf", 14, "text" },
  bodyStrong = { "SourceSans3-SemiBold.ttf", 14, "text" },
  small = { "SourceSans3-Regular.ttf", 12, "textMuted" },
  smallStrong = { "SourceSans3-SemiBold.ttf", 12, "text" },
  button = { "SourceSans3-Bold.ttf", 13, "text" },
  day = { "SourceSans3-SemiBold.ttf", 13, "text" },
}

function Theme.Font(name)
  if not fonts[name] then
    local spec = FONT_SPECS[name]
    local font = CreateFont("VanguardaDaLuzFont_" .. name)
    font:SetFont(FONT_PATH .. spec[1], spec[2], "")
    font:SetTextColor(unpack(Theme.colors[spec[3]]))
    fonts[name] = font
  end
  return fonts[name]
end

local WHITE = "Interface\\Buttons\\WHITE8X8"

-- Fundo liso com borda de 1 pixel.
-- Borda de pelo menos 1 pixel da tela: com a escala da interface abaixo de 1,
-- uma borda de 1 unidade pode sumir em alguns lados quando o quadro não cai
-- exatamente num pixel.
local function EdgeSize(frame)
  if not (PixelUtil and PixelUtil.GetNearestPixelSize and frame.GetEffectiveScale) then return 1 end
  local scale = frame:GetEffectiveScale()
  if not scale or scale <= 0 then return 1 end
  return math.max(1, PixelUtil.GetNearestPixelSize(1, scale, 1))
end

function Theme.Backdrop(frame, bg, border)
  if not frame.SetBackdrop then Mixin(frame, BackdropTemplateMixin) end
  frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = EdgeSize(frame) })
  frame:SetBackdropColor(unpack(Theme.colors[bg or "surface"]))
  frame:SetBackdropBorderColor(unpack(Theme.colors[border or "border"]))
end

function Theme.Text(parent, font, color, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY")
  fs:SetFontObject(Theme.Font(font or "body"))
  if color then fs:SetTextColor(unpack(Theme.colors[color])) end
  fs:SetJustifyH("LEFT")
  fs:SetWordWrap(true)
  return fs
end

-- Linha dourada em degradê (bronze, dourado, bronze), como no site.
function Theme.Divider(parent)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetHeight(1)
  line:SetColorTexture(1, 1, 1, 1)
  local bronze, gold = Theme.colors.bronze, Theme.colors.gold
  if line.SetGradient and CreateColor then
    line:SetGradient("HORIZONTAL", CreateColor(bronze[1], bronze[2], bronze[3], 1),
      CreateColor(gold[1], gold[2], gold[3], 1))
  else
    line:SetColorTexture(unpack(gold))
  end
  return line
end

-- Botão. kind: "primary" (dourado), "outline" (contorno) ou "ghost" (só texto).
function Theme.Button(parent, label, kind, width)
  kind = kind or "outline"
  local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
  button:SetSize(width or 120, 28)
  button.kind = kind
  local text = Theme.Text(button, "button")
  text:SetPoint("CENTER")
  text:SetJustifyH("CENTER")
  text:SetWordWrap(false)
  button.label = text
  button:SetFontString(text)

  local function Paint(self, hover)
    local enabled = self:IsEnabled()
    if self.kind == "primary" then
      Theme.Backdrop(self, hover and "goldLight" or "gold", "goldDeep")
      text:SetTextColor(unpack(Theme.colors.onGold))
    elseif self.kind == "ghost" then
      Theme.Backdrop(self, hover and "surfaceRaised" or "surface", hover and "border" or "surface")
      text:SetTextColor(unpack(Theme.colors[hover and "goldLight" or "gold"]))
    else
      Theme.Backdrop(self, hover and "surfaceRaised" or "surface", hover and "gold" or "borderField")
      text:SetTextColor(unpack(Theme.colors[hover and "goldLight" or "text"]))
    end
    self:SetAlpha(enabled and 1 or 0.45)
  end

  button:SetScript("OnEnter", function(self) if self:IsEnabled() then Paint(self, true) end end)
  button:SetScript("OnLeave", function(self) Paint(self, false) end)
  button:SetScript("OnEnable", function(self) Paint(self, false) end)
  button:SetScript("OnDisable", function(self) Paint(self, false) end)
  -- Troca o estilo depois de criado (abas: a ativa fica "primary").
  function button.SetKind(self, newKind)
    self.kind = newKind
    Paint(self, false)
  end
  button:SetText(label)
  Paint(button, false)
  return button
end

-- Caixa de marcar com rótulo. `onChange(valor)` é chamado no clique;
-- toggle:SetValue(v) muda a marcação sem chamar onChange.
function Theme.Toggle(parent, label, width, onChange)
  local toggle = CreateFrame("Button", nil, parent)
  toggle:SetSize(width or 300, 26)
  local box = CreateFrame("Frame", nil, toggle, "BackdropTemplate")
  box:SetSize(20, 20)
  box:SetPoint("LEFT")
  Theme.Backdrop(box, "bgDeep", "borderField")
  local check = box:CreateTexture(nil, "OVERLAY")
  check:SetSize(24, 24)
  check:SetPoint("CENTER")
  check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  check:Hide()
  local text = Theme.Text(toggle, "body")
  text:SetPoint("LEFT", box, "RIGHT", 10, 0)
  text:SetPoint("RIGHT")
  text:SetWordWrap(false)
  toggle:SetFontString(text)
  toggle:SetText(label)
  toggle.label = text

  function toggle.SetValue(self, value)
    self.value = value and true or false
    check:SetShown(self.value)
  end
  function toggle.GetValue(self) return self.value end
  toggle:SetScript("OnClick", function(self)
    self:SetValue(not self.value)
    if onChange then onChange(self.value) end
  end)
  toggle:SetScript("OnEnter", function() Theme.Backdrop(box, "bgDeep", "gold") end)
  toggle:SetScript("OnLeave", function() Theme.Backdrop(box, "bgDeep", "borderField") end)
  toggle:SetValue(false)
  return toggle
end

-- Menu de contexto junto do cursor: um título e uma lista de ações. Fecha ao
-- escolher uma ação, ao clicar fora dele ou com Esc.
-- menu:Open(title, { { label, action, disabled }, ... })
function Theme.PopupMenu(name, width)
  width = width or 200
  local menu = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  menu:SetWidth(width)
  menu:SetFrameStrata("FULLSCREEN_DIALOG")
  menu:SetClampedToScreen(true)
  menu:EnableMouse(true)
  Theme.Backdrop(menu, "surfaceRaised", "goldDeep")
  menu:Hide()
  local title = Theme.Text(menu, "smallStrong", "goldDeep")
  title:SetPoint("TOPLEFT", 12, -10)
  title:SetPoint("RIGHT", -12, 0)
  title:SetWordWrap(false)
  menu.title = title
  menu.buttons = {}
  if name then table.insert(UISpecialFrames, name) end
  menu:SetScript("OnEvent", function(self)
    if not self:IsMouseOver() then self:Hide() end
  end)
  menu:SetScript("OnHide", function(self) self:UnregisterEvent("GLOBAL_MOUSE_DOWN") end)

  function menu.Open(self, text, items)
    title:SetText(text or "")
    for i, item in ipairs(items) do
      local b = self.buttons[i]
      if not b then
        b = Theme.Button(self, "", "ghost", width - 12)
        b:SetHeight(24)
        b:SetPoint("TOPLEFT", 6, -30 - (i - 1) * 26)
        b.label:ClearAllPoints()
        b.label:SetPoint("LEFT", 10, 0)
        b:SetScript("OnClick", function(button)
          self:Hide()
          if button.action then button.action() end
        end)
        self.buttons[i] = b
      end
      b.action = item.action
      b:SetText(item.label)
      b:SetEnabled(not item.disabled)
      b:Show()
    end
    for i = #items + 1, #self.buttons do self.buttons[i]:Hide() end
    self:SetHeight(36 + #items * 26 - 2)
    local scale = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    self:Show()
    -- Clique fora fecha (o evento só é observado com o menu aberto).
    pcall(self.RegisterEvent, self, "GLOBAL_MOUSE_DOWN")
  end
  return menu
end

-- Cor da bolinha de presença: online, ausente, ocupado ou offline.
-- `status` = "away", "busy" ou nil.
function Theme.PresenceColor(online, status)
  if not online then return Theme.colors.border end
  if status == "away" then return Theme.colors.away end
  if status == "busy" then return Theme.colors.busy end
  return Theme.colors.success
end

-- Janela com a moldura do addon: fundo escuro, borda dourada, arrastável e
-- fechada com Esc.
function Theme.Window(name, width, height, title)
  local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  frame:SetSize(width, height)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("HIGH")
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  Theme.Backdrop(frame, "bg", "goldDeep")
  frame:Hide()
  table.insert(UISpecialFrames, name)

  local logo = frame:CreateTexture(nil, "ARTWORK")
  logo:SetSize(40, 40)
  logo:SetPoint("TOPLEFT", 14, -10)
  logo:SetTexture(ns.path .. "assets\\logo-64")
  frame.logo = logo

  local heading = Theme.Text(frame, "title", "gold")
  heading:SetPoint("LEFT", logo, "RIGHT", 10, 0)
  heading:SetText(title)
  frame.heading = heading

  local close = Theme.Button(frame, "×", "ghost", 28)
  close:SetPoint("TOPRIGHT", -10, -12)
  close:SetScript("OnClick", function() frame:Hide() end)
  frame.close = close

  local divider = Theme.Divider(frame)
  divider:SetPoint("TOPLEFT", 12, -58)
  divider:SetPoint("TOPRIGHT", -12, -58)

  return frame
end

-- Área de texto com rolagem (somente leitura).
function Theme.ScrollText(parent, font)
  local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  local child = CreateFrame("Frame", nil, scroll)
  child:SetSize(1, 1)
  scroll:SetScrollChild(child)
  local text = Theme.Text(child, font or "body")
  text:SetPoint("TOPLEFT")
  scroll:SetScript("OnSizeChanged", function(_, w)
    child:SetWidth(w)
    text:SetWidth(w)
  end)
  function scroll:SetText(value)
    text:SetText(value)
    child:SetHeight(text:GetStringHeight() + 4)
    self:SetVerticalScroll(0)
  end
  return scroll
end

ns.Theme = Theme
