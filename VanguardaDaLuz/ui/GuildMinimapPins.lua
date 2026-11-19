-- Membros da guilda no minimapa: o mesmo quadrado na cor da classe do
-- mapa-múndi (ui/GuildMapPins.lua), menor, para cada membro online com
-- posição recente que esteja dentro do alcance do minimapa. Quem está no
-- grupo fica de fora: a Blizzard já mostra o ponto dele.
--
-- O minimapa acompanha o jogador, então os pontos são conferidos várias
-- vezes por segundo a partir da posição no mundo em jardas (a própria e a de
-- cada membro), do raio visível (muda com o zoom e em lugares fechados) e da
-- direção do personagem quando a opção "Girar minimapa" está ligada. Conta em
-- logic/MapPositions.MinimapPoint. As posições dos outros chegam a cada 5 s
-- andando, então os pontos andam aos saltos.
--
-- Memória: a conferência roda 10 vezes por segundo e não pode criar tabelas.
-- A própria posição vem de UnitPosition (só números; os vetores do mapa levam
-- ~1 KB cada), a lista de membros é a guardada em GuildMap.Visible e só se
-- redesenha quando algo mudou.
--
-- Os quadrados são quadros do addon dentro do minimapa; o addon não mexe nos
-- quadros nem nos marcadores da Blizzard. Só pegam o movimento do mouse.
local _, ns = ...

local GuildMinimapPins = {}

local REFRESH_INTERVAL = 0.1 -- segundos entre recálculos

local minimap, driver
local pins = {}
local wait = 0

local function HideFrom(first)
  for i = first, #pins do
    if pins[i].item then
      pins[i]:Hide()
      pins[i].item = nil
    end
  end
end

-- Posição no mundo de uma posição recebida, calculada uma vez por mensagem.
local function World(position)
  if position.world == nil then
    position.world = ns.Flavor.WorldPosition(position.map, position.x, position.y) or false
  end
  return position.world or nil
end

-- Último desenho: só redesenha quando algo mudou (posição, direção, zoom,
-- formato, tamanho ou a lista de membros). Parado, nada é recalculado.
local drawn = {}
local me = {} -- a própria posição no mundo, reaproveitada

local function Changed(list, north, west, instance, facing, radius, square, width, height)
  if drawn.list == list and drawn.north == north and drawn.west == west and drawn.instance == instance
    and drawn.facing == facing and drawn.radius == radius and drawn.square == square and drawn.width == width
    and drawn.height == height then
    return false
  end
  drawn.list, drawn.north, drawn.west, drawn.instance, drawn.facing = list, north, west, instance, facing
  drawn.radius, drawn.square, drawn.width, drawn.height = radius, square, width, height
  return true
end

-- Recalcula e desenha os pontos. `force` redesenha mesmo sem mudanças.
function GuildMinimapPins.Draw(force)
  if not minimap then return end
  local list = ns.GuildMap.Visible(true)
  local facing = #list > 0 and ns.Flavor.MinimapFacing()
  local north, west, instance
  if facing ~= false then north, west, instance = ns.Flavor.PlayerWorldPosition() end
  if not north then
    drawn.list = nil
    HideFrom(1)
    GuildMinimapPins.count = 0
    return
  end
  local radius = ns.Flavor.MinimapRadius()
  local square = ns.Flavor.MinimapSquare()
  local width, height = minimap:GetWidth(), minimap:GetHeight()
  if not (Changed(list, north, west, instance, facing, radius, square, width, height) or force) then return end
  me.north, me.west, me.instance = north, west, instance
  local count = 0
  local halfW, halfH = width / 2, height / 2
  local level = (minimap:GetFrameLevel() or 0) + 5
  for _, item in ipairs(list) do
    local x, y = ns.MapPositions.MinimapPoint(me, World(item.position), radius, facing, square)
    if x then
      count = count + 1
      local pin = pins[count]
      if not pin then
        pin = ns.GuildMapPins.NewPin(minimap, ns.Config.MINIMAP_PIN_SIZE)
        pins[count] = pin
      end
      pin:ClearAllPoints()
      pin:SetPoint("CENTER", minimap, "CENTER", x * halfW, y * halfH)
      pin:SetFrameLevel(level)
      ns.GuildMapPins.Paint(pin, item)
      pin:Show()
    end
  end
  HideFrom(count + 1)
  GuildMinimapPins.count = count -- para o teste de fumaça
end

local function Update(_, elapsed)
  wait = wait - (elapsed or 0)
  if wait > 0 then return end
  wait = REFRESH_INTERVAL
  GuildMinimapPins.Draw()
end

function GuildMinimapPins.Init()
  minimap = ns.Flavor.Minimap()
  if not minimap then return end
  -- O quadro de conferência é filho do minimapa: só roda com ele à vista.
  driver = CreateFrame("Frame", nil, minimap)
  driver:SetSize(1, 1)
  driver:SetPoint("CENTER")
  driver:SetScript("OnUpdate", Update)
  GuildMinimapPins.driver, GuildMinimapPins.pins = driver, pins -- para o teste de fumaça
end

ns.GuildMinimapPins = GuildMinimapPins
