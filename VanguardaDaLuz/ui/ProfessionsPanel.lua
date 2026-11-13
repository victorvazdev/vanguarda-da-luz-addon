-- Painel das profissões: membros da guilda com as profissões primárias e o
-- nível, filtro por profissão, só online e botão de sussurrar. Usado na janela
-- Profissões e na aba Profissões da janela da guilda.
local _, ns = ...

local L = ns.L

local Theme, Text = ns.Theme, ns.Text
local ProfessionsPanel = {}

local ROW_H = 30
local TOOLBAR_H = 40   -- filtros
local HEADER_H = 26    -- títulos das colunas
local BUTTON_W = 90

local Panel = {}
Panel.__index = Panel

function Panel:ProfessionText(p)
  if not p then return "" end
  local level
  if p.level then
    level = Theme.Code("gold") .. p.level .. "/" .. p.max .. "|r"
  else
    level = Theme.Code("textMuted") .. "—|r"
  end
  local name = Text.Escape(p.name)
  if self.options.profession == p.name then name = Theme.Code("goldLight") .. name .. "|r" end
  return name .. "  " .. level
end

function Panel:CreateRow(i)
  local row = CreateFrame("Frame", nil, self.list, "BackdropTemplate")
  row:SetSize(self.listW, ROW_H)
  row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
  row.dot = row:CreateTexture(nil, "OVERLAY")
  row.dot:SetSize(8, 8)
  row.dot:SetPoint("LEFT", 10, 0)
  for key, column in pairs(self.columns) do
    local fs = Theme.Text(row, "body")
    fs:SetPoint("LEFT", column[1], 0)
    fs:SetWidth(column[2])
    fs:SetWordWrap(false)
    row[key] = fs
  end
  row.whisper = Theme.Button(row, L["Sussurrar"], "outline", BUTTON_W)
  row.whisper:SetHeight(24)
  row.whisper:SetPoint("RIGHT", -6, 0)
  row.whisper:SetScript("OnClick", function(b)
    if b.target then ns.Flavor.Whisper(b.target) end
  end)
  self.rows[i] = row
  return row
end

function Panel:ShowRow(i, data)
  local row = self.rows[i] or self:CreateRow(i)
  Theme.Backdrop(row, i % 2 == 1 and "surface" or "bg", i % 2 == 1 and "surface" or "bg")
  row.dot:SetColorTexture(unpack(Theme.PresenceColor(data.online, data.status)))
  local isMe = ns.Guild.IsPlayer(data.name)
  local name = Text.Escape(data.name)
  if isMe then name = name .. Theme.Code("textMuted") .. L["  (você)"] .. "|r" end
  row.name:SetText(name)
  row.name:SetTextColor(unpack(Theme.colors[data.online and "text" or "textMuted"]))
  row.first:SetText(self:ProfessionText(data.professions[1]))
  row.second:SetText(self:ProfessionText(data.professions[2]))
  if #data.professions == 0 then
    row.first:SetText(Theme.Code("textMuted") .. L["Sem profissão"] .. "|r")
  end
  row.whisper.target = data.name
  row.whisper:SetShown(not isMe)
  row.whisper:SetEnabled(data.online)
  row:Show()
end

---------------------------------------------------------------------------
-- Filtro de profissão
---------------------------------------------------------------------------

function Panel:FilterLabel()
  return string.format(L["Profissão: %s"],
    self.options.profession and Text.Escape(self.options.profession) or L["Todas"])
end

function Panel:CloseMenu()
  self.menu:Hide()
end

