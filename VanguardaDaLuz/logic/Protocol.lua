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

-- Retorna { kind = "query"|"have"|"data", number, raw }, { kind = "alert", id,
-- text }, { kind = "presence", eventId, status, at }, { kind = "presenceRequest" },
-- { kind = "presenceList", encoded }, { kind = "professions", at, payload },
-- { kind = "professionsRequest" }, { kind = "professionsList", payload } ou nil.
function Protocol.Parse(message)
  if type(message) ~= "string" then return nil end
  if message == "R" then return { kind = "presenceRequest" } end
  if message == "G" then return { kind = "professionsRequest" } end
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
