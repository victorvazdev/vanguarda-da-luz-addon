-- Tempo de jogo com a guilda: a cada minuto, verifica se o jogador está em
-- grupo com outro membro da guilda, na mesma zona e sem ausentes, soma o
-- minuto, anuncia o total de tempos em tempos e repassa os conhecidos.
-- Regras em logic/Together.lua.
local _, ns = ...

local Together = ns.Together
local GuildTogether = {}

local response = nil  -- resposta agendada a um pedido
local lastSent = nil  -- último total anunciado
local lastAnnounce = 0

local function Store()
  return ns.db.together
end

local function Changed()
  ns.Fire("TOGETHER_UPDATED")
end

function GuildTogether.Init()
  ns.db.together = ns.db.together or {}
end

-- Segundos de um personagem e total da pessoa (main com os alts).
function GuildTogether.PersonTotal(name)
  local totals = Together.Totals(Store(), ns.db.members)
  local person = Together.PersonOf(name, ns.db.members)
  return totals[person], person
end

function GuildTogether.Totals()
  return Together.Totals(Store(), ns.db.members)
end

-- Anuncia o próprio total se mudou desde o último anúncio.
function GuildTogether.Announce()
  if not ns.Guild.IsMember() then return end
  local me = ns.Guild.PlayerName()
  local seconds = me and Store()[me]
  if not seconds or seconds == lastSent then return end
  lastSent = seconds
  lastAnnounce = GetTime()
  ns.Comm.SendTogether(ns.Protocol.Together(Together.EncodeOwn(seconds)))
end

-- Um minuto: conta se estiver junto de alguém da guilda. A leitura do grupo
-- fica num pcall: em encontros, o jogo pode esconder dados das unidades.
function GuildTogether.Tick()
  if not ns.Guild.IsMember() then return end
  local me = ns.Guild.PlayerName()
  if not me then return end
  ns.Guild.RequestRoster() -- atualiza a zona dos membros
  local ok, counts = pcall(function()
    local player, group = ns.Flavor.GroupState()
    return Together.Counts(player, group)
  end)
  if not (ok and counts) then return end
  Together.Add(Store(), me, ns.Config.TOGETHER_TICK)
  Changed()
  if GetTime() - lastAnnounce >= ns.Config.TOGETHER_ANNOUNCE_INTERVAL then GuildTogether.Announce() end
end

function GuildTogether.Start()
  C_Timer.NewTicker(ns.Config.TOGETHER_TICK, GuildTogether.Tick)
end

-- Total anunciado pelo próprio remetente.
function GuildTogether.OnOwn(message, sender)
  local seconds = Together.DecodeOwn(message.payload)
  if seconds and Together.Set(Store(), sender, seconds) then Changed() end
end

-- Alguém pediu os totais: responde depois de uma espera aleatória, se ninguém
-- responder antes.
function GuildTogether.OnRequest()
  if response or not next(Store()) then return end
  response = true
  local delay = ns.Protocol.RandomDelay(ns.Config.RESPONSE_DELAY_MIN, ns.Config.RESPONSE_DELAY_MAX)
  C_Timer.After(delay, function()
    if response then
      ns.Comm.SendTogetherList(ns.Protocol.TogetherList(Together.EncodeStore(Store())))
    end
    response = nil
  end)
end

-- Totais repassados por outro membro.
function GuildTogether.OnList(message)
  response = nil
  local other = Together.DecodeStore(message.payload)
  if other and Together.Merge(Store(), other) > 0 then Changed() end
end

ns.GuildTogether = GuildTogether