function Panel:OpenMenu()
  local menu = self.menu
  local choices = { false }
  for _, name in ipairs(self.names or {}) do choices[#choices + 1] = name end
  for i, choice in ipairs(choices) do
    local button = self.menuButtons[i]
    if not button then
      button = Theme.Button(menu, "", "ghost", 196)
      button:SetHeight(24)
      button:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 26)
      button.label:ClearAllPoints()
      button.label:SetPoint("LEFT", 10, 0)
      button:SetScript("OnClick", function(b)
        self.options.profession = b.choice or nil
        self:CloseMenu()
        self:Refresh()
      end)
      self.menuButtons[i] = button
    end
    button.choice = choice
    button:SetText(choice and Text.Escape(choice) or L["Todas"])
    button:Show()
  end
  for i = #choices + 1, #self.menuButtons do self.menuButtons[i]:Hide() end
  menu:SetHeight(12 + #choices * 26 - 2)
  menu:Show()
end

---------------------------------------------------------------------------
-- Atualização
---------------------------------------------------------------------------

function Panel:Refresh()
  local options = self.options
  local all = ns.GuildProfessions.Rows()
  local names = all and ns.Professions.Names(all) or {}
  local known = false
  for _, name in ipairs(names) do known = known or name == options.profession end
  if not known then options.profession = nil end
  self.filter:SetText(self:FilterLabel())
  self.online:SetText(options.onlineOnly and L["Mostrar: só online"] or L["Mostrar: todos"])
  self.names = names

  local list = all and ns.Professions.Filter(all, options) or {}
  for i, data in ipairs(list) do self:ShowRow(i, data) end
  for i = #list + 1, #self.rows do self.rows[i]:Hide() end
  self.list:SetHeight(math.max(1, #list * ROW_H))

  if not all then
    self.empty:SetText(L["A lista da guilda ainda não carregou. Tente de novo em alguns segundos."])
    self.count:SetText("")
    ns.Guild.RequestRoster()
  else
    self.empty:SetText(#list == 0 and L["Nenhum membro encontrado com esse filtro."] or "")
    local online = 0
    for _, data in ipairs(all) do if data.online then online = online + 1 end end
    self.count:SetText(string.format(L["%d membro(s)"], #all) .. "  ·  " .. string.format(L["%d online"], online))
  end
end

---------------------------------------------------------------------------
-- Construção
---------------------------------------------------------------------------

-- Cria o painel dentro de `parent`, com `width` x `height`. Quem usa o painel
-- chama panel:Refresh() quando ele está visível.
function ProfessionsPanel.Create(parent, width, height)
  -- Por padrão, só quem está online (quem dá para sussurrar agora).
  local self = setmetatable({ options = { onlineOnly = true }, rows = {}, menuButtons = {} }, Panel)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetSize(width, height)
  frame:SetScript("OnHide", function() self:CloseMenu() end)
  self.frame = frame

  -- Colunas: nome, profissão 1, profissão 2 e o botão.
  self.listW = width - 24 -- espaço da barra de rolagem
  local available = self.listW - 26 - BUTTON_W - 12
  local nameW = math.floor(available * 0.36)
  local professionW = math.floor((available - nameW - 16) / 2)
  self.columns = {
    name = { 26, nameW },
    first = { 26 + nameW + 8, professionW },
    second = { 26 + nameW + 16 + professionW, professionW },
  }

  -- Barra de filtros
  local filter = Theme.Button(frame, self:FilterLabel(), "outline", 210)
  filter:SetPoint("TOPLEFT")
  filter:SetScript("OnClick", function()
    if self.menu:IsShown() then self:CloseMenu() else self:OpenMenu() end
  end)
  self.filter = filter

  local online = Theme.Button(frame, L["Mostrar: só online"], "outline", 150)
  online:SetPoint("LEFT", filter, "RIGHT", 8, 0)
  online:SetScript("OnClick", function()
    self.options.onlineOnly = not self.options.onlineOnly
    self:Refresh()
  end)
  self.online = online

  local count = Theme.Text(frame, "small", "textMuted")
  count:SetPoint("RIGHT", frame, "TOPRIGHT", 0, -14)
  count:SetJustifyH("RIGHT")
  self.count = count

  -- Cabeçalho da lista
  for key, label in pairs({ name = L["MEMBRO"], first = L["PROFISSÃO 1"], second = L["PROFISSÃO 2"] }) do
    local header = Theme.Text(frame, "smallStrong", "goldDeep")
    header:SetPoint("TOPLEFT", self.columns[key][1], -TOOLBAR_H - 6)
    header:SetText(label)
  end
  local line = Theme.Divider(frame)
  line:SetPoint("TOPLEFT", 0, -TOOLBAR_H - HEADER_H)
  line:SetPoint("TOPRIGHT", 0, -TOOLBAR_H - HEADER_H)

  -- Lista com rolagem
  local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, -TOOLBAR_H - HEADER_H - 6)
  scroll:SetPoint("BOTTOMRIGHT", -24, 0)
  local list = CreateFrame("Frame", nil, scroll)
  list:SetSize(self.listW, 1)
  scroll:SetScrollChild(list)
  self.list = list

  local empty = Theme.Text(frame, "body", "textMuted")
  empty:SetPoint("TOP", scroll, "TOP", 12, -24)
  empty:SetJustifyH("CENTER")
  self.empty = empty

  -- Menu do filtro, por cima da lista
  local menu = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  menu:SetPoint("TOPLEFT", filter, "BOTTOMLEFT", 0, -4)
  menu:SetWidth(208)
  menu:SetFrameStrata("FULLSCREEN_DIALOG")
  Theme.Backdrop(menu, "surfaceRaised", "goldDeep")
  menu:Hide()
  self.menu = menu

  return self
end

ns.ProfessionsPanel = ProfessionsPanel
