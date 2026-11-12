-- Funções puras de texto (UTF-8).
local _, ns = ...

local Text = {}

local ELLIPSIS = "\226\128\166" -- "…"

-- Corta `s` em no máximo `maxBytes` bytes sem quebrar um caractere UTF-8.
-- Se cortar, termina com "…" (dentro do limite).
function Text.Truncate(s, maxBytes)
  if #s <= maxBytes then return s end
  local limit = maxBytes - #ELLIPSIS
  if limit <= 0 then return "" end
  local cut = limit
  -- Recuar enquanto o próximo byte for continuação (10xxxxxx).
  while cut > 0 do
    local nextByte = string.byte(s, cut + 1)
    if not nextByte or nextByte < 128 or nextByte >= 192 then break end
    cut = cut - 1
  end
  return (string.gsub(string.sub(s, 1, cut), "%s+$", "")) .. ELLIPSIS
end

-- Texto para exibir em FontString: "|" é o caractere de escape do jogo.
function Text.Escape(s)
  return (string.gsub(s, "|", "||"))
end

-- Texto para o calendário do jogo: sem "|" e sem caracteres de controle,
-- exceto quebras de linha.
function Text.ForGame(s)
  s = string.gsub(s, "|", "/")
  s = string.gsub(s, "\r\n", "\n")
  s = string.gsub(s, "[%z\1-\9\11-\31\127]", "")
  return s
end

-- Remove espaços e caracteres de controle nas pontas.
function Text.Trim(s)
  s = string.gsub(s, "^[%c ]+", "")
  s = string.gsub(s, "[%c ]+$", "")
  return s
end

-- Número de caracteres UTF-8 (bytes que não são de continuação).
function Text.Length(s)
  local _, count = string.gsub(s, "[^\128-\191]", "")
  return count
end

-- Links num texto: { { url, first, last }, ... } em ordem, com as posições em
-- bytes. Aceita http://, https:// e www.; pontuação no fim ("site.app.") não
-- faz parte do link.
local LINK_PATTERNS = { "[Hh][Tt][Tt][Pp][Ss]?://[^%s|<>\"]+", "[Ww][Ww][Ww]%.[^%s|<>\"]+" }

function Text.FindLinks(s)
  local links, pos = {}, 1
  while true do
    local first, last
    for _, pattern in ipairs(LINK_PATTERNS) do
      local a, b = string.find(s, pattern, pos)
      if a and (not first or a < first) then first, last = a, b end
    end
    if not first then break end
    local url = string.sub(s, first, last)
    local trimmed = string.gsub(url, "[%.,;:!%?%)%]}'\"]+$", "")
    last = first + #trimmed - 1
    -- "www." sozinho não é link.
    if #trimmed > 4 and not string.find(trimmed, "^[Ww][Ww][Ww]%.$") then
      links[#links + 1] = { url = trimmed, first = first, last = last }
    end
    pos = math.max(last, first) + 1
  end
  return links
end

-- Texto para exibir com os links clicáveis: cada link vira um hyperlink
-- "|H<tipo>:<url>|h<url>|h" na cor `color` ("|cffRRGGBB"). O resto é escapado.
function Text.Linkify(s, linkType, color)
  local parts, pos = {}, 1
  for _, link in ipairs(Text.FindLinks(s)) do
    parts[#parts + 1] = Text.Escape(string.sub(s, pos, link.first - 1))
    parts[#parts + 1] = color .. "|H" .. linkType .. ":" .. link.url .. "|h" .. link.url .. "|h|r"
    pos = link.last + 1
  end
  parts[#parts + 1] = Text.Escape(string.sub(s, pos))
  return table.concat(parts)
end

ns.Text = Text
return Text
