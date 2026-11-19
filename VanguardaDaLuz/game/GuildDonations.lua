-- Ouro doado ao banco da guilda: o addon guarda o próprio registro de
-- depósitos, completado com o registro de dinheiro do banco sempre que alguém
-- com o addon abre o banco. Regras em logic/Donations.lua.
--
-- O registro do banco só chega com o banco aberto num banqueiro: ao abrir, o
-- addon pede o registro (QueryGuildBankLog), e de novo logo depois de o
-- dinheiro do banco mudar (o próprio depósito). A resposta chega em
-- GUILDBANKLOG_UPDATE, também quando a aba de registro da Blizzard pede. Os
-- depósitos novos vão para a guilda (g); quem entra no jogo pede os
-- conhecidos (j, com quantos já tem) e responde quem tem mais (l). Os
-- depósitos de quem saiu da guilda são apagados quando o roster muda.
local _, ns = ...

local Donations = ns.Donations
local GuildDonations = {}

local response = nil  -- resposta agendada a um pedido
local bankOpen = false
local queryPending = false

local function Store()
  return ns.db.donations
end

local function Changed()
  ns.Fire("DONATIONS_UPDATED")
end

function GuildDonations.Init()
  ns.db.donations = ns.db.donations or {}
end

-- Quantos depósitos o registro tem (vai no pedido: só responde quem tem mais).
function GuildDonations.Count()
  return #Store()
end

-- Apaga os depósitos de quem saiu da guilda. `members` = { [nome] = linha }.
function GuildDonations.Prune(members)
  Donations.Prune(Store(), members)
end

-- Total por pessoa (main com os alts), em cobre.
function GuildDonations.Totals()
  return Donations.Totals(Store(), ns.db.members)
end

-- Lê o registro de dinheiro carregado e guarda os depósitos novos.
function GuildDonations.ReadLog()
  if not ns.Guild.IsMember() then return end
  local entries = Donations.FromLog(ns.Flavor.MoneyLog(), GetServerTime())
  local added = Donations.Absorb(Store(), entries)
  if #added == 0 then return end
  Changed()
  ns.Comm.SendDonations(ns.Protocol.Donations(Donations.Encode(added)))
end

-- Pede o registro ao servidor (com o banco aberto), uma vez a cada espera.
function GuildDonations.Query()
  if not (bankOpen and ns.Guild.IsMember()) or queryPending then return end
  queryPending = true
  C_Timer.After(ns.Config.DONATIONS_QUERY_DELAY, function()
    queryPending = false
    if bankOpen then ns.Flavor.QueryMoneyLog() end
  end)
end

function GuildDonations.OnBankOpened()
  bankOpen = true
  GuildDonations.Query()
end

function GuildDonations.OnBankClosed()
  bankOpen = false
end

function GuildDonations.OnInteractionShow(_, kind)
  if ns.Flavor.IsGuildBankInteraction(kind) then GuildDonations.OnBankOpened() end
end

function GuildDonations.OnInteractionHide(_, kind)
  if ns.Flavor.IsGuildBankInteraction(kind) then GuildDonations.OnBankClosed() end
end

-- Depósitos achados por outro membro no registro do banco.
function GuildDonations.OnFound(message)
  local entries = Donations.Decode(message.payload)
  if entries and #Donations.Absorb(Store(), entries) > 0 then Changed() end
end

-- Alguém pediu os depósitos: responde depois de uma espera aleatória, se
-- tiver mais que ele e ninguém responder antes.
function GuildDonations.OnRequest(message)
  if response or #Store() <= ((message and message.count) or 0) then return end
  response = true
  local delay = ns.Protocol.RandomDelay(ns.Config.RESPONSE_DELAY_MIN, ns.Config.RESPONSE_DELAY_MAX)
  C_Timer.After(delay, function()
    if response then
      ns.Comm.SendDonationsList(ns.Protocol.DonationsList(Donations.Encode(Store())))
    end
    response = nil
  end)
end

-- Depósitos repassados por outro membro.
function GuildDonations.OnList(message)
  response = nil
  GuildDonations.OnFound(message)
end

ns.GuildDonations = GuildDonations
