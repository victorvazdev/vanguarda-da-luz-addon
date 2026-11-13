-- Painel Membros: lista da guilda com nome (na cor da classe), nível, item
-- level, main/alt, zona e posto. Clicar no título de uma coluna ordena por ela;
-- o clique direito num membro abre o menu (sussurrar e convidar para o grupo).
-- Usado na janela do addon e por cima da aba Membros da janela da guilda.
local _, ns = ...

local L = ns.L

local Theme, Text, Roster = ns.Theme, ns.Text, ns.Roster
local MembersPanel = {}

local ROW_H = 30
local TOOLBAR_H = 40
local HEADER_H = 26
local GAP = 8

local menu -- menu do clique direito, um só para todos os painéis

-- Colunas: chave, título e peso na largura disponível.
local COLUMNS = {
  { key = "name", label = L["MEMBRO"], weight = 0.21 },
  { key = "level", label = L["NV"], weight = 0.06 },
  { key = "ilvl", label = L["ILVL"], weight = 0.07 },
  { key = "main", label = L["MAIN/ALT"], weight = 0.19 },
  { key = "zone", label = L["ZONA"], weight = 0.19 },
  { key = "rank", label = L["POSTO"], weight = 0.14 },
  { key = "time", label = L["TEMPO"], weight = 0.14 },
}

local Panel = {}
Panel.__index = Panel

local function Muted(text)
  return Theme.Code("textMuted") .. text .. "|r"
end

-- Menu do clique direito num membro.
function MembersPanel.OpenMenu(data)
  menu = menu or Theme.PopupMenu("VanguardaDaLuzMemberMenu", 200)
  local offline = not data.online
  local isMe = ns.Guild.IsPlayer(data.name)
  menu:Open(data.name, {
    { label = L["Sussurrar"], disabled = offline or isMe, action = function() ns.Flavor.Whisper(data.name) end },
    { label = L["Convidar para o grupo"], disabled = offline or isMe,
      action = function() ns.Flavor.InviteToGroup(data.name) end },
  })
  return menu
end

function Panel:CreateRow(i)
  local row = CreateFrame("Frame", nil, self.list, "BackdropTemplate")
  row:SetSize(self.listW, ROW_H)
  row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
  row.dot = row:CreateTexture(nil, "OVERLAY")
  row.dot:SetSize(8, 8)
  row.dot:SetPoint("LEFT", 10, 0)
  local hover = row:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints()
  hover:SetColorTexture(1, 1, 1, 0.05)
  row:EnableMouse(true)
  row:SetScript("OnMouseUp", function(r, button)
    if button == "RightButton" and r.data then MembersPanel.OpenMenu(r.data) end
  end)
  for _, column in ipairs(self.cols) do
    local x, w = unpack(self.columns[column.key])
    local fs = Theme.Text(row, "body")
    fs:SetPoint("LEFT", x, 0)
    fs:SetWidth(w)
    fs:SetWordWrap(false)
    row[column.key] = fs
  end
  self.rows[i] = row
  return row
end

function Panel:ShowRow(i, data)
  local row = self.rows[i] or self:CreateRow(i)
  Theme.Backdrop(row, i % 2 == 1 and "surface" or "bg", i % 2 == 1 and "surface" or "bg")
  row.dot:SetColorTexture(unpack(Theme.PresenceColor(data.online, data.status)))
  local isMe = ns.Guild.IsPlayer(data.name)
  local name = Text.Escape(data.name)
  -- Cor da classe para quem está online; cinza para offline, como na Blizzard.
  local color = data.online and ns.Flavor.ClassColorCode(data.classFile)
  name = color and (color .. name .. "|r") or (data.online and name or Muted(name))
  if isMe then name = name .. Muted(L["  (você)"]) end
  row.name:SetText(name)

  local function Cell(fs, value)
    fs:SetText(data.online and value or Muted(value))
  end
  Cell(row.level, tostring(data.level or ""))
  Cell(row.ilvl, data.ilvl and tostring(data.ilvl) or "—")
  local main = Roster.MainText(data)
  Cell(row.main, main and Text.Escape(main) or "—")
  Cell(row.zone, data.online and Text.Escape(data.zone or "") or L["Offline"])
  Cell(row.rank, Text.Escape(data.rank or ""))
  if self.columns.time then Cell(row.time, data.together and ns.Together.Format(data.together) or "—") end

  row.data = data
  row:Show()
end

