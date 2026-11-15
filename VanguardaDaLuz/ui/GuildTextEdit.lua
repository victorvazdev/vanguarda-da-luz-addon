-- Clique na mensagem do dia ou nas informações da guilda no Início abre a
-- edição. Só para o Grão Lorde e os Lordes que o jogo deixa editar.
--   modo "edit" (Início na janela da guilda): abre a janela de edição da Blizzard;
--   modo "open" (Início da janela do addon): abre a janela da guilda, onde o
--   clique no texto edita. O botão de edição da Blizzard só existe com ela
--   carregada, e a edição só vem com o texto atual com ela aberta.
--
-- O jogo bloqueia a gravação se o addon abrir a janela de edição pelo código
-- (ForceTaint_Strong). Por isso o clique cai num botão seguro do addon
-- (SecureActionButtonTemplate, type "click") que aciona o botão "Editar" da
-- própria Blizzard: o código da Blizzard roda limpo e grava (confirmado no
-- jogo). Com a janela da guilda aberta, a edição já vem com o texto atual.
-- A janela da guilda também precisa abrir por um botão seguro (aciona o botão
-- Guilda do menu do jogo): aberta pelo código do addon, o jogo bloqueia a
-- gravação depois (confirmado no jogo).
--
-- O botão seguro fica por baixo do texto. O texto deixa o clique passar para
-- ele (SetPropagateMouseClicks), menos com o mouse em cima de um link, que
-- continua abrindo a caixa de copiar.
--
-- Botões seguros não podem ser mexidos em combate, e o quadro pai de um botão
-- seguro também fica travado. Ao entrar em combate o botão é escondido e
-- solto do painel; ao sair, volta.
--
-- O jogo não deixa ancorar um botão seguro em quadros do addon ("Cannot anchor
-- protected frames to regions"). O botão é posicionado pela tela (em relação
-- ao UIParent) no lugar do texto, e reposicionado quando a janela da guilda
-- se move ou muda de tamanho.
local _, ns = ...

local L = ns.L

local Theme = ns.Theme
local GuildTextEdit = {}

local editors = {}  -- { card, holder, kind, mode, button }
local events
local refreshAfterEdit = false
local FOLLOW_INTERVAL = 0.25
local NOTICE_INTERVAL = 2

-- Botão da Blizzard que o clique aciona.
local function Target(kind, mode)
  if mode == "open" then return ns.Flavor.GuildOpenButton() end
  return ns.Flavor.GuildTextEditButton(kind)
end

-- Pode editar este texto? `mode` é "edit" (padrão) ou "open".
function GuildTextEdit.CanEdit(kind, mode)
  mode = mode or "edit"
  if not (ns.Guild.IsPlayerTrusted() and ns.Flavor.CanEditGuildText(kind) and Target(kind, mode)) then
    return false
  end
  -- Com a janela da guilda aberta, o botão Guilda a fecharia.
  return mode ~= "open" or not ns.Flavor.IsGuildWindowShown()
end

function GuildTextEdit.CanEditAny(mode)
  return GuildTextEdit.CanEdit("motd", mode) or GuildTextEdit.CanEdit("info", mode)
end

local function ClickThrough(holder, on)
  if holder.SetPropagateMouseClicks then holder:SetPropagateMouseClicks(on and true or false) end
end

local function Highlight(editor, on)
  Theme.Backdrop(editor.card, "surface", on and editor.editable and "gold" or "border")
end

-- Depois de editar, o texto novo aparece no Início.
local function WatchEditFrame()
  if refreshAfterEdit then return end
  local frame = _G[ns.Flavor.guildWindow.textEditFrame]
  if not (frame and frame.HookScript) then return end
  refreshAfterEdit = true
  frame:HookScript("OnHide", function()
    C_Timer.After(1, function()
      ns.Guild.RequestRoster()
      ns.Fire("GUILD_UPDATED")
    end)
  end)
end

-- Depois de abrir a janela da guilda: fecha a do addon e diz onde editar.
local lastNotice
local function OnOpened()
  ns.MainFrame.Hide()
  -- O clique chega ao apertar e ao soltar: avisa uma vez só.
  if lastNotice and GetTime() - lastNotice < NOTICE_INTERVAL then return end
  lastNotice = GetTime()
  ns.Print(L["Na janela da guilda, abra Informações e clique no texto para editar."])
end

