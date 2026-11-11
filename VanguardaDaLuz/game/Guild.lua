-- Guilda: roster, cargos aceitos e permissões do calendário.
local _, ns = ...

local Guild = {}
local waiting = {} -- callbacks esperando GUILD_ROSTER_UPDATE

function Guild.RequestRoster()
  if not IsInGuild() then return end
  if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
end

-- Lista de { name, rankName, rankIndex } do roster atual.
function Guild.Roster()
  local roster = {}
  for i = 1, GetNumGuildMembers() do
    local name, rankName, rankIndex = GetGuildRosterInfo(i)
    if name then roster[#roster + 1] = { name = name, rankName = rankName, rankIndex = rankIndex } end
  end
  return roster
end

-- O próprio jogador tem cargo aceito?
function Guild.IsPlayerTrusted()
  if not IsInGuild() then return false end
  local _, rankName, rankIndex = GetGuildInfo("player")
  return ns.Trust.IsTrustedRank(rankIndex, rankName, ns.Config)
end

-- Confere o cargo de quem enviou. Se o remetente ainda não estiver no roster,
-- atualiza o roster uma vez antes de decidir. callback(trusted)
function Guild.CheckSender(sender, callback)
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

-- Pode criar eventos de guilda no calendário do jogo?
-- Retorna true ou false e o motivo.
function Guild.CanEditCalendar()
  if not IsInGuild() then return false, "Você não está em uma guilda." end
  if C_Calendar.CanAddEvent and not C_Calendar.CanAddEvent() then
    return false, "O calendário do jogo não permite criar eventos agora."
  end
  local _, _, rankIndex = GetGuildInfo("player")
  if rankIndex == 0 then return true end -- Mestre da Guilda
  if rankIndex and C_GuildInfo and C_GuildInfo.GuildControlGetRankFlags then
    local flags = C_GuildInfo.GuildControlGetRankFlags(rankIndex + 1)
    if flags and not flags[ns.Flavor.RANK_FLAG_CREATE_EVENT] then
      return false, "Seu cargo na guilda não tem a permissão \"Criar evento da guilda\"."
    end
  end
  return true
end

ns.Guild = Guild
