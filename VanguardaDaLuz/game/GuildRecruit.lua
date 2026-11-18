-- Mensagem de recrutamento do Grão Lorde e dos Lordes: salva o texto (em
-- db.recruit), compartilha com a guilda (mensagens S e Z) e envia num canal do
-- chat com o clique da pessoa. Regras em logic/Recruit.lua.
--
-- Enviar em canais como o Geral só funciona a partir de um clique ou tecla
-- (o jogo exige; mandar sozinho, por tempo, seria spam). Por isso não existe
-- envio automático, e há um intervalo mínimo entre envios.
local _, ns = ...

local L = ns.L

local Recruit = ns.Recruit
local GuildRecruit = {}

local response = nil -- resposta agendada a um pedido: { at }
local lastSent = nil -- GetTime() do último envio no canal

local function Changed()
  ns.Fire("RECRUIT_UPDATED")
end

-- { text, at, by } salvo por último, ou nil.
function GuildRecruit.Get()
  return ns.db.recruit
end

-- O jogador pode editar e enviar?
function GuildRecruit.CanUse()
  return ns.Guild.IsMember() and ns.Guild.IsPlayerTrusted()
end

local function Announce(record)
  ns.Comm.SendRecruit(ns.Protocol.Recruit(Recruit.Encode(record)))
end

-- Mensagem do erro de validação.
function GuildRecruit.ErrorText(code)
  local text = Recruit.ERRORS[code]
  return text and L[text] or code
end

-- Salva o texto e envia para a guilda. Retorna o registro ou nil e o erro.
function GuildRecruit.Save(text)
  if not GuildRecruit.CanUse() then
    return nil, L["Somente o Grão Lorde e os Lordes podem usar a mensagem de recrutamento."]
  end
  local clean, code = Recruit.Validate(text)
  if not clean then return nil, GuildRecruit.ErrorText(code) end
  local current = ns.db.recruit
  if current and current.text == clean then return current end
  local record = { text = clean, at = GetServerTime(), by = ns.Guild.PlayerName() or UnitName("player") }
  -- Salvo no mesmo segundo que o atual: passa na frente.
  if current and record.at <= current.at then record.at = current.at + 1 end
  ns.db.recruit = record
  response = nil
  Announce(record)
  Changed()
  return record
end

-- Canais do chat em que o personagem está e o escolhido para o envio.
function GuildRecruit.Channels()
  return Recruit.Channels(ns.Flavor.ChatChannels())
end

function GuildRecruit.Channel()
  return Recruit.PickChannel(GuildRecruit.Channels(), ns.db.settings.recruitChannel)
end

-- Troca para o próximo canal da lista e guarda a escolha (por conta).
function GuildRecruit.NextChannel()
  local channel = Recruit.NextChannel(GuildRecruit.Channels(), GuildRecruit.Channel())
  if channel then
    ns.db.settings.recruitChannel = channel.name
    Changed()
  end
  return channel
end

-- "1. Geral"
function GuildRecruit.ChannelLabel(channel)
  if not channel then return L["nenhum canal"] end
  return channel.id .. ". " .. channel.name
end

-- Segundos que faltam para poder enviar de novo (0 = pode).
function GuildRecruit.WaitTime()
  return ns.Alert.WaitTime(lastSent, GetTime(), ns.Config.RECRUIT_INTERVAL)
end

-- Envia o texto salvo no canal escolhido. Chamado só pelo clique num botão.
-- Retorna true e o canal, ou false e o erro.
function GuildRecruit.Send()
  if not GuildRecruit.CanUse() then
    return false, L["Somente o Grão Lorde e os Lordes podem usar a mensagem de recrutamento."]
  end
  local record = ns.db.recruit
  if not record then return false, L["Salve a mensagem de recrutamento antes de enviar."] end
  local wait = GuildRecruit.WaitTime()
  if wait > 0 then return false, string.format(L["Aguarde %d s para enviar a mensagem de novo."], wait) end
  if ns.Flavor.InMessagingLockdown() then
    return false, L["O chat está restrito no momento (luta com chefe, chave ou JxJ). Tente depois."]
  end
  local channel = GuildRecruit.Channel()
  if not channel then return false, L["Entre num canal do chat (como o Geral) para enviar."] end
  local ok, err = ns.Flavor.SendChannelMessage(record.text, channel.id)
  if not ok then return false, string.format(L["O jogo não deixou enviar: %s"], tostring(err)) end
  lastSent = GetTime()
  return true, channel
end

-- Texto recebido de outro membro: só vale de quem tem cargo aceito.
function GuildRecruit.OnReceived(message, sender)
  local record = Recruit.Decode(message.payload)
  if not record then return end
  if response and record.at >= response.at then response = nil end
  if not Recruit.IsNewer(ns.db.recruit, record) then return end
  ns.Guild.CheckSender(sender, function(trusted)
    if not trusted or not Recruit.IsNewer(ns.db.recruit, record) then return end
    ns.db.recruit = record
    Changed()
  end)
end

-- Alguém pediu o texto: o Grão Lorde ou um Lorde responde depois de uma
-- espera aleatória, se ninguém responder antes com um texto igual ou mais novo.
function GuildRecruit.OnRequest()
  local record = ns.db.recruit
  if response or not record or not ns.Guild.IsPlayerTrusted() then return end
  response = { at = record.at }
  local delay = ns.Protocol.RandomDelay(ns.Config.RESPONSE_DELAY_MIN, ns.Config.RESPONSE_DELAY_MAX)
  C_Timer.After(delay, function()
    if response and ns.db.recruit then Announce(ns.db.recruit) end
    response = nil
  end)
end

ns.GuildRecruit = GuildRecruit
