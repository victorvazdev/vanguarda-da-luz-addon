-- Painel de administração (Grão Lorde e Lordes): importar a string do site,
-- exportar as presenças e enviar o alerta de raide, com o estado da
-- sincronização. Usado na aba Administração da janela da guilda.
local _, ns = ...

local Theme = ns.Theme
local AdminPanel = {}

local CARD_GAP = 12

local Panel = {}
Panel.__index = Panel

local CARDS = {
  {
    title = "Importar eventos",
    text = "Cole a string gerada no site em \"Exportar para o addon\". "
      .. "Os eventos vão para o calendário e são enviados à guilda.",
    button = "Importar",
    action = function() ns.ImportDialog.Show() end,
  },
  {
    title = "Exportar presenças",
    text = "Gera a string com as confirmações e os cancelamentos do jogo, para colar no site.",
    button = "Gerar string",
    action = function() ns.PresenceExport.Show() end,
  },
  {
    title = "Alerta de raide",
    text = "Mostra um aviso no centro da tela dos membros online e publica no chat da guilda.",
    button = "Enviar alerta",
    action = function() ns.AlertDialog.Show() end,
  },
}

function Panel:Refresh()
  local trusted = ns.Guild.IsPlayerTrusted()
  self.info:SetText(ns.CalendarPanel.InfoLine())
  self.sync:SetText(ns.Comm.Status())
  for _, card in ipairs(self.cards) do card.button:SetEnabled(trusted) end
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
  label:SetText("SINCRONIZAÇÃO")
  local syncButton = Theme.Button(status, "Sincronizar", "outline", 110)
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

  -- Ações, lado a lado
  local cardW = math.floor((width - 2 * CARD_GAP) / #CARDS)
  for i, spec in ipairs(CARDS) do
    local card = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    card:SetPoint("TOPLEFT", status, "BOTTOMLEFT", (i - 1) * (cardW + CARD_GAP), -CARD_GAP)
    card:SetSize(cardW, height - 76 - CARD_GAP - 26)
    Theme.Backdrop(card, "surface", "border")
    local title = Theme.Text(card, "heading", "heading")
    title:SetPoint("TOPLEFT", 14, -14)
    title:SetPoint("RIGHT", -14, 0)
    title:SetText(spec.title)
    local text = Theme.Text(card, "body", "textMuted")
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    text:SetPoint("RIGHT", -14, 0)
    text:SetSpacing(2)
    text:SetText(spec.text)
    card.button = Theme.Button(card, spec.button, i == 1 and "primary" or "outline", cardW - 28)
    card.button:SetPoint("BOTTOMLEFT", 14, 14)
    card.button:SetScript("OnClick", spec.action)
    self.cards[i] = card
  end

  local denied = Theme.Text(frame, "small", "cancel")
  denied:SetPoint("BOTTOMLEFT", 0, 4)
  denied:SetText("Somente o Grão Lorde e os Lordes podem usar estas ações.")
  self.denied = denied

  return self
end

ns.AdminPanel = AdminPanel
