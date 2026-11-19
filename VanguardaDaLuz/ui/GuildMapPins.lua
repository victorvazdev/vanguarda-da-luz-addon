-- Membros da guilda no mapa-múndi: um quadrado na cor da classe (diferente dos
-- pontos redondos de grupo e raide da Blizzard) para cada membro
-- online com posição recente (game/GuildMap.lua), no mapa aberto (a zona, o
-- continente ou um bairro, com logic/MapPositions.ToMap). O mouse em cima
-- mostra nome, nível, posto, main/alt e há quanto tempo a posição chegou.
--
-- Os quadrados são quadros do addon dentro da tela do mapa
-- (WorldMapFrame:GetCanvas()); o addon não mexe nos quadros nem nos
-- marcadores da Blizzard. A tela muda de escala com o zoom: o ponto recebe a
-- escala inversa para ficar sempre do mesmo tamanho. Os pontos só pegam o
-- movimento do mouse; os cliques passam para o mapa.
local _, ns = ...

local L = ns.L

local GuildMapPins = {}

local REFRESH_INTERVAL = 0.2 -- segundos entre conferências com o mapa aberto
local REDRAW_INTERVAL = 1    -- redesenho mesmo sem mudanças (tempo no tooltip)
local FALLBACK_COLOR = { r = 0.2, g = 1, b = 0.4 }

local map, canvas, driver
local pins = {}
local drawn = {} -- assinatura do último desenho

local function ClassColor(classFile)
  local colors = RAID_CLASS_COLORS
  return colors and classFile and colors[classFile] or FALLBACK_COLOR
end

