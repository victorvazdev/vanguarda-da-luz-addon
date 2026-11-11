-- Teste de fumaça: carrega o addon inteiro, na ordem do .toc, com uma
-- simulação mínima da API do jogo, e percorre importação, calendário do jogo
-- e sincronização. Não substitui o teste no jogo (ver README).
-- Retorna as linhas impressas e o namespace do addon.
local ROOT = "VanguardaDaLuz/"
local frames = {}
local function Mock(name)
  local o = { _scripts = {}, _shown = false, _text = "", _enabled = true, _name = name }
  return setmetatable(o, { __index = function(_, k)
    local f = ({
      SetScript = function(self, n, fn) self._scripts[n] = fn end,
      GetScript = function(self, n) return self._scripts[n] end,
      CreateFontString = function() return Mock() end,
      CreateTexture = function() return Mock() end,
      Show = function(self) self._shown = true; if self._scripts.OnShow then self._scripts.OnShow(self) end end,
      Hide = function(self) self._shown = false end,
      IsShown = function(self) return self._shown end,
      SetShown = function(self, v) if v then self:Show() else self:Hide() end end,
      SetText = function(self, v) self._text = v end,
      GetText = function(self) return self._text end,
      IsEnabled = function(self) return self._enabled end,
      Enable = function(self) self._enabled = true end,
      Disable = function(self) self._enabled = false end,
      SetEnabled = function(self, v) self._enabled = v and true or false end,
      GetWidth = function() return 140 end,
      GetStringHeight = function() return 20 end,
      GetCenter = function() return 0, 0 end,
      GetEffectiveScale = function() return 1 end,
      RegisterEvent = function(self) frames.events = self; return true end,
    })[k]
    return f or function() return nil end
  end })
