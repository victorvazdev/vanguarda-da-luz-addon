-- Posições dos membros no mapa-múndi. Lógica pura.
--
-- Cada addon envia a posição do próprio personagem para a guilda (mensagem
-- W, logic/Protocol.lua) e guarda na memória a dos outros: elas mudam o tempo
-- todo e não vão para as SavedVariables.
--
-- Carga da mensagem: "<mapa>|<x>|<y>|<em voo>", com x e y de 0 a 10000
-- (posição no mapa de 0 a 1, com 4 casas) e em voo = 1 ou 0.
local _, ns = ...

local MapPositions = {}

local SCALE = 10000

local function Round(v)
  return math.floor(v * SCALE + 0.5)
end

-- Carga da posição própria. `taxi` = true em voo. Retorna nil se a posição
-- não for válida.
function MapPositions.Encode(mapID, x, y, taxi)
  if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then return nil end
  if mapID < 1 or mapID ~= math.floor(mapID) then return nil end
  if x < 0 or x > 1 or y < 0 or y > 1 or (x == 0 and y == 0) then return nil end
  return mapID .. "|" .. Round(x) .. "|" .. Round(y) .. "|" .. (taxi and 1 or 0)
end

-- { map, x, y, taxi } de uma carga recebida, ou nil se for inválida.
function MapPositions.Decode(payload)
  if type(payload) ~= "string" then return nil end
  local map, x, y, taxi = string.match(payload, "^(%d+)|(%d+)|(%d+)|([01])$")
  if not map then return nil end
  map, x, y = tonumber(map), tonumber(x), tonumber(y)
  if map < 1 or x > SCALE or y > SCALE then return nil end
  return { map = map, x = x / SCALE, y = y / SCALE, taxi = taxi == "1" }
end

-- Vale enviar a posição agora? Envia ao mudar de mapa, de estado de voo ou
-- ao andar mais que `config.MAP_MOVE_EPSILON`; parado, a cada
-- `config.MAP_HEARTBEAT` segundos. `last` = { map, x, y, taxi, time } do
-- último envio (ou nil); `now` em segundos.
function MapPositions.ShouldSend(last, current, now, config)
  if not current then return false end
  if not last or not last.time then return true end
  if last.map ~= current.map or last.taxi ~= current.taxi then return true end
  local eps = config.MAP_MOVE_EPSILON
  if math.abs(last.x - current.x) > eps or math.abs(last.y - current.y) > eps then return true end
  return now - last.time >= config.MAP_HEARTBEAT
end

-- Guarda a posição recebida de `name` no momento `now`.
function MapPositions.Set(store, name, position, now)
  store[name] = { map = position.map, x = position.x, y = position.y, taxi = position.taxi, time = now }
end

-- Tira as posições mais velhas que `maxAge` segundos. Retorna quantas saíram.
function MapPositions.Prune(store, now, maxAge)
  local removed = 0
  for name, position in pairs(store) do
    if now - position.time > maxAge then
      store[name] = nil
      removed = removed + 1
    end
  end
  return removed
end

-- Leva a posição para o mapa `target` (o aberto no mapa-múndi). `rectOf(a, b)`
-- é como C_Map.GetMapRectOnMap: o retângulo (minX, maxX, minY, maxY) do mapa
-- `a` dentro do mapa `b`, ou nil. Funciona de um mapa para o mapa que o
-- contém (zona → continente) e ao contrário (zona → bairro dela). Retorna
-- x, y de 0 a 1, ou nil se a posição fica fora do mapa aberto.
function MapPositions.ToMap(position, target, rectOf)
  local x, y
  if position.map == target then
    x, y = position.x, position.y
  else
    local minX, maxX, minY, maxY = rectOf(position.map, target)
    if minX and maxX and minY and maxY and maxX > minX and maxY > minY then
      x, y = minX + position.x * (maxX - minX), minY + position.y * (maxY - minY)
    else
      minX, maxX, minY, maxY = rectOf(target, position.map)
      if not (minX and maxX and minY and maxY and maxX > minX and maxY > minY) then return nil end
      x, y = (position.x - minX) / (maxX - minX), (position.y - minY) / (maxY - minY)
    end
  end
  if x < 0 or x > 1 or y < 0 or y > 1 then return nil end
  return x, y
end

ns.MapPositions = MapPositions
return MapPositions
