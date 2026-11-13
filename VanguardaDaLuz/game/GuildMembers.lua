-- Item level e main/alt dos membros: lê os do próprio personagem, anuncia
-- para a guilda e repassa os conhecidos. Regras em logic/Members.lua.
--
-- O main é da conta (ns.db.settings.main): definido com /vdl main num
-- personagem, os outros personagens da conta na guilda viram alts dele ao logar.
local _, ns = ...

local L = ns.L

local Members = ns.Members
local GuildMembers = {}

local response = nil  -- resposta agendada a um pedido
local announcing = false

local function Store()
  return ns.db.members
end

local function Changed()
  ns.Fire("MEMBERS_UPDATED")
end

function GuildMembers.Init()
  ns.db.members = ns.db.members or {}
end

-- Dados de um personagem (nil se o addon dele ainda não informou).
function GuildMembers.Get(name)
  return name and Store()[name] or nil
end

-- Anuncia o próprio item level e main se mudaram desde o último anúncio.
-- Espera a lista da guilda carregar (para saber se o main ainda está nela).
function GuildMembers.Announce()
  if not ns.Guild.IsMember() then return end
  local me = ns.Guild.PlayerName()
  local level = ns.Flavor.OwnItemLevel()
  local members = ns.Flavor.GuildMembers()
  if not (me and level and members) then return end
  local names = {}
  for _, member in ipairs(members) do names[member.name] = true end
  Members.Prune(Store(), names)
  local record = { i = level, m = Members.MainFor(ns.db.settings.main, names) }
  local current = Store()[me]
  if Members.Same(current, record) then return end
  local at = GetServerTime()
  if current and current.t >= at then at = current.t + 1 end
  if not Members.Set(Store(), me, record, at) then return end
  ns.Comm.SendMember(ns.Protocol.Member(at, Members.EncodeOwn(record)))
  Changed()
end

-- Troca de equipamento: espera um pouco para juntar várias peças num anúncio.
function GuildMembers.OnEquipmentChanged()
  if announcing then return end
  announcing = true
  C_Timer.After(ns.Config.MEMBERS_ANNOUNCE_DELAY, function()
    announcing = false
    GuildMembers.Announce()
  end)
end

-- Define o personagem atual como main da conta.
function GuildMembers.SetMain()
  local me = ns.Guild.PlayerName()
  if not me then
    ns.Print(L["A lista da guilda ainda não carregou. Tente de novo em alguns segundos."])
    return
  end
  ns.db.settings.main = me
  ns.Fire("SETTINGS_UPDATED")
  ns.Print(string.format(L["%s agora é o seu main. Os outros personagens desta conta na guilda aparecem como "
    .. "alts ao logar."], me))
  GuildMembers.Announce()
end

-- Desfaz o main da conta: os personagens deixam de aparecer como main/alt.
function GuildMembers.ClearMain()
  ns.db.settings.main = nil
  ns.Fire("SETTINGS_UPDATED")
  ns.Print(L["Main desmarcado. Os personagens desta conta deixam de aparecer como main ou alt."])
  GuildMembers.Announce()
end

-- O personagem atual é o main da conta?
function GuildMembers.IsMain()
  local me = ns.Guild.PlayerName()
  return me ~= nil and ns.db.settings.main == me
end

-- Dados anunciados pelo próprio remetente.
function GuildMembers.OnOwn(message, sender)
  local record = Members.DecodeOwn(message.payload)
  if record and Members.Set(Store(), sender, record, message.at) then Changed() end
end

-- Alguém pediu os dados: responde depois de uma espera aleatória, se ninguém
-- responder antes.
function GuildMembers.OnRequest()
  if response or not next(Store()) then return end
  response = true
  local delay = ns.Protocol.RandomDelay(ns.Config.RESPONSE_DELAY_MIN, ns.Config.RESPONSE_DELAY_MAX)
  C_Timer.After(delay, function()
    if response then
      ns.Comm.SendMembersList(ns.Protocol.MembersList(Members.EncodeStore(Store())))
    end
    response = nil
  end)
end

-- Dados repassados por outro membro.
function GuildMembers.OnList(message)
  response = nil
  local other = Members.DecodeStore(message.payload)
  if other and Members.Merge(Store(), other) > 0 then Changed() end
end

ns.GuildMembers = GuildMembers
