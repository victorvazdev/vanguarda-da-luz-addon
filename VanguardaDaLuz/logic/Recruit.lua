-- Mensagem de recrutamento: texto definido pelo Grão Lorde ou por um Lorde,
-- compartilhado entre eles pela guilda (mensagem S, logic/Protocol.lua) e
-- enviado num canal do chat (Geral, por exemplo) com um clique. Lógica pura.
--
-- Carga da mensagem S: "<t>|<quem salvou>|<texto>", com t = horário do
-- servidor em que o texto foi salvo. Fica o texto salvo por último.
local _, ns = ...

local Text = ns.Text
local Recruit = {}

-- Limite de uma mensagem de chat do jogo, em bytes.
Recruit.MAX_BYTES = 255

Recruit.ERRORS = {
  empty = "Escreva a mensagem de recrutamento.",
  long = "A mensagem passou do limite de 255 bytes do chat.",
}

-- Uma linha só, sem "|" e sem caracteres de controle, com espaços simples.
function Recruit.Clean(text)
  text = Text.ForGame(tostring(text or ""))
  text = string.gsub(text, "\n", " ")
  text = string.gsub(text, "%s+", " ")
  return Text.Trim(text)
end

-- Retorna o texto limpo ou nil e o código do erro ("empty" ou "long").
function Recruit.Validate(text)
  text = Recruit.Clean(text)
  if text == "" then return nil, "empty" end
  if #text > Recruit.MAX_BYTES then return nil, "long" end
  return text
end

-- Carga da mensagem S de `record` = { text, at, by }.
function Recruit.Encode(record)
  return record.at .. "|" .. record.by .. "|" .. record.text
end

-- { text, at, by } de uma carga recebida, ou nil se for inválida.
function Recruit.Decode(payload)
  if type(payload) ~= "string" then return nil end
  local at, by, text = string.match(payload, "^(%d+)|([^|]+)|(.+)$")
  if not at then return nil end
  if Recruit.Validate(text) ~= text then return nil end
  return { text = text, at = tonumber(at), by = by }
end

-- `incoming` substitui `current`? Fica o salvo por último; no mesmo segundo,
-- desempata pelo nome para todos ficarem com o mesmo texto.
function Recruit.IsNewer(current, incoming)
  if not incoming then return false end
  if not current then return true end
  if incoming.at ~= current.at then return incoming.at > current.at end
  if incoming.by ~= current.by then return incoming.by > current.by end
  return false
end

-- Canais do chat a partir de GetChannelList() (id, nome, desativado, ...):
-- { { id, name }, ... } sem os desativados, na ordem dos números.
function Recruit.Channels(...)
  local list = {}
  local values = { ... }
  for i = 1, #values, 3 do
    local id, name, disabled = values[i], values[i + 1], values[i + 2]
    if type(id) == "number" and type(name) == "string" and name ~= "" and not disabled then
      list[#list + 1] = { id = id, name = name }
    end
  end
  table.sort(list, function(a, b) return a.id < b.id end)
  return list
end

-- O canal escolhido (`saved` = nome), ou o primeiro da lista (o Geral costuma
-- ser o 1). nil se não houver canal.
function Recruit.PickChannel(channels, saved)
  for _, channel in ipairs(channels) do
    if channel.name == saved then return channel end
  end
  return channels[1]
end

-- O canal seguinte da lista, para o botão que troca de canal.
function Recruit.NextChannel(channels, current)
  if #channels == 0 then return nil end
  for i, channel in ipairs(channels) do
    if current and channel.name == current.name then return channels[i % #channels + 1] end
  end
  return channels[1]
end

ns.Recruit = Recruit
return Recruit
