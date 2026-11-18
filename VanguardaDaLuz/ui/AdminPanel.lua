-- Painel de administração (Grão Lorde e Lordes): importar a string do site,
-- backup do addon, exportar as presenças, enviar o alerta de raide e a
-- mensagem de recrutamento, com o estado da sincronização. Usado na aba Administração da janela da guilda.
local _, ns = ...

local L = ns.L

local Theme = ns.Theme
local AdminPanel = {}

local CARD_GAP = 12

local Panel = {}
Panel.__index = Panel

-- Uma linha por ação: título e texto à esquerda, botões à direita.
local CARDS = {
  {
    title = L["Importar eventos"],
    text = L["Cole a string de \"Exportar para o addon\" do site. Os eventos vão para o calendário e para a guilda."],
    buttons = { { label = L["Importar"], kind = "primary", action = function() ns.ImportDialog.Show() end } },
  },
  {
    title = L["Backup do addon"],
    text = L["Eventos criados no jogo, presenças, profissões, item level e tempo junto, para guardar no site "
      .. "e restaurar depois."],
    buttons = {
      { label = L["Gerar backup"], kind = "outline", action = function() ns.BackupDialog.ShowExport() end },
      { label = L["Restaurar"], kind = "ghost", action = function() ns.BackupDialog.ShowRestore() end },
    },
  },
  {
    title = L["Exportar presenças"],
    text = L["Gera a string com as confirmações e os cancelamentos do jogo, para colar no site."],
    buttons = { { label = L["Gerar string"], kind = "outline", action = function() ns.PresenceExport.Show() end } },
  },
  {
    title = L["Alerta de raide"],
    text = L["Mostra um aviso no centro da tela dos membros online e publica no chat da guilda."],
    buttons = { { label = L["Enviar alerta"], kind = "outline", action = function() ns.AlertDialog.Show() end } },
  },
  {
    key = "recruit",
    title = L["Mensagem de recrutamento"],
    text = "", -- o texto salvo, preenchido em Refresh
    buttons = {
      { label = L["Editar texto"], kind = "outline", action = function() ns.RecruitDialog.Show() end },
      { label = L["Enviar no canal"], kind = "ghost", action = function() ns.RecruitDialog.SendNow() end },
    },
  },
}

-- Linha do cartão da mensagem de recrutamento: o texto e o canal.
local function RecruitLine()
  local record = ns.GuildRecruit.Get()
  if not record then
    return L["Texto do Grão Lorde e dos Lordes para enviar com um clique num canal do chat, como o Geral."]
  end
  local channel = ns.GuildRecruit.ChannelLabel(ns.GuildRecruit.Channel())
  return "\"" .. ns.Text.Escape(record.text) .. "\" · " .. string.format(L["Canal: %s"], channel)
end

local BUTTON_W = 120

function Panel:Refresh()
  local trusted = ns.Guild.IsPlayerTrusted()
  self.info:SetText(ns.CalendarPanel.InfoLine())
  self.sync:SetText(ns.Comm.Status())
  for _, card in ipairs(self.cards) do
    for _, button in ipairs(card.buttons) do button:SetEnabled(trusted) end
  end
  self.recruit.text:SetText(RecruitLine())
  self.recruit.send:SetEnabled(trusted and ns.GuildRecruit.Get() ~= nil)
  self.denied:SetShown(not trusted)
end

-- Cria o painel dentro de `parent`, com `width` x `height`.
function AdminPanel.Create(parent, width, height)
  local self = setmetatable({ cards = {} }, Panel)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetSize(width, height)
  self.frame = frame

  -- Sincronização
  local status = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  status:SetPoint("TOPLEFT")
  status:SetPoint("TOPRIGHT")
  status:SetHeight(76)
  Theme.Backdrop(status, "surface", "border")

  local label = Theme.Text(status, "smallStrong", "goldDeep")
  label:SetPoint("TOPLEFT", 14, -12)
  label:SetText(L["SINCRONIZAÇÃO"])
  local syncButton = Theme.Button(status, L["Sincronizar"], "outline", 110)
  syncButton:SetPoint("RIGHT", -14, 0)
  syncButton:SetScript("OnClick", function() ns.Comm.RequestLatest() end)
  local info = Theme.Text(status, "small")
  info:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
  info:SetPoint("RIGHT", syncButton, "LEFT", -12, 0)
  self.info = info
  local sync = Theme.Text(status, "small", "textMuted")
  sync:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -4)
  sync:SetPoint("RIGHT", syncButton, "LEFT", -12, 0)
  sync:SetWordWrap(false)
  self.sync = sync

  -- Ações, uma por linha
  local cardH = math.floor((height - 76 - CARD_GAP - 26 - (#CARDS - 1) * 8) / #CARDS)
  local previous = status
  for i, spec in ipairs(CARDS) do
    local card = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    card:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, i == 1 and -CARD_GAP or -8)
    card:SetPoint("RIGHT", frame, "RIGHT")
    card:SetHeight(cardH)
    Theme.Backdrop(card, "surface", "border")
    card.buttons = {}
    local right = nil
    for k = #spec.buttons, 1, -1 do
      local b = spec.buttons[k]
      local button = Theme.Button(card, b.label, b.kind, BUTTON_W)
      if right then
        button:SetPoint("RIGHT", right, "LEFT", -8, 0)
      else
        button:SetPoint("RIGHT", -12, 0)
      end
      button:SetScript("OnClick", b.action)
      card.buttons[#card.buttons + 1] = button
      if spec.key == "recruit" and b.label == L["Enviar no canal"] then card.send = button end
      right = button
    end
    local title = Theme.Text(card, "heading", "heading")
    title:SetPoint("TOPLEFT", 14, -(cardH > 70 and 14 or 8))
    title:SetPoint("RIGHT", right, "LEFT", -12, 0)
    title:SetWordWrap(false)
    title:SetText(spec.title)
    local text = Theme.Text(card, "small", "textMuted")
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    text:SetPoint("RIGHT", right, "LEFT", -12, 0)
    text:SetText(spec.text)
    card.text = text
    if spec.key == "recruit" then
      text:SetWordWrap(false) -- uma linha; o jogo corta com "..."
      self.recruit = card
    end
    self.cards[i] = card
    previous = card
  end

  local denied = Theme.Text(frame, "small", "cancel")
  denied:SetPoint("BOTTOMLEFT", 0, 4)
  denied:SetText(L["Somente o Grão Lorde e os Lordes podem usar estas ações."])
  self.denied = denied

  return self
end

ns.AdminPanel = AdminPanel