-- Cria o botão seguro (fora de combate).
local function Build(editor)
  local target = Target(editor.kind, editor.mode)
  if not target then return end
  local button = CreateFrame("Button", nil, editor.card, "SecureActionButtonTemplate")
  button:RegisterForClicks("AnyUp", "AnyDown")
  button:SetAttribute("type", "click")
  button:SetAttribute("clickbutton", target)
  button:HookScript("OnEnter", function() Highlight(editor, true) end)
  button:HookScript("OnLeave", function() Highlight(editor, false) end)
  if editor.mode == "open" then button:HookScript("PostClick", OnOpened) end
  editor.button = button
  if editor.mode == "edit" then WatchEditFrame() end
end

-- Põe o botão por baixo do texto do cartão, pela posição na tela. Retorna
-- false se o jogo recusar.
local function Place(editor)
  local button, area = editor.button, editor.holder.scroll
  local left, top, width, height = area:GetLeft(), area:GetTop(), area:GetWidth(), area:GetHeight()
  if not (left and top and width and height) then return false end
  editor.placed = left .. ":" .. top .. ":" .. width .. ":" .. height
  return pcall(function()
    button:SetParent(editor.card)
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    button:SetSize(width, height)
    button:SetFrameLevel(math.max(0, (area:GetFrameLevel() or 1) - 1))
  end)
end

-- Liga ou desliga o clique para editar num cartão (fora de combate).
local function Update(editor)
  if not editor.button then Build(editor) end
  local editable = editor.button ~= nil and GuildTextEdit.CanEdit(editor.kind, editor.mode)
  if editable then editable = Place(editor) end
  editor.editable = editable
  if editor.button then editor.button:SetShown(editable) end
  ClickThrough(editor.holder, editable)
  Highlight(editor, false)
end

-- Com o cartão na tela: o botão acompanha o texto quando a janela anda ou
-- muda de tamanho, e liga/desliga quando a permissão ou a janela da guilda
-- mudam.
local function Follow(editor, elapsed)
  editor.wait = (editor.wait or 0) - (elapsed or 0)
  if editor.wait > 0 or InCombatLockdown() then return end
  editor.wait = FOLLOW_INTERVAL
  if (GuildTextEdit.CanEdit(editor.kind, editor.mode) and true or false) ~= (editor.editable and true or false) then
    Update(editor)
    return
  end
  if not (editor.editable and editor.button) then return end
  local area = editor.holder.scroll
  local left, top, width, height = area:GetLeft(), area:GetTop(), area:GetWidth(), area:GetHeight()
  if not (left and top and width and height) then return end
  if left .. ":" .. top .. ":" .. width .. ":" .. height ~= editor.placed then Place(editor) end
end

function GuildTextEdit.Refresh()
  if InCombatLockdown() then return end
  for _, editor in ipairs(editors) do Update(editor) end
end

-- Entrando em combate: esconde e solta os botões (ainda é permitido).
local function OnCombatStart()
  for _, editor in ipairs(editors) do
    if editor.button then
      editor.button:Hide()
      editor.button:ClearAllPoints()
      editor.button:SetParent(UIParent)
    end
    editor.editable = false
    ClickThrough(editor.holder, false)
  end
end

-- Liga o clique para editar no texto de um cartão. `holder` é o quadro do
-- texto com links (com .scroll); `kind` é "motd" ou "info"; `mode` é "edit"
-- (janela da guilda) ou "open" (janela do addon).
function GuildTextEdit.Attach(card, holder, kind, mode)
  local editor = { card = card, holder = holder, kind = kind, mode = mode or "edit" }
  editors[#editors + 1] = editor
  -- Em cima de um link, o clique fica com o link.
  holder:HookScript("OnHyperlinkEnter", function() ClickThrough(holder, false) end)
  holder:HookScript("OnHyperlinkLeave", function() ClickThrough(holder, editor.editable) end)
  holder:HookScript("OnEnter", function() Highlight(editor, true) end)
  holder:HookScript("OnLeave", function() Highlight(editor, false) end)
  card:HookScript("OnUpdate", function(_, elapsed) Follow(editor, elapsed) end)
  if not events then
    events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function(_, event)
      if event == "PLAYER_REGEN_DISABLED" then OnCombatStart() else GuildTextEdit.Refresh() end
    end)
  end
  GuildTextEdit.editors = editors -- para o teste de fumaça
  GuildTextEdit.OnCombatStart = OnCombatStart
  return editor
end

ns.GuildTextEdit = GuildTextEdit
