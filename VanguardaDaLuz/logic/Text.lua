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

ns.Text = Text
return Text
