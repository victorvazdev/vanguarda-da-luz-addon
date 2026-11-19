-- Guilda: roster e cargos aceitos.
local _, ns = ...

local Guild = {}
local waiting = {} -- callbacks esperando GUILD_ROSTER_UPDATE

-- Em luta com chefe (e outras restrições) o jogo pode entregar os dados da
-- guilda como secretos, que não dá para ler nem comparar: vale a última
-- leitura legível.
local last = { member = false, motd = "", info = "", total = 0, online = 0 }

local function Secret(...) return ns.Flavor.AnySecret(...) end

-- O jogador está na guilda do addon (ns.Config.GUILD_NAME)?
function Guild.IsMember()
  local inGuild = IsInGuild()
  if Secret(inGuild) then return last.member end
  if not inGuild then
    last.member = false
    return false
  end
  local name = GetGuildInfo("player")
  if Secret(name) then return last.member end
  last.member = ns.Trust.IsOurGuild(name, ns.Config)
  return last.member
end

function Guild.RequestRoster()
  if not IsInGuild() then return end
  if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
end

-- Mensagem do dia e informações da guilda ("" se não houver).
function Guild.Motd()
  local text = GetGuildRosterMOTD and GetGuildRosterMOTD() or ""
  if Secret(text) then return last.motd end
  last.motd = text
  return text
end

function Guild.InfoText()
  local text = GetGuildInfoText and GetGuildInfoText() or ""
  if Secret(text) then return last.info end
  last.info = text
  return text
end

-- Total de membros e quantos estão online.
function Guild.Counts()
  local total, online = GetNumGuildMembers()
  if Secret(total, online) then return last.total, last.online end
  last.total, last.online = total or 0, online or 0
  return last.total, last.online
end

-- Lista de { name, rankName, rankIndex } do roster atual.
function Guild.Roster()
  local roster = {}
  for _, entry in ipairs(ns.Flavor.GuildRoster()) do
    roster[#roster + 1] = { name = entry.name, rankName = entry.rank, rankIndex = entry.rankIndex }
  end
  return roster
end

-- Nome do jogador como aparece no roster e nas mensagens de addon, que pode
-- ser diferente de UnitName("player"). Procura pelo GUID.
function Guild.PlayerName()
  local guid = UnitGUID and UnitGUID("player")
  if guid and not Secret(guid) then
    for _, entry in ipairs(ns.Flavor.GuildRoster()) do
      if entry.guid == guid then return entry.name end
    end
  end
  -- Sem roster: no WoW Forever, o segundo valor de UnitName é o sobrenome.
  local name, surname = UnitName("player")
  if surname and surname ~= "" then return name .. " " .. surname end
  return name
end

-- Linha do roster ({ name, rank, classFile, ... }) do membro com esse GUID,
-- ou nil.
function Guild.MemberByGuid(guid)
  if not guid then return nil end
  for _, entry in ipairs(ns.Flavor.GuildRoster()) do
    if entry.guid == guid then return entry end
  end
  return nil
end

-- `sender` é o próprio jogador?
function Guild.IsPlayer(sender)
  return ns.Trust.SameName(sender, UnitName("player")) or ns.Trust.SameName(sender, Guild.PlayerName())
end

-- O próprio jogador tem cargo aceito?
function Guild.IsPlayerTrusted()
  if not Guild.IsMember() then return false end
  local _, rankName, rankIndex = GetGuildInfo("player")
  if Secret(rankName, rankIndex) then return last.trusted or false end
  last.trusted = ns.Trust.IsTrustedRank(rankIndex, rankName, ns.Config)
  return last.trusted
end

-- Confere o cargo de quem enviou. Se o remetente ainda não estiver no roster,
-- atualiza o roster uma vez antes de decidir. callback(trusted)
function Guild.CheckSender(sender, callback)
  if not Guild.IsMember() then
    callback(false)
    return
  end
  local trusted = ns.Trust.IsTrustedSender(sender, Guild.Roster(), ns.Config)
  if trusted ~= nil then
    callback(trusted)
    return
  end
  local done = false
  local function Finish()
    if done then return end
    done = true
    callback(ns.Trust.IsTrustedSender(sender, Guild.Roster(), ns.Config) == true)
  end
  table.insert(waiting, Finish)
  Guild.RequestRoster()
  C_Timer.After(10, Finish)
end

function Guild.OnRosterUpdate()
  local list = waiting
  waiting = {}
  for _, fn in ipairs(list) do fn() end
end

ns.Guild = Guild