local function ShowTooltip(pin)
  local item = pin.item
  if not item then return end
  local entry = item.entry
  GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
  local color = ClassColor(entry.classFile)
  GameTooltip:SetText(item.name, color.r, color.g, color.b)
  local line = string.format(L["Nível %d"], entry.level or 0)
  if entry.rank and entry.rank ~= "" then line = line .. " · " .. entry.rank end
  GameTooltip:AddLine(line, 0.95, 0.93, 0.87)
  local detail = ns.Members.Detail(item.name, ns.GuildMembers.Get(item.name))
  if detail then GameTooltip:AddLine(detail, 0.95, 0.79, 0.30) end
  if entry.zone and entry.zone ~= "" then GameTooltip:AddLine(entry.zone, 0.85, 0.81, 0.73) end
  if item.position.taxi then GameTooltip:AddLine(L["Em voo"], 0.85, 0.81, 0.73) end
  local age = math.max(0, math.floor(GetTime() - item.position.time))
  GameTooltip:AddLine(string.format(L["Posição de %d s atrás"], age), 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

-- Quadrado na cor da classe com borda preta, filho de `parent`. Também usado
-- no minimapa (ui/GuildMinimapPins.lua).
function GuildMapPins.NewPin(parent, size)
  local pin = CreateFrame("Frame", nil, parent)
  pin:SetSize(size + 2, size + 2)
  -- Quadrado (não redondo) para não confundir com os pontos de grupo e raide.
  local border = pin:CreateTexture(nil, "BACKGROUND")
  border:SetAllPoints()
  border:SetColorTexture(0, 0, 0, 1)
  local dot = pin:CreateTexture(nil, "ARTWORK")
  dot:SetPoint("TOPLEFT", 1.5, -1.5)
  dot:SetPoint("BOTTOMRIGHT", -1.5, 1.5)
  pin.dot = dot
  -- Só o movimento do mouse: os cliques e o arrastar ficam com o mapa.
  if pin.SetMouseClickEnabled then
    pin:SetMouseClickEnabled(false)
    pin:SetMouseMotionEnabled(true)
  else
    pin:EnableMouse(true)
  end
  pin:SetScript("OnEnter", ShowTooltip)
  pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return pin
end

-- Pinta o quadrado com a cor da classe do membro e guarda o item do tooltip.
function GuildMapPins.Paint(pin, item)
  local color = ClassColor(item.entry.classFile)
  pin.dot:SetColorTexture(color.r, color.g, color.b, 1)
  pin.item = item
end

local function CreatePin(i)
  pins[i] = GuildMapPins.NewPin(canvas, ns.Config.MAP_PIN_SIZE)
  return pins[i]
end

local function HideFrom(first)
  for i = first, #pins do
    pins[i]:Hide()
    pins[i].item = nil
  end
end

-- Desenha os membros no mapa aberto.
function GuildMapPins.Draw()
  if not (canvas and map) then return end
  local mapID = map:GetMapID()
  local zoom, width, height = canvas:GetScale(), canvas:GetWidth(), canvas:GetHeight()
  if not (mapID and zoom and zoom > 0 and width and width > 0 and height and height > 0) then
    HideFrom(1)
    return
  end
  local count = 0
  local level = (canvas:GetFrameLevel() or 0) + 2000
  for _, item in ipairs(ns.GuildMap.Visible()) do
    local x, y = ns.MapPositions.ToMap(item.position, mapID, ns.Flavor.MapRect)
    if x then
      count = count + 1
      local pin = pins[count] or CreatePin(count)
      local scale = 1 / zoom
      pin:SetScale(scale)
      pin:ClearAllPoints()
      pin:SetPoint("CENTER", canvas, "TOPLEFT", x * width / scale, -y * height / scale)
      pin:SetFrameLevel(level)
      GuildMapPins.Paint(pin, item)
      pin:Show()
    end
  end
  HideFrom(count + 1)
  GuildMapPins.count = count -- para o teste de fumaça
end

-- Com o mapa aberto: redesenha quando muda o mapa, o zoom, o tamanho ou as
-- posições, e de tempos em tempos.
local function Check(_, elapsed)
  drawn.wait = (drawn.wait or 0) - (elapsed or 0)
  if drawn.wait > 0 then return end
  drawn.wait = REFRESH_INTERVAL
  -- Comparação campo a campo: montar uma chave em texto criaria lixo a cada
  -- conferência.
  local mapID, scale, width, height = map:GetMapID(), canvas:GetScale(), canvas:GetWidth(), canvas:GetHeight()
  local version, now = ns.GuildMap.version, GetTime()
  if drawn.stale or mapID ~= drawn.mapID or scale ~= drawn.scale or width ~= drawn.width or height ~= drawn.height
    or version ~= drawn.version or now - (drawn.at or 0) >= REDRAW_INTERVAL then
    drawn.stale, drawn.mapID, drawn.scale, drawn.width, drawn.height = false, mapID, scale, width, height
    drawn.version, drawn.at = version, now
    GuildMapPins.Draw()
  end
end

local function Setup()
  map = ns.Flavor.WorldMap()
  canvas = map and map.GetCanvas and map:GetCanvas()
  if not canvas then return end
  -- O quadro de conferência é filho da tela do mapa: só roda com o mapa aberto.
  driver = CreateFrame("Frame", nil, canvas)
  driver:SetSize(1, 1)
  driver:SetPoint("TOPLEFT")
  driver:SetScript("OnUpdate", Check)
  driver:SetScript("OnShow", function() drawn.stale = true end)
  GuildMapPins.driver, GuildMapPins.pins = driver, pins -- para o teste de fumaça
end

function GuildMapPins.Init()
  local spec = ns.Flavor.worldMap
  if ns.Flavor.WorldMap() or (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(spec.addon)) then
    Setup()
    return
  end
  local events = CreateFrame("Frame")
  events:SetScript("OnEvent", function(self, _, name)
    if name == spec.addon then
      self:UnregisterEvent("ADDON_LOADED")
      Setup()
    end
  end)
  events:RegisterEvent("ADDON_LOADED")
end

ns.GuildMapPins = GuildMapPins
