-- Abates honrosos: lê os do próprio personagem (GetPVPLifetimeStats), anuncia
-- à guilda quando mudam e repassa os conhecidos. Regras em logic/Kills.lua.
--
-- O jogo avisa a cada abate (PLAYER_PVP_KILLS_CHANGED); o anúncio espera
-- Config.KILLS_ANNOUNCE_DELAY segundos para juntar vários abates seguidos. De
-- reserva, confere a cada Config.KILLS_CHECK segundos. Só anuncia quando o
-- número mudou.
local _, ns = ...

local Kills = ns.Kills
local GuildKills = {}

local response = nil -- resposta agendada a um pedido
local lastSent = nil -- último total anunciado
local announcePending = false

local function Store()
  return ns.db.kills
end

local function Changed()
  ns.Fire("KILLS_UPDATED")
end

function GuildKills.Init()
  ns.db.kills = ns.db.kills or {}
end

-- Apaga quem saiu da guilda. `members` = { [nome] = linha }.
function GuildKills.Prune(members)
  Kills.Prune(Store(), members)
end

-- Total por pessoa (main com os alts): { [pessoa] = abates }.
function GuildKills.Totals()
  return Kills.Totals(Store(), ns.db.members)
end

-- Lê os próprios abates e guarda. Retorna o total, ou nil.
function GuildKills.ReadOwn()
  local me = ns.Guild.PlayerName()
  local kills = ns.Flavor.HonorableKills()
  if not (me and kills) then return nil end
  if Kills.Set(Store(), me, kills) then Changed() end
  return Store()[me]
end

-- Anuncia os próprios abates se mudaram desde o último anúncio.
function GuildKills.Announce()
  if not ns.Guild.IsMember() then return end
  local kills = GuildKills.ReadOwn()
  if not kills or kills == lastSent then return end
  lastSent = kills
  ns.Comm.SendKills(ns.Protocol.Kills(Kills.EncodeOwn(kills)))
end

-- Abate no jogo: lê na hora (o ranking atualiza) e anuncia depois da espera.
function GuildKills.OnKillsChanged()
  if not ns.Guild.IsMember() then return end
  GuildKills.ReadOwn()
  if announcePending then return end
  announcePending = true
  C_Timer.After(ns.Config.KILLS_ANNOUNCE_DELAY, function()
    announcePending = false
    GuildKills.Announce()
  end)
end

function GuildKills.Start()
  C_Timer.NewTicker(ns.Config.KILLS_CHECK, GuildKills.Announce)
end

-- Total anunciado pelo próprio remetente.
function GuildKills.OnOwn(message, sender)
  local kills = Kills.DecodeOwn(message.payload)
  if kills and Kills.Set(Store(), sender, kills) then Changed() end
end

-- Alguém pediu os totais: responde depois de uma espera aleatória, se ninguém
-- responder antes.
function GuildKills.OnRequest()
  if response or not next(Store()) then return end
  response = true
  local delay = ns.Protocol.RandomDelay(ns.Config.RESPONSE_DELAY_MIN, ns.Config.RESPONSE_DELAY_MAX)
  C_Timer.After(delay, function()
    if response then
      ns.Comm.SendKillsList(ns.Protocol.KillsList(Kills.EncodeStore(Store())))
    end
    response = nil
  end)
end

-- Totais repassados por outro membro.
function GuildKills.OnList(message)
  response = nil
  local other = Kills.DecodeStore(message.payload)
  if other and Kills.Merge(Store(), other) > 0 then Changed() end
end

ns.GuildKills = GuildKills
