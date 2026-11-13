-- Profissões dos membros: lê as do próprio personagem, anuncia para a guilda,
-- repassa os níveis conhecidos e monta a lista exibida. Regras em
-- logic/Professions.lua.
local _, ns = ...

local Professions = ns.Professions
local GuildProfessions = {}

local response = {}   -- [com IDs] = resposta agendada a um pedido de níveis
local announcing = false

local function Store()
  return ns.db.professions
end

local function Changed()
  ns.Fire("PROFESSIONS_UPDATED")
end

function GuildProfessions.Init()
  ns.db.professions = ns.db.professions or {}
end

-- Anuncia as próprias profissões se mudaram desde o último anúncio.
function GuildProfessions.Announce()
  if not ns.Guild.IsMember() then return end
  local list = ns.Flavor.OwnProfessions()
  if not list then return end
  local me = ns.Guild.PlayerName()
  local current = Store()[me]
  if current and Professions.SameList(current.p, list) then return end
  local at = GetServerTime()
  if current and current.t >= at then at = current.t + 1 end
  if not Professions.Set(Store(), me, list, at) then return end
  -- Com IDs para as versões novas; sem IDs (F) para as antigas.
  ns.Comm.SendProfessions(ns.Protocol.ProfessionIds(at, Professions.EncodeOwn(list, true)), "professionIds")
  ns.Comm.SendProfessions(ns.Protocol.Professions(at, Professions.EncodeOwn(list)))
  Changed()
end

-- Mudança de nível: espera um pouco para juntar vários pontos num anúncio.
function GuildProfessions.OnSkillChanged()
  if announcing then return end
  announcing = true
  C_Timer.After(ns.Config.PROFESSIONS_ANNOUNCE_DELAY, function()
    announcing = false
    GuildProfessions.Announce()
  end)
end

-- Profissões anunciadas pelo próprio remetente.
function GuildProfessions.OnOwn(message, sender)
  local list = Professions.DecodeOwn(message.payload, message.withIds)
  if list and Professions.Set(Store(), sender, list, message.at) then Changed() end
end

-- Alguém pediu os níveis: responde depois de uma espera aleatória, se ninguém
-- responder antes.
-- `withIds`: o pedido veio de uma versão nova (Y), que recebe a lista com IDs
-- (X); as antigas (G) recebem a lista só com nomes (K).
function GuildProfessions.OnRequest(withIds)
  local key = withIds and true or false
  if response[key] or not next(Store()) then return end
  response[key] = true
  local delay = ns.Protocol.RandomDelay(ns.Config.RESPONSE_DELAY_MIN, ns.Config.RESPONSE_DELAY_MAX)
  C_Timer.After(delay, function()
    if response[key] then
      if withIds then
        ns.Comm.SendProfessionsList(ns.Protocol.ProfessionIdsList(Professions.EncodeStore(Store(), true)),
          "professionIdsList")
      else
        ns.Comm.SendProfessionsList(ns.Protocol.ProfessionsList(Professions.EncodeStore(Store())))
      end
    end
    response[key] = nil
  end)
end

-- Níveis repassados por outro membro (a resposta vale para o pedido do mesmo formato).
function GuildProfessions.OnList(message)
  response[message.withIds and true or false] = nil
  local other = Professions.DecodeStore(message.payload, message.withIds)
  if other and Professions.Merge(Store(), other) > 0 then Changed() end
end

-- Linhas da lista (logic/Professions.lua BuildRows), ou nil se a lista da
-- guilda ainda não carregou. Apaga os níveis de quem saiu da guilda.
function GuildProfessions.Rows()
  local members = ns.Flavor.GuildMembers()
  if not members then return nil end
  local names = {}
  for _, member in ipairs(members) do names[member.name] = true end
  Professions.Prune(Store(), names)
  return Professions.BuildRows(members, Store())
end

ns.GuildProfessions = GuildProfessions
