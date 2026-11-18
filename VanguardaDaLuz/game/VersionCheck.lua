-- Aviso de versão nova: o addon anuncia a própria versão à guilda (mensagem
-- I, enviada junto com o pedido Q ao entrar no jogo) e avisa no chat, uma vez
-- por sessão, quando alguém tem uma versão mais nova. Quem tem uma versão mais
-- nova que a anunciada responde com a sua, depois de uma espera aleatória, se
-- ninguém responder antes com uma igual ou mais nova. Nenhum addon consegue
-- consultar a CurseForge de dentro do jogo: o aviso depende de alguém da
-- guilda já ter atualizado.
local _, ns = ...

local L = ns.L

local Version = ns.Version
local VersionCheck = {}

local newest = nil   -- versão mais nova vista na guilda (se maior que a minha)
local warned = false -- já avisou nesta sessão
local response = nil -- resposta agendada: true

function VersionCheck.Mine()
  return ns.version
end

-- Versão mais nova que a minha vista na guilda, ou nil.
function VersionCheck.Newest()
  return newest
end

-- Mensagem I com a minha versão (nil se a versão do .toc não for válida).
function VersionCheck.Message()
  if not Version.Parse(ns.version) then return nil end
  return ns.Protocol.Version(ns.version)
end

local function Warn()
  if warned then return end
  warned = true
  ns.Print(string.format(L["Há uma versão nova do addon (%s); a sua é %s. Atualize pela CurseForge."],
    newest, ns.version))
end

-- Versão anunciada por outro membro.
function VersionCheck.OnAnnounce(message)
  local theirs, mine = message.version, ns.version
  if not Version.Parse(theirs) or not Version.Parse(mine) then return end
  if Version.IsNewer(theirs, mine) then
    response = nil
    if not newest or Version.IsNewer(theirs, newest) then
      newest = theirs
      ns.Fire("VERSION_UPDATED")
    end
    Warn()
    return
  end
  if Version.Compare(theirs, mine) == 0 then
    response = nil -- alguém com a mesma versão já respondeu
    return
  end
  -- Quem anunciou tem uma versão mais velha: conto a minha.
  if response then return end
  response = true
  local delay = ns.Protocol.RandomDelay(ns.Config.RESPONSE_DELAY_MIN, ns.Config.RESPONSE_DELAY_MAX)
  C_Timer.After(delay, function()
    if response then ns.Comm.SendVersion(VersionCheck.Message()) end
    response = nil
  end)
end

ns.VersionCheck = VersionCheck
