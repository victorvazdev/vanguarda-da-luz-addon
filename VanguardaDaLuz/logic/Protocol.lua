-- Mensagens entre addons pelo canal GUILD. Lógica pura.
--
--   Q|<n>       Pedido: "alguém tem exportação mais nova que <n>?" (0 = nenhuma)
--   H|<n>       Aviso: "vou enviar a exportação <n>" (cancela outras respostas)
--   D|<n>|<raw> Dados: a string original da exportação <n>
--   A|<id>|<txt> Alerta de raide (logic/Alert.lua)
--   P|<evento>|<1 ou 0>|<t>  Presença do próprio remetente num evento
--   R           Pedido: "alguém me manda as presenças que conhece?"
--   L|<VDLP1>   Presenças conhecidas, numa string VDLP1 (logic/PresenceCodec.lua)
--   F|<t>|<lista>  Profissões e níveis do próprio remetente (logic/Professions.lua)
--   G           Pedido: "alguém me manda os níveis de profissão que conhece?"
--   K|<lista>   Níveis de profissão conhecidos (logic/Professions.lua)
--   J|<t>|<lista>  Como F, com o ID de cada profissão (casa em qualquer idioma)
--   Y           Como G, pedindo a resposta com IDs (X)
--   X|<lista>   Como K, com IDs
--   M|<t>|<dados>  Item level e main do próprio remetente (logic/Members.lua)
--   N           Pedido: "alguém me manda os item levels e mains que conhece?"
--   O|<lista>   Item levels e mains conhecidos (logic/Members.lua)
--   T|<total>   Tempo de jogo com a guilda do próprio remetente (logic/Together.lua)
--   U           Pedido: "alguém me manda os tempos com a guilda que conhece?"
--   V|<lista>   Tempos com a guilda conhecidos (logic/Together.lua)
--
-- A AceComm divide e junta as mensagens grandes.
local _, ns = ...

local Protocol = {}

function Protocol.Query(exportNumber)
  return "Q|" .. (exportNumber or 0)
end

function Protocol.Have(exportNumber)
  return "H|" .. exportNumber
end

function Protocol.Data(exportNumber, raw)
  return "D|" .. exportNumber .. "|" .. raw
end

function Protocol.Alert(id, text)
  return "A|" .. id .. "|" .. text
end

function Protocol.Presence(eventId, status, at)
  return "P|" .. eventId .. "|" .. status .. "|" .. at
end

function Protocol.PresenceRequest()
  return "R"
end

function Protocol.PresenceList(encoded)
  return "L|" .. encoded
end

function Protocol.Professions(at, payload)
  return "F|" .. at .. "|" .. payload
end

function Protocol.ProfessionsRequest()
  return "G"
end

function Protocol.ProfessionsList(payload)
  return "K|" .. payload
end

function Protocol.ProfessionIds(at, payload)
  return "J|" .. at .. "|" .. payload
end

function Protocol.ProfessionIdsRequest()
  return "Y"
end

function Protocol.ProfessionIdsList(payload)
  return "X|" .. payload
end

function Protocol.Member(at, payload)
  return "M|" .. at .. "|" .. payload
end

function Protocol.MembersRequest()
  return "N"
end

function Protocol.MembersList(payload)
  return "O|" .. payload
end

function Protocol.Together(payload)
  return "T|" .. payload
end

function Protocol.TogetherRequest()
  return "U"
end

function Protocol.TogetherList(payload)
  return "V|" .. payload
end

-- Retorna { kind = "query"|"have"|"data", number, raw }, { kind = "alert", id,
-- text }, { kind = "presence", eventId, status, at }, { kind = "presenceRequest" },
-- { kind = "presenceList", encoded }, { kind = "professions", at, payload },
-- { kind = "professionsRequest" }, { kind = "professionsList", payload } (com
-- `withIds` = true quando vêm de J, Y e X),
-- { kind = "member", at, payload }, { kind = "membersRequest" },
-- { kind = "membersList", payload }, { kind = "together", payload },
-- { kind = "togetherRequest" }, { kind = "togetherList", payload } ou nil.
function Protocol.Parse(message)
  if type(message) ~= "string" then return nil end
  if message == "R" then return { kind = "presenceRequest" } end
  if message == "G" then return { kind = "professionsRequest" } end
  if message == "Y" then return { kind = "professionsRequest", withIds = true } end
  local idsAt, ids = string.match(message, "^J|(%d+)|(%d.*)$")
  if idsAt then return { kind = "professions", at = tonumber(idsAt), payload = ids, withIds = true } end
  local idsList = string.match(message, "^X|(%d.*)$")
  if idsList then return { kind = "professionsList", payload = idsList, withIds = true } end
  if message == "N" then return { kind = "membersRequest" } end
  if message == "U" then return { kind = "togetherRequest" } end
  local together = string.match(message, "^T|(%d.*)$")
  if together then return { kind = "together", payload = together } end
  local togetherList = string.match(message, "^V|(%d.*)$")
  if togetherList then return { kind = "togetherList", payload = togetherList } end
  local memberAt, member = string.match(message, "^M|(%d+)|(%d.*)$")
  if memberAt then return { kind = "member", at = tonumber(memberAt), payload = member } end
  local members = string.match(message, "^O|(%d.*)$")
  if members then return { kind = "membersList", payload = members } end
  local ownAt, own = string.match(message, "^F|(%d+)|(%d.*)$")
  if ownAt then return { kind = "professions", at = tonumber(ownAt), payload = own } end
  local known = string.match(message, "^K|(%d.*)$")
  if known then return { kind = "professionsList", payload = known } end
  local eventId, status, at = string.match(message, "^P|(%w+)|([01])|(%d+)$")
  if eventId then
    return { kind = "presence", eventId = eventId, status = tonumber(status), at = tonumber(at) }
  end
  local encoded = string.match(message, "^L|(VDLP.+)$")
  if encoded then return { kind = "presenceList", encoded = encoded } end
  local kind, number, rest = string.match(message, "^([QHDA])|(%d+)(.*)$")
  if not kind then return nil end
  number = tonumber(number)
  if kind == "Q" and rest == "" then return { kind = "query", number = number } end
  if kind == "H" and rest == "" then return { kind = "have", number = number } end
  if kind == "A" then
    local text = string.match(rest, "^|(.+)$")
    if text then return { kind = "alert", id = number, text = text } end
    return nil
  end
  if kind == "D" then
    local raw = string.match(rest, "^|(VDL.+)$")
    if raw then return { kind = "data", number = number, raw = raw } end
  end
  return nil
end

-- Devo responder a um pedido? Só quem tem cargo aceito e dados mais novos.
function Protocol.ShouldRespond(myNumber, requested, iAmTrusted)
  return iAmTrusted and myNumber ~= nil and myNumber > (requested or 0)
end

-- Outro remetente vai enviar (ou enviou) dados iguais ou mais novos que os que
-- eu ia enviar: cancelo a minha resposta.
function Protocol.ShouldCancel(myPendingNumber, seenNumber)
  return myPendingNumber ~= nil and seenNumber >= myPendingNumber
end

-- Vale a pena processar dados recebidos?
function Protocol.IsNewer(number, myNumber)
  return number > (myNumber or 0)
end

-- Espera aleatória entre min e max segundos. `random` é math.random ou outra
-- função com a mesma assinatura (para os testes).
function Protocol.RandomDelay(min, max, random)
  random = random or math.random
  return min + (max - min) * random()
end

ns.Protocol = Protocol
return Protocol
