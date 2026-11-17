-- Botão "Convidar para a guilda" da aba Membros. Só para quem o jogo deixa
-- convidar (permissão do posto, Flavor.CanGuildInvite).
--   modo "invite" (por cima da aba Membros da janela da guilda): aciona o
--   botão de convite da própria Blizzard (CommunitiesFrame.InviteButton), que
--   abre a janela de convite dela; o nome é digitado lá;
--   modo "open" (janela do addon): abre a janela da guilda, onde o botão do
--   modo "invite" convida.
--
-- Convidar pelo código do addon é bloqueado no WoW Forever, tanto
-- C_GuildInfo.Invite quanto "/ginvite" num botão seguro de macro (confirmado
-- no jogo). Como em ui/GuildTextEdit.lua, o clique cai num botão seguro do
-- addon (SecureActionButtonTemplate, type "click") que aciona o botão da
-- Blizzard: o código da Blizzard roda limpo.
--
-- O jogo não deixa ancorar o botão seguro em quadros do addon: ele é
-- posicionado pela tela em cima do botão do addon e acompanha a janela. Em
-- combate o botão seguro não pode ser mexido: ao entrar, é escondido e solto
-- do painel; ao sair, volta.
local _, ns = ...

local L = ns.L

local GuildInviteButton = {}

local invites = {} -- { visual, host, mode, button, usable, placed }
local events
local FOLLOW_INTERVAL = 0.25
local NOTICE_INTERVAL = 2

-- Botão da Blizzard que o clique aciona.
local function Target(mode)
  if mode == "open" then return ns.Flavor.GuildOpenButton() end
  return ns.Flavor.GuildInviteButton()
end

-- O botão do addon aparece? (a permissão de convidar vem do posto)
function GuildInviteButton.CanInvite()
  return ns.Guild.IsMember() and ns.Flavor.CanGuildInvite()
end

-- O clique pode acionar o botão da Blizzard agora?
local function Usable(mode)
  if not (GuildInviteButton.CanInvite() and Target(mode)) then return false end
  if mode == "open" then
    -- Com a janela da guilda aberta, o botão Guilda a fecharia.
    return not ns.Flavor.IsGuildWindowShown()
  end
  -- O botão da Blizzard convida para o clube selecionado: tem de ser a guilda.
  return ns.Flavor.IsGuildClubSelected(_G[ns.Flavor.guildWindow.frame])
end

-- Depois do clique (o clique chega ao apertar e ao soltar: avisa uma vez só).
local lastNotice
local function OnClicked(invite)
  if lastNotice and GetTime() - lastNotice < NOTICE_INTERVAL then return end
  lastNotice = GetTime()
  if invite.mode == "open" then
    ns.MainFrame.Hide()
    ns.Print(L["Na janela da guilda, abra Membros e clique em Convidar para a guilda."])
  end
end

-- Cria o botão seguro (fora de combate).
local function Build(invite)
  local target = Target(invite.mode)
  if not target then return end
  local button = CreateFrame("Button", nil, invite.host, "SecureActionButtonTemplate")
  button:RegisterForClicks("AnyUp", "AnyDown")
  button:SetAttribute("type", "click")
  button:SetAttribute("clickbutton", target)
  button:HookScript("OnEnter", function() invite.visual:LockHighlight() end)
  button:HookScript("OnLeave", function() invite.visual:UnlockHighlight() end)
  button:HookScript("PostClick", function() OnClicked(invite) end)
  button:Hide()
  invite.button = button
end

local function Spot(visual)
  local left, top, width, height = visual:GetLeft(), visual:GetTop(), visual:GetWidth(), visual:GetHeight()
  if not (left and top and width and height) then return nil end
  return left, top, width, height
end

-- Põe o botão seguro em cima do botão do addon, pela posição na tela.
-- Retorna false se o jogo recusar.
local function Place(invite)
  local left, top, width, height = Spot(invite.visual)
  if not left then return false end
  invite.placed = left .. ":" .. top .. ":" .. width .. ":" .. height
  local button, visual = invite.button, invite.visual
  return pcall(function()
    button:SetParent(invite.host)
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    button:SetSize(width, height)
    button:SetFrameLevel((visual:GetFrameLevel() or 1) + 2)
  end)
end

-- Mostra o botão do addon e liga o botão seguro por cima (fora de combate).
local function Update(invite)
  invite.visual:SetShown(GuildInviteButton.CanInvite())
  if InCombatLockdown() then return end
  if not invite.button then Build(invite) end
  local usable = invite.button ~= nil and invite.visual:IsShown() and Usable(invite.mode)
  if usable then usable = Place(invite) end
  invite.usable = usable
  if invite.button then invite.button:SetShown(usable) end
end

-- Com o painel na tela: o botão acompanha quando a janela anda ou muda de
-- tamanho, e liga/desliga quando a permissão, o clube ou a janela da guilda
-- mudam.
local function Follow(invite, elapsed)
  invite.wait = (invite.wait or 0) - (elapsed or 0)
  if invite.wait > 0 or InCombatLockdown() then return end
  invite.wait = FOLLOW_INTERVAL
  local usable = GuildInviteButton.CanInvite() and Usable(invite.mode)
  if (usable and true or false) ~= (invite.usable and true or false) then
    Update(invite)
    return
  end
  if not (invite.usable and invite.button) then return end
  local left, top, width, height = Spot(invite.visual)
  if left and left .. ":" .. top .. ":" .. width .. ":" .. height ~= invite.placed then Place(invite) end
end

function GuildInviteButton.Refresh()
  for _, invite in ipairs(invites) do Update(invite) end
end

-- Entrando em combate: esconde e solta os botões seguros (ainda é permitido).
local function OnCombatStart()
  for _, invite in ipairs(invites) do
    if invite.button then
      invite.button:Hide()
      invite.button:ClearAllPoints()
      invite.button:SetParent(UIParent)
    end
    invite.usable = false
  end
end

-- Clique no botão do addon sem o botão seguro por cima (combate, ou a janela
-- da guilda não está pronta): diz o que fazer.
local function OnVisualClick(invite)
  if InCombatLockdown() then
    ns.Print(L["Em combate não dá para convidar. Tente ao sair do combate."])
  elseif invite.mode == "open" then
    ns.Print(L["Na janela da guilda, abra Membros e clique em Convidar para a guilda."])
  else
    ns.Print(L["Selecione a guilda na janela da guilda para convidar."])
  end
end

-- Liga o convite no botão `visual` do painel `host`; `mode` é "invite"
-- (janela da guilda) ou "open" (janela do addon).
function GuildInviteButton.Attach(visual, host, mode)
  local invite = { visual = visual, host = host, mode = mode }
  invites[#invites + 1] = invite
  visual:SetScript("OnClick", function() OnVisualClick(invite) end)
  host:HookScript("OnUpdate", function(_, elapsed) Follow(invite, elapsed) end)
  if not events then
    events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function(_, event)
      if event == "PLAYER_REGEN_DISABLED" then OnCombatStart() else GuildInviteButton.Refresh() end
    end)
  end
  GuildInviteButton.invites = invites -- para o teste de fumaça
  GuildInviteButton.OnCombatStart = OnCombatStart
  return invite
end

ns.GuildInviteButton = GuildInviteButton
