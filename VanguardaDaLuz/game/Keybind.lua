-- Atalho de teclado para abrir e fechar a janela do addon (Configurações).
--
-- A tecla fica salva na conta (ns.db.settings.keybind) e é aplicada como
-- atalho de prioridade do addon (SetOverrideBindingClick): não altera os
-- atalhos da Blizzard e some se o addon for desligado. Em combate o jogo não
-- deixa trocar atalhos, então a troca espera o combate acabar.
local _, ns = ...

local Keys = ns.Keys
local Keybind = {}

local BUTTON_NAME = "VanguardaDaLuzToggleButton"
local owner      -- frame dono do atalho (recebe também o fim do combate)
local pending = false

local function Apply()
  if InCombatLockdown() then
    pending = true
    return
  end
  pending = false
  ClearOverrideBindings(owner)
  local combo = Keybind.Get()
  if combo then SetOverrideBindingClick(owner, true, combo, BUTTON_NAME) end
end

-- Fim do combate: aplica a troca que ficou esperando.
function Keybind.OnCombatEnd()
  if not pending then return end
  Apply()
  ns.Fire("SETTINGS_UPDATED")
end

function Keybind.Init()
  owner = CreateFrame("Frame")
  owner:RegisterEvent("PLAYER_REGEN_ENABLED")
  owner:SetScript("OnEvent", Keybind.OnCombatEnd)
  -- Botão invisível acionado pelo atalho: faz o mesmo que /vdl.
  local button = CreateFrame("Button", BUTTON_NAME, UIParent)
  button:SetScript("OnClick", function() SlashCmdList.VANGUARDADALUZ("") end)
  if ns.db.settings.keybind and not Keys.IsValid(ns.db.settings.keybind) then ns.db.settings.keybind = nil end
  Apply()
end

-- Combinação atual ("SHIFT-V") ou nil.
function Keybind.Get()
  return ns.db.settings.keybind
end

-- Define (ou, com nil, remove) o atalho.
function Keybind.Set(combo)
  if combo ~= nil and not Keys.IsValid(combo) then return end
  ns.db.settings.keybind = combo
  Apply()
  ns.Fire("SETTINGS_UPDATED")
end

-- A troca está esperando o fim do combate?
function Keybind.IsPending()
  return pending
end

-- Texto da combinação para a tela ("Shift-V"), no idioma do jogo.
function Keybind.Text(combo)
  if not combo then return nil end
  return GetBindingText and GetBindingText(combo) or combo
end

-- Ação da Blizzard que já usa esta tecla (nome para a tela), ou nil.
function Keybind.Conflict(combo)
  if not combo or not GetBindingAction then return nil end
  local action = GetBindingAction(combo)
  if not action or action == "" or action:find(BUTTON_NAME, 1, true) then return nil end
  return _G["BINDING_NAME_" .. action] or action
end

ns.Keybind = Keybind
