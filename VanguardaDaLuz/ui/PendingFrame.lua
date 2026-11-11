-- Alterações pendentes no calendário do jogo, aplicadas uma por clique.
local _, ns = ...

local Theme, Time, Text = ns.Theme, ns.Time, ns.Text
local PendingFrame = {}

local ROWS = 9
local frame
local rows = {}

local OP_COLORS = { create = "success", update = "azure", cancel = "cancel", remove = "warning" }

local function Title(item)
  if item.event then return item.event.title end
  return item.link.gameTitle or item.id
end

local function When(item)
  if item.event then return Time.FormatDateTime(item.event.startsAt, ns.Config.BRASILIA_OFFSET) end
  return ""
end

function PendingFrame.Refresh()
  if not frame or not frame:IsShown() then return end
  local list = ns.Calendar.PendingList()
  local phase, message, current, applied = ns.Calendar.Status()

  for i = 1, ROWS do
    local row, item = rows[i], list[i]
    if item then
      local op = item.link.op
      row.op:SetText(Theme.Code(OP_COLORS[op]) .. ns.Calendar.OP_LABELS[op] .. "|r")
      row.title:SetText(Text.Escape(Title(item)))
      row.when:SetText(When(item))
      if item.link.state == "failed" then
        row.state:SetText(Theme.Code("cancel") .. "Falhou: " .. Text.Escape(item.link.error or "erro") .. "|r")
        row.retry.id = item.id
        row.retry:Show()
      else
        local isCurrent = current and current.id == item.id
        row.state:SetText(isCurrent and (Theme.Code("gold") .. "Próxima|r") or "Pendente")
        row.retry:Hide()
      end
      row:Show()
    else
      row:Hide()
    end
  end
  frame.more:SetText(#list > ROWS and ("e mais " .. (#list - ROWS) .. " alteração(ões)") or "")

  local failed = 0
  for _, item in ipairs(list) do
    if item.link.state == "failed" then failed = failed + 1 end
  end
  frame.progress:SetText(string.format("Aplicadas nesta sessão: %d  ·  Restantes: %d  ·  Com falha: %d",
    applied, #list - failed, failed))
  frame.status:SetText(message or "")
  frame.apply:SetEnabled(phase == "ready")
  frame.retryAll:SetEnabled(failed > 0)
  frame.prepare:SetEnabled(phase == "blocked" or phase == "idle")
end

local function Build()
  frame = Theme.Window("VanguardaDaLuzPendingFrame", 640, 440, "Calendário do jogo")

  local help = Theme.Text(frame, "body", "textMuted")
  help:SetPoint("TOPLEFT", 16, -68)
  help:SetPoint("TOPRIGHT", -16, -68)
  help:SetText("O jogo só permite gravar eventos com um clique. Clique em \"Aplicar próximo\" "
    .. "para cada alteração. Somente eventos criados pelo addon são alterados.")

  for i = 1, ROWS do
    local row = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    row:SetHeight(28)
    row:SetPoint("TOPLEFT", 16, -104 - (i - 1) * 30)
    row:SetPoint("RIGHT", -16, 0)
    Theme.Backdrop(row, "surface", "border")
    row.op = Theme.Text(row, "smallStrong")
    row.op:SetPoint("LEFT", 8, 0)
    row.op:SetWidth(60)
    row.when = Theme.Text(row, "small", "textMuted")
    row.when:SetPoint("LEFT", 70, 0)
    row.when:SetWidth(100)
    row.retry = Theme.Button(row, "Tentar de novo", "ghost", 110)
    row.retry:SetHeight(22)
    row.retry:SetPoint("RIGHT", -3, 0)
    row.retry:SetScript("OnClick", function(self) ns.Calendar.Retry(self.id) end)
    row.state = Theme.Text(row, "small")
    row.state:SetPoint("RIGHT", row.retry, "LEFT", -6, 0)
    row.state:SetWidth(150)
    row.state:SetJustifyH("RIGHT")
    row.state:SetWordWrap(false)
    row.title = Theme.Text(row, "body")
    row.title:SetPoint("LEFT", 172, 0)
    row.title:SetPoint("RIGHT", row.state, "LEFT", -6, 0)
    row.title:SetWordWrap(false)
    rows[i] = row
  end

  local more = Theme.Text(frame, "small", "textMuted")
  more:SetPoint("TOPLEFT", 16, -104 - ROWS * 30)
  frame.more = more

  local progress = Theme.Text(frame, "smallStrong")
  progress:SetPoint("BOTTOMLEFT", 16, 66)
  frame.progress = progress

  local status = Theme.Text(frame, "body", "gold")
  status:SetPoint("BOTTOMLEFT", 16, 46)
  status:SetPoint("RIGHT", -16, 0)
  status:SetWordWrap(false)
  frame.status = status

  local apply = Theme.Button(frame, "Aplicar próximo", "primary", 160)
  apply:SetPoint("BOTTOMRIGHT", -16, 12)
  apply:SetScript("OnClick", function() ns.Calendar.ApplyNext() end)
  frame.apply = apply

  local prepare = Theme.Button(frame, "Preparar de novo", "outline", 140)
  prepare:SetPoint("RIGHT", apply, "LEFT", -8, 0)
  prepare:SetScript("OnClick", function() ns.Calendar.Prepare() end)
  frame.prepare = prepare

  local retryAll = Theme.Button(frame, "Tentar falhas de novo", "ghost", 170)
  retryAll:SetPoint("BOTTOMLEFT", 16, 12)
  retryAll:SetScript("OnClick", function() ns.Calendar.Retry() end)
  frame.retryAll = retryAll

  frame:SetScript("OnShow", function()
    ns.Calendar.Prepare()
    PendingFrame.Refresh()
  end)
  ns.On("PENDING_UPDATED", PendingFrame.Refresh)
  ns.On("CALENDAR_STATUS", PendingFrame.Refresh)
end

function PendingFrame.Show()
  if not frame then Build() end
  if frame:IsShown() then
    ns.Calendar.Prepare()
  else
    frame:Show()
  end
end

ns.PendingFrame = PendingFrame
