-- Membros da guilda por perto: o logo da guilda em cima da placa de nome
-- (nameplate) de cada jogador da guilda e uma linha no tooltip ao passar o
-- mouse nele (posto, item level e main/alt).
--
-- Quem é da guilda vem do jogo (UnitIsInMyGuild), então funciona também para
-- quem não tem o addon. O nome em cima do personagem é desenhado pelo jogo e
-- nenhum addon muda; por isso o logo vai na placa de nome, que só aparece com
-- as placas de aliados ligadas (Shift+V). Em masmorras e raides as placas de
-- aliados são protegidas e o logo não aparece. O logo é um quadro do addon
-- ancorado na placa; o addon não mexe nos quadros nem nos textos da Blizzard.
--
-- Opções em db.settings.nearby: { plates = false, tooltip = false } desligam;
-- scale = tamanho do logo (1 = Config.NAMEPLATE_ICON_SIZE, até 3).
local _, ns = ...

local GuildNearby = {}

local icons = {} -- [placa] = quadro do logo
-- Unidades com placa visível, pelos eventos NAME_PLATE_UNIT_ADDED/REMOVED:
-- o campo namePlateUnitToken das placas não existe em todas as versões.
local units = {}

local function Settings()
  ns.db.settings.nearby = ns.db.settings.nearby or {}
  return ns.db.settings.nearby
end

-- Logo nas placas de nome e linha no tooltip: começam ligados.
function GuildNearby.ShowsPlates()
  return Settings().plates ~= false
end

function GuildNearby.ShowsTooltip()
  return Settings().tooltip ~= false
end

function GuildNearby.SetPlates(on)
  if on then Settings().plates = nil else Settings().plates = false end
  GuildNearby.RefreshAll()
  ns.Fire("SETTINGS_UPDATED")
end

function GuildNearby.SetTooltip(on)
  if on then Settings().tooltip = nil else Settings().tooltip = false end
  ns.Fire("SETTINGS_UPDATED")
end

-- Tamanho do logo: de SCALE_MIN a SCALE_MAX, em passos de SCALE_STEP.
GuildNearby.SCALE_MIN, GuildNearby.SCALE_MAX, GuildNearby.SCALE_STEP = 1, 3, 0.25

function GuildNearby.Scale()
  local scale = tonumber(Settings().scale) or 1
  return math.max(GuildNearby.SCALE_MIN, math.min(GuildNearby.SCALE_MAX, scale))
end

-- Muda o tamanho em `steps` passos (+1 aumenta, -1 diminui).
function GuildNearby.StepScale(steps)
  local scale = GuildNearby.Scale() + steps * GuildNearby.SCALE_STEP
  scale = math.floor(scale / GuildNearby.SCALE_STEP + 0.5) * GuildNearby.SCALE_STEP
  scale = math.max(GuildNearby.SCALE_MIN, math.min(GuildNearby.SCALE_MAX, scale))
  if scale == 1 then Settings().scale = nil else Settings().scale = scale end
  GuildNearby.RefreshAll()
  ns.Fire("SETTINGS_UPDATED")
end

local function IsPlayerUnit(unit)
  local ok, me = pcall(UnitIsUnit, unit, "player")
  return ok and not ns.Flavor.IsSecret(me) and me and true or false
end

local function Logo()
  return ns.path .. "assets\\logo-64"
end

local function Icon(plate)
  local icon = icons[plate]
  if icon then return icon end
  icon = CreateFrame("Frame", nil, plate)
  local texture = icon:CreateTexture(nil, "OVERLAY")
  texture:SetAllPoints()
  texture:SetTexture(Logo())
  icon:EnableMouse(false)
  icons[plate] = icon
  return icon
end

-- Mostra ou esconde o logo na placa da unidade.
function GuildNearby.Update(unit)
  local plate = ns.Flavor.NamePlate(unit)
  if not plate then return end
  local show = GuildNearby.ShowsPlates() and ns.Guild.IsMember() and ns.Flavor.UnitInMyGuild(unit)
    and not IsPlayerUnit(unit)
  if not show then
    if icons[plate] then icons[plate]:Hide() end
    return
  end
  local icon = Icon(plate)
  local size = ns.Config.NAMEPLATE_ICON_SIZE * GuildNearby.Scale()
  icon:SetSize(size, size)
  icon:ClearAllPoints()
  -- Em cima do nome da placa, se ela tiver um; senão, no topo da placa.
  local name = plate.UnitFrame and plate.UnitFrame.name
  if name and name.IsShown and name:IsShown() then
    icon:SetPoint("BOTTOM", name, "TOP", 0, 2)
  else
    icon:SetPoint("BOTTOM", plate, "TOP", 0, 0)
  end
  icon:Show()
end

function GuildNearby.Remove(unit)
  units[unit] = nil
  local plate = ns.Flavor.NamePlate(unit)
  if plate and icons[plate] then icons[plate]:Hide() end
end

-- Confere todas as placas visíveis (ao mudar a opção ou entrar na guilda).
function GuildNearby.RefreshAll()
  for _, unit in ipairs(ns.Flavor.NamePlateUnits()) do units[unit] = true end
  for _, icon in pairs(icons) do icon:Hide() end
  for unit in pairs(units) do GuildNearby.Update(unit) end
end

-- Linha do tooltip para a unidade, ou nil se ela não é da guilda.
function GuildNearby.TooltipLine(unit)
  if not (GuildNearby.ShowsTooltip() and ns.Guild.IsMember() and ns.Flavor.UnitInMyGuild(unit)) then return nil end
  local entry = ns.Guild.MemberByGuid(ns.Flavor.UnitGuid(unit))
  if not entry then return nil end
  local line = ns.Members.UnitLine(entry.name, entry.rank, ns.GuildMembers.Get(entry.name))
  if not line then return nil end
  return "|T" .. Logo() .. ":14:14|t " .. ns.Text.Escape(line)
end

local function OnTooltip(tooltip, unit)
  local line = GuildNearby.TooltipLine(unit)
  if line then tooltip:AddLine(line, 0.95, 0.79, 0.30) end
end

function GuildNearby.Init()
  local events = CreateFrame("Frame")
  events:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
      units[unit] = true
      GuildNearby.Update(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
      GuildNearby.Remove(unit)
    else
      GuildNearby.RefreshAll()
    end
  end)
  events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
  events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
  events:RegisterEvent("PLAYER_GUILD_UPDATE")
  GuildNearby.events = events -- para o teste de fumaça
  ns.Flavor.HookUnitTooltip(OnTooltip)
end

GuildNearby.icons = icons -- para o teste de fumaça

ns.GuildNearby = GuildNearby
