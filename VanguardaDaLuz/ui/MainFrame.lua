-- Janela principal do addon, com abas: Início (mensagem do dia e informações
-- da guilda), Eventos (calendário), Profissões e Administração (Grão Lorde e
-- Lordes). Abre sempre no Início.
local _, ns = ...

local Theme = ns.Theme
local MainFrame = {}

local WIDTH, HEIGHT = 960, 640
local PAD = 20
local CONTENT_TOP = 116  -- abaixo do cabeçalho e da barra de abas
local FOOTER_H = 62

local TABS = {
  { key = "home", label = "Início", width = 100 },
  { key = "events", label = "Eventos", width = 100 },
  { key = "professions", label = "Profissões", width = 116 },
  { key = "admin", label = "Administração", width = 140, trusted = true },
}

local frame
local active = "home"

local function Available(tab)
  return not tab.trusted or ns.Guild.IsPlayerTrusted()
end

function MainFrame.Refresh()
  if not frame or not frame:IsShown() then return end
  if not Available(TABS[#TABS]) and active == "admin" then active = "home" end
  for _, tab in ipairs(TABS) do
    local button = frame.tabs[tab.key]
    button:SetShown(Available(tab))
    button:SetKind(tab.key == active and "primary" or "ghost")
    frame.panels[tab.key].frame:SetShown(tab.key == active)
  end
  frame.panels[active]:Refresh()
  frame.info:SetText(ns.CalendarPanel.InfoLine())
  frame.sync:SetText(Theme.Code("textMuted") .. ns.Comm.Status() .. "|r")
end

-- Abre uma aba ("home", "events", "professions" ou "admin").
function MainFrame.ShowTab(key)
  active = key
  if key == "professions" then ns.Guild.RequestRoster() end
  MainFrame.Refresh()
end

local function Build()
  frame = Theme.Window("VanguardaDaLuzMainFrame", WIDTH, HEIGHT, "Vanguarda da Luz")
  frame:SetScript("OnShow", MainFrame.Refresh)

  local subtitle = Theme.Text(frame, "small", "textMuted")
  subtitle:SetPoint("TOPLEFT", frame.heading, "BOTTOMLEFT", 0, -2)
  subtitle:SetText("Guilda Vanguarda da Luz  ·  " .. ns.Flavor.label .. "  ·  Horários de Brasília")

  -- Barra de abas
  frame.tabs = {}
  local previous
  for _, tab in ipairs(TABS) do
    local button = Theme.Button(frame, tab.label, "ghost", tab.width)
    if previous then
      button:SetPoint("LEFT", previous, "RIGHT", 6, 0)
    else
      button:SetPoint("TOPLEFT", PAD, -72)
    end
    button:SetScript("OnClick", function() MainFrame.ShowTab(tab.key) end)
    frame.tabs[tab.key] = button
    previous = button
  end

  -- Painéis
  local w, h = WIDTH - 2 * PAD, HEIGHT - CONTENT_TOP - FOOTER_H - 12
  frame.panels = {
    home = ns.HomePanel.Create(frame, w, h, function(event)
      local f = ns.Time.Fields(event.startsAt, ns.Config.BRASILIA_OFFSET)
      MainFrame.ShowTab("events")
      frame.panels.events:ShowDate(f.year, f.month, f.day, event.id)
    end),
    events = ns.CalendarPanel.Create(frame, w, "wide", h),
    professions = ns.ProfessionsPanel.Create(frame, w, h),
    admin = ns.AdminPanel.Create(frame, w, h),
  }
  for _, panel in pairs(frame.panels) do
    panel.frame:SetPoint("TOPLEFT", PAD, -CONTENT_TOP)
    panel.frame:Hide()
  end
  -- Atalhos usados pelo teste de fumaça.
  frame.calendar = frame.panels.events
  frame.dayTitle, frame.detail = frame.calendar.dayTitle, frame.calendar.detail

  -- Rodapé: informações à esquerda, Sincronizar à direita
  local footerLine = Theme.Divider(frame)
  footerLine:SetPoint("BOTTOMLEFT", 12, FOOTER_H)
  footerLine:SetPoint("BOTTOMRIGHT", -12, FOOTER_H)

  local info = Theme.Text(frame, "small", "textMuted")
  info:SetPoint("BOTTOMLEFT", PAD, 38)
  info:SetPoint("RIGHT", -150, 0)
  info:SetWordWrap(false)
  frame.info = info

  local sync = Theme.Text(frame, "small", "textMuted")
  sync:SetPoint("BOTTOMLEFT", PAD, 20)
  sync:SetPoint("RIGHT", -150, 0)
  sync:SetWordWrap(false)
  frame.sync = sync

  local syncButton = Theme.Button(frame, "Sincronizar", "outline", 110)
  syncButton:SetPoint("BOTTOMRIGHT", -PAD, 18)
  syncButton:SetScript("OnClick", function() ns.Comm.RequestLatest() end)

  ns.On("DATA_UPDATED", MainFrame.Refresh)
  ns.On("SYNC_STATUS", MainFrame.Refresh)
  ns.On("ATTENDANCE_UPDATED", MainFrame.Refresh)
  ns.On("PROFESSIONS_UPDATED", MainFrame.Refresh)
  ns.On("GUILD_UPDATED", MainFrame.Refresh)
end

function MainFrame.Hide()
  if frame then frame:Hide() end
end

-- Abre no Início; se já estiver aberta, fecha.
function MainFrame.Toggle()
  if not ns.Guild.IsMember() then
    MainFrame.Hide()
    ns.WelcomeFrame.Toggle()
    return
  end
  if not frame then Build() end
  if frame:IsShown() then
    frame:Hide()
  else
    active = "home"
    frame:Show()
  end
end

ns.MainFrame = MainFrame