function Panel:Refresh()
  local options = self.options
  self.online:SetText(options.onlineOnly and L["Mostrar: só online"] or L["Mostrar: todos"])
  for _, column in ipairs(self.cols) do
    local header = self.headers[column.key]
    local active = options.sort == column.key
    header.label:SetTextColor(unpack(Theme.colors[active and "goldLight" or "goldDeep"]))
    header.arrow:SetShown(active)
    if active then
      header.arrow:SetTexture(options.descending and "Interface\\Buttons\\Arrow-Down-Up"
        or "Interface\\Buttons\\Arrow-Up-Up")
    end
  end

  local all = Roster.BuildRows(ns.Flavor.GuildRoster(), ns.db.members, ns.GuildTogether.Totals())
  local list = Roster.Sort(Roster.Filter(all, options), options.sort, options.descending)
  for i, data in ipairs(list) do self:ShowRow(i, data) end
  for i = #list + 1, #self.rows do self.rows[i]:Hide() end
  self.list:SetHeight(math.max(1, #list * ROW_H))

  if #all == 0 then
    self.empty:SetText(L["A lista da guilda ainda não carregou. Tente de novo em alguns segundos."])
    self.count:SetText("")
    ns.Guild.RequestRoster()
  else
    self.empty:SetText(#list == 0 and L["Nenhum membro online."] or "")
    local online = 0
    for _, data in ipairs(all) do if data.online then online = online + 1 end end
    self.count:SetText(string.format(L["%d membro(s)"], #all) .. "  ·  " .. string.format(L["%d online"], online))
  end
end

-- Clique no título: ordena pela coluna; de novo, inverte; uma terceira vez
-- volta à ordem padrão (online, posto, nível decrescente e nome).
function Panel:SortBy(key)
  local options = self.options
  if options.sort ~= key then
    options.sort, options.descending = key, false
  elseif not options.descending then
    options.descending = true
  else
    options.sort, options.descending = nil, false
  end
  self:Refresh()
end

-- Cria o painel dentro de `parent`, com `width` x `height`. Quem usa o painel
-- chama panel:Refresh() quando ele está visível.
-- `hidden` = { [coluna] = true }: colunas que não aparecem (a janela da guilda
-- esconde o tempo); as outras dividem a largura.
function MembersPanel.Create(parent, width, height, hidden)
  local self = setmetatable({ options = { onlineOnly = false }, rows = {}, headers = {}, cols = {} }, Panel)
  for _, column in ipairs(COLUMNS) do
    if not (hidden and hidden[column.key]) then self.cols[#self.cols + 1] = column end
  end
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetSize(width, height)
  self.frame = frame

  self.listW = width - 24 -- espaço da barra de rolagem
  local available = self.listW - 26 - 12 - GAP * (#self.cols - 1)
  local weights = 0
  for _, column in ipairs(self.cols) do weights = weights + column.weight end
  self.columns = {}
  local x = 26
  for _, column in ipairs(self.cols) do
    local w = math.floor(available * column.weight / weights)
    self.columns[column.key] = { x, w }
    x = x + w + GAP
  end

  -- Barra
  local online = Theme.Button(frame, L["Mostrar: todos"], "outline", 150)
  online:SetPoint("TOPLEFT")
  online:SetScript("OnClick", function()
    self.options.onlineOnly = not self.options.onlineOnly
    self:Refresh()
  end)
  self.online = online

  local hint = Theme.Text(frame, "small", "textMuted")
  hint:SetPoint("LEFT", online, "RIGHT", 12, 0)
  hint:SetWordWrap(false)
  hint:SetText(L["Clique direito num membro: sussurrar ou convidar"])
  self.hint = hint

  local count = Theme.Text(frame, "small", "textMuted")
  count:SetPoint("RIGHT", frame, "TOPRIGHT", 0, -14)
  count:SetJustifyH("RIGHT")
  self.count = count
  hint:SetPoint("RIGHT", count, "LEFT", -12, 0)

  -- Títulos das colunas (clicáveis)
  for _, column in ipairs(self.cols) do
    local colX, colW = unpack(self.columns[column.key])
    local header = CreateFrame("Button", nil, frame)
    header:SetSize(colW, HEADER_H - 4)
    header:SetPoint("TOPLEFT", colX, -TOOLBAR_H - 2)
    local label = Theme.Text(header, "smallStrong", "goldDeep")
    label:SetPoint("LEFT")
    label:SetWordWrap(false)
    header:SetFontString(label)
    header:SetText(column.label)
    header.label = label
    local arrow = header:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(12, 12)
    arrow:SetPoint("LEFT", label, "RIGHT", 2, 0)
    arrow:Hide()
    header.arrow = arrow
    header:SetScript("OnClick", function() self:SortBy(column.key) end)
    self.headers[column.key] = header
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

  return self
end

ns.MembersPanel = MembersPanel