end
local all = {}
_G.CreateFrame = function(_, name) local f = Mock(name); all[#all+1] = f; if name then _G[name] = f end; return f end
_G.CreateFont = function() return Mock() end
_G.UIParent, _G.Minimap, _G.GameTooltip = Mock(), Mock(), Mock()
_G.UISpecialFrames, _G.SlashCmdList = {}, {}
_G.Mixin = function(o) return o end
_G.BackdropTemplateMixin = {}
_G.CreateColor = function() return {} end
_G.geterrorhandler = function() return error end
_G.securecallfunction = function(f, ...) return f(...) end
local now = 1794410000
_G.GetServerTime = function() return now end
_G.GetTime = function() return 0 end
_G.IsInGuild = function() return true end
_G.InCombatLockdown = function() return false end
_G.GetGuildInfo = function() return "Vanguarda da Luz", "Oficial", 1 end
_G.GetNumGuildMembers = function() return 1 end
_G.GetGuildRosterInfo = function() return "Maren-Forever", "Oficial", 1 end
_G.UnitName = function() return "Tester" end
_G.Ambiguate = function(n) return n end
_G.GetCursorPosition = function() return 0, 0 end
_G.Enum = {}
local timers = {}
_G.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end, NewTicker = function() end }
_G.C_AddOns = { GetAddOnMetadata = function() return "0.1.0" end }
_G.C_GuildInfo = { GuildRoster = function() end, GuildControlGetRankFlags = function() return { [14] = true } end }
local sent = {}
_G.C_ChatInfo = {
  RegisterAddonMessagePrefix = function() return 0 end,
  SendAddonMessage = function(_, m) sent[#sent + 1] = m; return 0 end,
  InChatMessagingLockdown = function() return false end,
}
_G.C_DateAndTime = { GetCurrentCalendarTime = function()
  return { year = 2026, month = 11, monthDay = 12, hour = 20, minute = 33 } end }
local calls = {}
_G.C_Calendar = setmetatable({
  GetMonthInfo = function() return { year = 2026, month = 11 } end,
  GetNumDayEvents = function() return 0 end,
  CanAddEvent = function() return true end,
  EventCanEdit = function() return true end,
}, { __index = function(_, k) return function() calls[#calls + 1] = k end end })
_G.ChatFrame_AddMessageEventFilter = function() end
_G.hooksecurefunc = function() end
local output = {}
_G.print = function(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
  output[#output + 1] = table.concat(t, " ")
end
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.strsplit = function() end
_G.max, _G.min, _G.floor = math.max, math.min, math.floor
_G.tinsert, _G.tremove = table.insert, table.remove
_G.debugstack = function() return "" end
_G.issecretvalue = nil

local ns = {}
for line in io.lines(ROOT .. "VanguardaDaLuz_Forever.toc") do
  if not line:match("^##") and line:match("%S") then
    local path = line:gsub("\\", "/")
    local files = {}
    if path:match("%.xml$") then
      local dir = path:match("^(.*)/")
      for l in io.lines(ROOT .. path) do
        local f = l:match('Script file="([^"]+)"'); if f then files[#files + 1] = dir .. "/" .. f end
      end
    else files = { path } end
    for _, f in ipairs(files) do assert(loadfile(ROOT .. f))("VanguardaDaLuz", ns) end
  end
end

local ev = frames.events
ev._scripts.OnEvent(ev, "ADDON_LOADED", "VanguardaDaLuz")
ev._scripts.OnEvent(ev, "PLAYER_ENTERING_WORLD")
SlashCmdList.VANGUARDADALUZ("")
SlashCmdList.VANGUARDADALUZ("ajuda")
SlashCmdList.VANGUARDADALUZ("importar")
local dialog = _G.VanguardaDaLuzImportDialog
local f = io.open("docs/exemplos-addon/valida.txt"); local raw = f:read("*a"); f:close()
-- Clica no botão com o texto indicado (o mais recente, se houver vários).

local function Click(label)
  for i = #all, 1, -1 do
    local b = all[i]
    if b._text == label and b._scripts.OnClick then return b._scripts.OnClick(b, "LeftButton") end
  end
  error("botão não encontrado: " .. label)
end
local function RunTimers() local list = timers; timers = {}; for _, fn in ipairs(list) do fn() end end

dialog.edit:SetText("lixo"); Click("Validar"); print("erro:", dialog.message._text)
dialog.edit:SetText(raw); Click("Validar"); print("resumo:\n" .. dialog.message._text)
print("confirm enabled:", dialog.confirm:IsEnabled())
local comms = {}
ns.Comm.SendCommMessage = function(_, prefix, msg, dist, _, prio)
  comms[#comms + 1] = prefix .. " " .. dist .. " " .. (prio or "") .. " " .. msg:sub(1, 30)
end
Click("Confirmar importação")
print("eventos salvos:", (function() local n=0 for _ in pairs(ns.db.events) do n=n+1 end return n end)())
print("pendências:", #ns.Calendar.PendingList(), "mensagens enviadas:", #sent)
RunTimers()  -- localizar
print("status:", ns.Calendar.Status())
Click("Aplicar próximo")
print("chamadas C_Calendar:", table.concat(calls, ","))
RunTimers()  -- gravar
print("status:", ns.Calendar.Status())
print("link A:", ns.db.game["3kTq9ZcV1bWfX7rLm2Pa"].state, ns.db.game["3kTq9ZcV1bWfX7rLm2Pa"].gameEventId)
SlashCmdList.VANGUARDADALUZ("")  -- fecha
SlashCmdList.VANGUARDADALUZ("")  -- abre de novo e renderiza
print("info:", _G.VanguardaDaLuzMainFrame.info._text)
print("dia:", _G.VanguardaDaLuzMainFrame.dayTitle._text)
-- membro recebendo dados de um oficial
local comm = ns.Comm
ns.db.export = nil; ns.db.events = {}
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.Data(1794409200, raw:gsub("%s+$","")), "GUILD", "Maren-Forever")
print("recebido da guilda:", ns.db.export and ns.db.export.source, ns.db.export and ns.db.export.sender)
comm.OnCommReceived(comm, "VanguardaDaLuz", ns.Protocol.Query(0), "GUILD", "Dorvan")
RunTimers()
print("respondeu ao pedido; mensagens enviadas:", #sent)
for _, c in ipairs(comms) do print("comm:", c) end
return output, ns, comms
