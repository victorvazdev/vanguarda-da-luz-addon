-- Mensagens entre addons pelo canal GUILD. Lógica pura.
--
--   Q|<n>       Pedido: "alguém tem exportação mais nova que <n>?" (0 = nenhuma)
--   H|<n>       Aviso: "vou enviar a exportação <n>" (cancela outras respostas)
--   D|<n>|<raw> Dados: a string original da exportação <n>
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

-- Retorna { kind = "query"|"have"|"data", number, raw } ou nil.
function Protocol.Parse(message)
  if type(message) ~= "string" then return nil end
  local kind, number, rest = string.match(message, "^([QHD])|(%d+)(.*)$")
  if not kind then return nil end
  number = tonumber(number)
  if kind == "Q" and rest == "" then return { kind = "query", number = number } end
  if kind == "H" and rest == "" then return { kind = "have", number = number } end
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
