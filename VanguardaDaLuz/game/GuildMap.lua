-- Membros no mapa-múndi e no minimapa: a cada poucos segundos envia a posição
-- do próprio personagem para a guilda (se andou, ou de tempos em tempos
-- parado) e guarda na memória a dos outros. Regras em logic/MapPositions.lua;
-- o desenho em ui/GuildMapPins.lua e ui/GuildMinimapPins.lua.
--
-- Em instâncias o jogo não dá a posição, e durante a restrição de mensagens
-- (lutas com chefe, M+, JxJ) nada é enviado: quem não envia some do mapa
-- depois de Config.MAP_EXPIRE segundos.
local _, ns = ...

local MapPositions = ns.MapPositions
local GuildMap = {}

local positions = {} -- [nome] = { map, x, y, taxi, time }
local lastSent = nil -- { map, x, y, taxi, time } do último envio
GuildMap.version = 0 -- muda a cada posição recebida (o desenho refaz)

local function Settings()
  return ns.db.settings.map
end

function GuildMap.Init()
  ns.db.settings.map = ns.db.settings.map or {}
end

-- Compartilhar a própria posição e mostrar os membros: começam ligados.
function GuildMap.IsSharing()
  return Settings().share ~= false
end

function GuildMap.IsShown()
  return Settings().show ~= false
end

-- Mostrar no minimapa: começa ligado.
function GuildMap.IsOnMinimap()
  return Settings().minimap ~= false
end

function GuildMap.SetOnMinimap(on)
  if on then Settings().minimap = nil else Settings().minimap = false end
  GuildMap.version = GuildMap.version + 1
  ns.Fire("SETTINGS_UPDATED")
end

function GuildMap.SetSharing(on)
  if on then Settings().share = nil else Settings().share = false end
  lastSent = nil
  ns.Fire("SETTINGS_UPDATED")
end

function GuildMap.SetShown(on)
  if on then Settings().show = nil else Settings().show = false end
  GuildMap.version = GuildMap.version + 1
  ns.Fire("SETTINGS_UPDATED")
end

-- Envia a própria posição, se mudou ou se faz tempo.
function GuildMap.Broadcast()
  if not (ns.Guild.IsMember() and GuildMap.IsSharing()) then return end
  local current = ns.Flavor.PlayerMapPosition()
  local now = GetTime()
  if not MapPositions.ShouldSend(lastSent, current, now, ns.Config) then return end
  local payload = MapPositions.Encode(current.map, current.x, current.y, current.taxi)
  if payload and ns.Comm.SendPosition(ns.Protocol.Position(payload)) then
    lastSent = { map = current.map, x = current.x, y = current.y, taxi = current.taxi, time = now }
  end
end

function GuildMap.Start()
  C_Timer.NewTicker(ns.Config.MAP_SEND_INTERVAL, GuildMap.Broadcast)
end

-- Posição enviada por outro membro.
function GuildMap.OnPosition(message, sender)
  local position = MapPositions.Decode(message.payload)
  if not position then return end
  MapPositions.Set(positions, sender, position, GetTime())
  GuildMap.version = GuildMap.version + 1
end

-- Grupo mudou: quem entrou ou saiu do grupo aparece ou some do minimapa.
function GuildMap.OnGroupChanged()
  GuildMap.version = GuildMap.version + 1
end

local EMPTY = {} -- lista vazia compartilhada (não alterar)
local cache = { map = {}, minimap = {} } -- última lista de cada um
local function ByName(a, b) return a.name < b.name end

-- Membros para desenhar: online no roster, com posição recente, sem o próprio
-- jogador. Cada item: { name, position, entry } (entry = linha do roster).
-- `minimap` = true para o minimapa: segue a opção dele e deixa de fora quem
-- está no grupo, que a Blizzard já mostra.
--
-- O minimapa chama isto 10 vezes por segundo: a lista é guardada e só é
-- refeita quando chega uma posição, muda o roster, o grupo ou uma opção, ou a
-- cada Config.MAP_VISIBLE_REFRESH segundos (posições vencidas). Não alterar a
-- lista devolvida.
function GuildMap.Visible(minimap)
  local shown
  if minimap then shown = GuildMap.IsOnMinimap() else shown = GuildMap.IsShown() end
  if not (shown and next(positions) and ns.Guild.IsMember()) then return EMPTY end
  local now = GetTime()
  local index = ns.Flavor.GuildRosterIndex()
  local last = minimap and cache.minimap or cache.map
  if last.list and last.version == GuildMap.version and last.index == index
    and now - last.at < ns.Config.MAP_VISIBLE_REFRESH then
    return last.list
  end
  if MapPositions.Prune(positions, now, ns.Config.MAP_EXPIRE) > 0 then
    GuildMap.version = GuildMap.version + 1
  end
  local list = {}
  local byName = index.byName
  for name, position in pairs(positions) do
    local entry = byName[name]
    if entry and entry.online and not ns.Guild.IsPlayer(name)
      and not (minimap and ns.Flavor.InGroupWith(name)) then
      list[#list + 1] = { name = name, position = position, entry = entry }
    end
  end
  table.sort(list, ByName)
  last.list, last.version, last.index, last.at = list, GuildMap.version, index, now
  return list
end

GuildMap.positions = positions -- para o teste de fumaça

ns.GuildMap = GuildMap
