-- Painel Bate-papo da janela do addon: mensagens da guilda (e de oficiais,
-- para o Grão Lorde e os Lordes) com nome na cor da classe, main de quem é alt,
-- menu no nome (sussurrar, convidar), links para copiar e links do jogo (item,
-- missão) que abrem o tooltip; caixa para escrever.
local _, ns = ...

local L = ns.L

local Theme, Chat = ns.Theme, ns.Chat
local ChatPanel = {}

local PAD = 12
local TOP_H = 36    -- seletor de canal e dica
local INPUT_H = 32
local MAX_LINES = 500

local Panel = {}
Panel.__index = Panel

local inputs = {} -- caixas de escrever dos painéis criados

-- Shift+clique num item ou missão com a caixa do addon em foco: o link entra
-- nela, como na caixa do chat da Blizzard.
local function InsertLink(link)
  if type(link) ~= "string" then return end
  for _, input in ipairs(inputs) do
    if input:HasFocus() then
      input:Insert(link)
      return
    end
  end
end

local function Roster(name)
  for _, entry in ipairs(ns.Flavor.GuildRoster()) do
    if entry.name == name then return entry end
  end
  return nil
end

-- Mostra o link na caixa de cópia, já selecionado.
function Panel:ShowCopy(url)
  local copy = self.copy
  copy.url = url
  copy.edit:SetText(url)
  copy:Show()
  copy.edit:SetFocus()
  copy.edit:HighlightText()
end

function Panel:OnLink(link, button, text)
  local kind, value = Chat.ParseLink(link)
  if not kind then
    -- Link do jogo (item, missão...): abre o tooltip, como no chat da Blizzard.
    ns.Flavor.OpenGameLink(link, text, button, self.messages)
  elseif kind == "url" then
    self:ShowCopy(value)
  elseif kind == "player" and (button == "RightButton" or button == "LeftButton") then
    local member = Roster(value)
    ns.MembersPanel.OpenMenu({ name = value, online = member and member.online or false })
  end
end

local function LinkTooltip(owner, link)
  local kind, value = Chat.ParseLink(link)
  if not kind then
    -- Link do jogo (item, missão...): tooltip junto do mouse, sem clicar.
    ns.Flavor.ShowLinkTooltip(owner, link)
    return
  end
  GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
  if kind == "url" then
    GameTooltip:SetText(L["Clique para copiar o link"])
  else
    GameTooltip:SetText(value)
    local detail = ns.Members.Detail(value, ns.GuildMembers.Get(value))
    if detail then GameTooltip:AddLine(detail, 0.95, 0.79, 0.30) end
    GameTooltip:AddLine(L["Clique: sussurrar ou convidar"], 0.7, 0.7, 0.7)
  end
  GameTooltip:Show()
end

-- Canal mostrado: o de oficiais só enquanto estiver disponível.
function Panel:Channel()
  if self.channel == "officer" and not self.channels.officer then self.channel = "guild" end
  return self.channel
end

