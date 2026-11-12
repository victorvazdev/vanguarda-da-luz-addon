-- Alerta de raide: limpeza e validação do texto, mensagem do chat e controle
-- de intervalo e duplicatas. Lógica pura.
local _, ns = ...

local Text = ns.Text
local Alert = {}

-- Limite de uma mensagem de chat do jogo, em bytes.
Alert.CHAT_MAX_BYTES = 255

Alert.ERRORS = {
  empty = "Escreva o texto do alerta.",
  long = "O alerta passou do limite de tamanho.",
  wait = "Aguarde %d s para enviar outro alerta.",
}

-- Uma linha só, sem "|" e sem caracteres de controle, com espaços simples.
function Alert.Clean(text)
  text = Text.ForGame(tostring(text or ""))
  text = string.gsub(text, "\n", " ")
  text = string.gsub(text, "%s+", " ")
  return Text.Trim(text)
end

-- Linha publicada no chat da guilda.
function Alert.ChatLine(text, config)
  return config.ALERT_CHAT_PREFIX .. text
end

-- Retorna o texto limpo ou nil e o código do erro ("empty" ou "long").
function Alert.Validate(text, config)
  text = Alert.Clean(text)
  if text == "" then return nil, "empty" end
  if Text.Length(text) > config.ALERT_MAX_CHARS
    or #Alert.ChatLine(text, config) > Alert.CHAT_MAX_BYTES then
    return nil, "long"
  end
  return text
end

-- Segundos que faltam para poder enviar de novo (0 = pode enviar).
function Alert.WaitTime(lastSentAt, now, interval)
  if not lastSentAt then return 0 end
  local left = interval - (now - lastSentAt)
  if left <= 0 then return 0 end
  return math.ceil(left)
end

-- Identificador do alerta: horário do servidor e um número aleatório.
function Alert.NewId(serverTime, random)
  random = random or math.random
  return string.format("%d%03d", serverTime, random(0, 999))
end

-- Estado do recebimento: alertas já vistos e o último de cada remetente.
function Alert.NewState()
  return { seen = {}, last = {} }
end

-- Mostrar um alerta recebido? Descarta repetidos e alertas do mesmo remetente
-- em intervalo menor que `interval`. `sender` deve vir normalizado.
function Alert.Accept(state, sender, id, now, interval)
  if state.seen[id] then return false, "duplicate" end
  local last = state.last[sender]
  if last and now - last < interval then return false, "interval" end
  state.seen[id] = true
  state.last[sender] = now
  return true
end

ns.Alert = Alert
return Alert
