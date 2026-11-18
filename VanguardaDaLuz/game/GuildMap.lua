-- Membros no mapa-múndi: a cada poucos segundos envia a posição do próprio
-- personagem para a guilda (se andou, ou de tempos em tempos parado) e guarda
-- na memória a dos outros. Regras em logic/MapPositions.lua; o desenho no
-- mapa em ui/GuildMapPins.lua.
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

-- Membros para desenhar: online no roster, com posição recente, sem o próprio
-- jogador. Cada item: { name, position, entry } (entry = linha do roster).
function GuildMap.Visible()
  if MapPositions.Prune(positions, GetTime(), ns.Config.MAP_EXPIRE) > 0 then
    GuildMap.version = GuildMap.version + 1
  end
  local list = {}
  if not (ns.Guild.IsMember() and GuildMap.IsShown()) then return list end
  local byName = {}
  for _, entry in ipairs(ns.Flavor.GuildRoster()) do byName[entry.name] = entry end
  for name, position in pairs(positions) do
    local entry = byName[name]
    if entry and entry.online and not ns.Guild.IsPlayer(name) then
      list[#list + 1] = { name = name, position = position, entry = entry }
    end
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  return list
end

GuildMap.positions = positions -- para o teste de fumaça

ns.GuildMap = GuildMap