function Panel:Refresh()
  self.channels = ns.GuildChat.Channels()
  local channel = self:Channel()
  local both = self.channels.officer
  self.guildTab:SetShown(both)
  self.officerTab:SetShown(both)
  self.guildTab:SetKind(channel == "guild" and "primary" or "ghost")
  self.officerTab:SetKind(channel == "officer" and "primary" or "ghost")
  self.placeholder:SetText(channel == "officer" and L["Escreva para os oficiais…"] or L["Escreva para a guilda…"])

  local entries = ns.GuildChat.Entries(channel)
  local last = entries[#entries]
  local signature = channel .. ":" .. #entries .. ":" .. (last and last.id or "")
  if signature == self.signature then return end
  self.signature = signature
  local messages = self.messages
  messages:Clear()
  if #entries == 0 then
    messages:AddMessage(Theme.Code("textMuted") .. L["Nenhuma mensagem ainda."] .. "|r")
    return
  end
  local muted, linkColor, alt = Theme.Code("textMuted"), Theme.Code("azure"), L["alt de %s"]
  for _, entry in ipairs(entries) do
    -- Texto secreto (encontros) pode recusar alguma operação: a linha é pulada.
    pcall(function() messages:AddMessage(Chat.Line(entry, muted, linkColor, alt)) end)
  end
  messages:ScrollToBottom()
end

function Panel:SetChannel(channel)
  self.channel = channel
  self:Refresh()
end

function Panel:Send()
  local ok, err = ns.GuildChat.Send(self:Channel(), self.input:GetText())
  if ok then
    self.input:SetText("")
  elseif err then
    ns.Print(err)
  end
end

-- Cria o painel dentro de `parent`, com `width` x `height`. `compact` (janela
-- da guilda) esconde a dica do topo, que não cabe ao lado dos canais.
function ChatPanel.Create(parent, width, height, compact)
  local self = setmetatable({ channel = "guild", channels = {} }, Panel)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetSize(width, height)
  self.frame = frame

  -- Canal
  self.guildTab = Theme.Button(frame, L["Guilda"], "ghost", 100)
  self.guildTab:SetPoint("TOPLEFT")
  self.guildTab:SetScript("OnClick", function() self:SetChannel("guild") end)
  self.officerTab = Theme.Button(frame, L["Oficiais"], "ghost", 100)
  self.officerTab:SetPoint("LEFT", self.guildTab, "RIGHT", 6, 0)
  self.officerTab:SetScript("OnClick", function() self:SetChannel("officer") end)
  local hint = Theme.Text(frame, "small", "textMuted")
  hint:SetPoint("TOPRIGHT", 0, -8)
  hint:SetText(L["Clique num nome: sussurrar ou convidar · clique num link para copiar"])
  hint:SetShown(not compact)

  -- Mensagens
  local card = CreateFrame("Frame", nil, frame)
  Theme.Backdrop(card, "surface", "border")
  card:SetPoint("TOPLEFT", 0, -TOP_H)
  card:SetPoint("BOTTOMRIGHT", 0, INPUT_H + 10)
  local messages = CreateFrame("ScrollingMessageFrame", nil, card)
  messages:SetPoint("TOPLEFT", PAD, -PAD)
  messages:SetPoint("BOTTOMRIGHT", -PAD, PAD)
  messages:SetFontObject(Theme.Font("body"))
  messages:SetTextColor(unpack(Theme.colors.text))
  messages:SetJustifyH("LEFT")
  messages:SetFading(false)
  messages:SetMaxLines(MAX_LINES)
  if messages.SetSpacing then messages:SetSpacing(3) end
  if messages.SetHyperlinksEnabled then messages:SetHyperlinksEnabled(true) end
  messages:EnableMouseWheel(true)
  messages:SetScript("OnMouseWheel", function(m, delta)
    if delta > 0 then m:ScrollUp() else m:ScrollDown() end
  end)
  messages:SetScript("OnHyperlinkClick", function(_, link, text, button) self:OnLink(link, button, text) end)
  messages:SetScript("OnHyperlinkEnter", LinkTooltip)
  messages:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
  self.messages = messages

  -- Caixa de cópia por cima das mensagens, no pé do cartão. Fecha ao perder o
  -- foco (clique fora), com Esc ou Enter.
  local copy = CreateFrame("Frame", nil, card)
  copy:SetPoint("BOTTOMLEFT", 8, 8)
  copy:SetPoint("BOTTOMRIGHT", -8, 8)
  copy:SetHeight(70)
  copy:SetFrameLevel((card:GetFrameLevel() or 0) + 20)
  copy:EnableMouse(true)
  Theme.Backdrop(copy, "surfaceRaised", "gold")
  local copyLabel = Theme.Text(copy, "small", "textMuted")
  copyLabel:SetPoint("TOPLEFT", 10, -10)
  copyLabel:SetText(L["Link selecionado: pressione Ctrl+C para copiar"])
  local copyBox = CreateFrame("Frame", nil, copy)
  copyBox:SetPoint("TOPLEFT", copyLabel, "BOTTOMLEFT", 0, -4)
  copyBox:SetPoint("RIGHT", -10, 0)
  copyBox:SetHeight(30)
  Theme.Backdrop(copyBox, "bgDeep", "borderField")
  local copyEdit = CreateFrame("EditBox", nil, copyBox)
  copyEdit:SetPoint("TOPLEFT", 8, -4)
  copyEdit:SetPoint("BOTTOMRIGHT", -8, 4)
  copyEdit:SetAutoFocus(false)
  copyEdit:SetFontObject(Theme.Font("body"))
  copyEdit:SetTextColor(unpack(Theme.colors.text))
  -- Somente leitura: qualquer edição volta ao link selecionado.
  copyEdit:SetScript("OnTextChanged", function(e, userInput)
    if userInput then
      e:SetText(copy.url or "")
      e:HighlightText()
    end
  end)
  copyEdit:SetScript("OnEditFocusLost", function() copy:Hide() end)
  copyEdit:SetScript("OnEscapePressed", function(e) e:ClearFocus() end)
  copyEdit:SetScript("OnEnterPressed", function(e) e:ClearFocus() end)
  copy.edit = copyEdit
  copy:Hide()
  self.copy = copy

  -- Escrever
  local send = Theme.Button(frame, L["Enviar"], "primary", 100)
  send:SetPoint("BOTTOMRIGHT")
  send:SetScript("OnClick", function() self:Send() end)
  local box = CreateFrame("Frame", nil, frame)
  box:SetPoint("BOTTOMLEFT")
  box:SetPoint("RIGHT", send, "LEFT", -8, 0)
  box:SetHeight(INPUT_H)
  Theme.Backdrop(box, "bgDeep", "borderField")
  local input = CreateFrame("EditBox", nil, box)
  input:SetPoint("TOPLEFT", 10, -4)
  input:SetPoint("BOTTOMRIGHT", -10, 4)
  input:SetAutoFocus(false)
  input:SetMaxLetters(Chat.MAX_LENGTH)
  input:SetFontObject(Theme.Font("body"))
  input:SetTextColor(unpack(Theme.colors.text))
  local placeholder = Theme.Text(box, "body", "textMuted")
  placeholder:SetPoint("LEFT", 10, 0)
  self.placeholder = placeholder
  local function UpdatePlaceholder()
    placeholder:SetShown(input:GetText() == "" and not input:HasFocus())
  end
  input:SetScript("OnEnterPressed", function() self:Send() end)
  input:SetScript("OnEscapePressed", function(e) e:ClearFocus() end)
  input:SetScript("OnEditFocusGained", UpdatePlaceholder)
  input:SetScript("OnEditFocusLost", UpdatePlaceholder)
  input:SetScript("OnTextChanged", UpdatePlaceholder)
  box:EnableMouse(true)
  box:SetScript("OnMouseDown", function() input:SetFocus() end)
  self.input = input
  UpdatePlaceholder()
  if #inputs == 0 then ns.Flavor.OnChatLinkInsert(InsertLink) end
  inputs[#inputs + 1] = input

  -- Ao voltar para a aba, relê tudo (a posição de rolagem volta ao fim).
  frame:SetScript("OnShow", function() self.signature = nil end)

  return self
end

ns.ChatPanel = ChatPanel
