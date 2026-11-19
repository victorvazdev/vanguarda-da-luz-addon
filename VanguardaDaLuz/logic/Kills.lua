-- Abates honrosos dos membros da guilda (jogadores da facção inimiga mortos
-- com a participação do personagem, que deram honra). Lógica pura.
--
-- O jogo só informa os abates do próprio personagem (GetPVPLifetimeStats),
-- então cada addon anuncia os seus. O total só cresce: ao receber dados de
-- outro membro vale o maior valor, como no tempo com a guilda
-- (logic/Together.lua, de onde vêm as regras de mescla, mensagens e soma
-- por pessoa).
--
-- `store` = { [personagem] = abates honrosos }
-- Por pessoa: os alts somam no main (logic/Members.lua, campo `m`).
local _, ns = ...

local Kills = {}

-- Registra o total de um personagem, se for maior. Retorna true se mudou.
function Kills.Set(store, who, kills)
  return ns.Together.Set(store, who, kills)
end

-- Mescla outro `store`. Retorna quantos personagens mudaram.
function Kills.Merge(store, other)
  return ns.Together.Merge(store, other)
end

-- Apaga quem não está mais na guilda. `members` = { [nome] = true }.
function Kills.Prune(store, members)
  ns.Together.Prune(store, members)
end

-- Total do próprio remetente: "<abates>".
function Kills.EncodeOwn(kills)
  return ns.Together.EncodeOwn(kills)
end

function Kills.DecodeOwn(payload)
  return ns.Together.DecodeOwn(payload)
end

-- Todos os totais conhecidos: "<personagens>" e "<nome><abates>" em ordem.
function Kills.EncodeStore(store)
  return ns.Together.EncodeStore(store)
end

function Kills.DecodeStore(payload)
  return ns.Together.DecodeStore(payload)
end

-- Total por pessoa: { [pessoa] = abates }.
function Kills.Totals(store, membersStore)
  return ns.Together.Totals(store, membersStore)
end

-- As `limit` pessoas com mais abates: { { name, kills }, ... }, sem quem tem 0.
function Kills.Ranking(totals, limit)
  local list = ns.Together.Ranking(totals, limit)
  for _, item in ipairs(list) do item.kills, item.seconds = item.seconds, nil end
  return list
end

ns.Kills = Kills
return Kills
