-- Quem pode ser fonte dos dados: membros com cargo aceito na configuração.
-- Lógica pura.
local _, ns = ...

local Trust = {}

-- O jogador está na guilda do addon? `guildName` vem de GetGuildInfo e é nil
-- fora de guilda (ou enquanto o jogo ainda não carregou a guilda).
function Trust.IsOurGuild(guildName, config)
  return guildName ~= nil and guildName == config.GUILD_NAME
end

-- `rankIndex` começa em 0 (Mestre da Guilda).
function Trust.IsTrustedRank(rankIndex, rankName, config)
  if rankIndex ~= nil and rankIndex <= config.TRUSTED_MAX_RANK_INDEX then return true end
  for _, name in ipairs(config.TRUSTED_RANK_NAMES or {}) do
    if rankName == name then return true end
  end
  return false
end

local function BaseName(name)
  return (string.match(name, "^([^%-]+)")) or name
end

-- Compara nomes de personagem com ou sem o sufixo "-Reino".
function Trust.SameName(a, b)
  if not a or not b then return false end
  if a == b then return true end
  local aHasRealm, bHasRealm = string.find(a, "-", 1, true), string.find(b, "-", 1, true)
  if aHasRealm and bHasRealm then return false end
  return BaseName(a) == BaseName(b)
end

-- Procura `sender` no roster: lista de { name, rankName, rankIndex }.
-- Retorna true/false, ou nil se o remetente não estiver no roster.
function Trust.IsTrustedSender(sender, roster, config)
  for _, member in ipairs(roster) do
    if Trust.SameName(member.name, sender) then
      return Trust.IsTrustedRank(member.rankIndex, member.rankName, config)
    end
  end
  return nil
end

ns.Trust = Trust
return Trust
