-- Atalho de teclado: monta a combinação no formato do jogo ("ALT-CTRL-SHIFT-K")
-- a partir da tecla apertada e dos modificadores. Lógica pura.
local _, ns = ...

local Keys = {}

-- Teclas que sozinhas são só modificadores (esperam a tecla de verdade).
local MODIFIERS = {
  LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
  LALT = true, RALT = true, LMETA = true, RMETA = true,
}

-- Teclas que não podem virar atalho.
local REJECTED = { ESCAPE = true, UNKNOWN = true, PRINTSCREEN = true }

function Keys.IsModifier(key)
  return MODIFIERS[key] == true
end

-- Combinação no formato do jogo, ou nil se a tecla não serve.
-- `mods` = { alt, ctrl, shift, meta }.
function Keys.Build(key, mods)
  if type(key) ~= "string" or key == "" or MODIFIERS[key] or REJECTED[key] then return nil end
  mods = mods or {}
  local prefix = ""
  if mods.alt then prefix = prefix .. "ALT-" end
  if mods.ctrl then prefix = prefix .. "CTRL-" end
  if mods.shift then prefix = prefix .. "SHIFT-" end
  if mods.meta then prefix = prefix .. "META-" end
  return prefix .. key
end

-- Combinação salva é válida? Só aceita o que Build produz.
function Keys.IsValid(combo)
  if type(combo) ~= "string" then return false end
  local key = combo:gsub("^ALT%-", ""):gsub("^CTRL%-", ""):gsub("^SHIFT%-", ""):gsub("^META%-", "")
  return key ~= "" and not key:find("%-.") and not MODIFIERS[key] and not REJECTED[key]
end

ns.Keys = Keys
return Keys
