-- Datas e fusos horários. Lógica pura: não usa date() nem os.date(), para dar o
-- mesmo resultado dentro e fora do jogo.
local _, ns = ...

local Time = {}

local floor = math.floor

Time.WEEKDAYS = { "domingo", "segunda", "terça", "quarta", "quinta", "sexta", "sábado" }
Time.WEEKDAYS_SHORT = { "Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb" }
Time.MONTHS = {
  "janeiro", "fevereiro", "março", "abril", "maio", "junho",
  "julho", "agosto", "setembro", "outubro", "novembro", "dezembro",
}

-- Nomes em inglês (ns.locale == "enUS").
local EN = {
  WEEKDAYS = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" },
  WEEKDAYS_SHORT = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" },
  MONTHS = {
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
  },
}

local function English() return ns.locale == "enUS" end

-- Nomes no idioma do addon: Time.Names().MONTHS etc.
function Time.Names()
  return English() and EN or Time
end

-- Dias desde 1970-01-01 para uma data do calendário gregoriano.
function Time.DaysFromCivil(y, m, d)
  if m <= 2 then y = y - 1 end
  local era = floor(y / 400)
  local yoe = y - era * 400
  local mp = (m + 9) % 12
  local doy = floor((153 * mp + 2) / 5) + d - 1
  local doe = yoe * 365 + floor(yoe / 4) - floor(yoe / 100) + doy
  return era * 146097 + doe - 719468
end

-- Data do calendário para um número de dias desde 1970-01-01.
function Time.CivilFromDays(z)
  z = z + 719468
  local era = floor(z / 146097)
  local doe = z - era * 146097
  local yoe = floor((doe - floor(doe / 1460) + floor(doe / 36524) - floor(doe / 146096)) / 365)
  local y = yoe + era * 400
  local doy = doe - (365 * yoe + floor(yoe / 4) - floor(yoe / 100))
  local mp = floor((5 * doy + 2) / 153)
  local d = doy - floor((153 * mp + 2) / 5) + 1
  local m = mp < 10 and mp + 3 or mp - 9
  if m <= 2 then y = y + 1 end
  return y, m, d
end

-- Campos de data de um instante Unix num fuso com `offset` segundos em
-- relação ao UTC. weekday: 1 = domingo.
function Time.Fields(ts, offset)
  local t = ts + (offset or 0)
  local days = floor(t / 86400)
  local secs = t - days * 86400
  local y, m, d = Time.CivilFromDays(days)
  return {
    year = y, month = m, day = d,
    hour = floor(secs / 3600), minute = floor((secs % 3600) / 60),
    weekday = (days + 4) % 7 + 1,
  }
end

-- Instante Unix de uma data e hora num fuso com `offset` segundos.
function Time.FromFields(y, m, d, hour, minute, offset)
  return Time.DaysFromCivil(y, m, d) * 86400 + (hour or 0) * 3600 + (minute or 0) * 60 - (offset or 0)
end

-- Diferença entre a hora do servidor e o UTC, arredondada a 15 minutos.
-- `calendarTime` vem de C_DateAndTime.GetCurrentCalendarTime() e
-- `serverUnix` de GetServerTime().
function Time.ServerOffset(calendarTime, serverUnix)
  local asUtc = Time.FromFields(calendarTime.year, calendarTime.month, calendarTime.monthDay,
    calendarTime.hour, calendarTime.minute, 0)
  return floor((asUtc - serverUnix) / 900 + 0.5) * 900
end

local function Pad(n) return string.format("%02d", n) end

-- "14/11/2026 20:00" (em inglês, "2026-11-14 20:00")
function Time.FormatDateTime(ts, offset)
  local f = Time.Fields(ts, offset)
  return Time.FormatDate(ts, offset) .. " " .. Pad(f.hour) .. ":" .. Pad(f.minute)
end

-- "14/11/2026" (em inglês, "2026-11-14")
function Time.FormatDate(ts, offset)
  local f = Time.Fields(ts, offset)
  if English() then return f.year .. "-" .. Pad(f.month) .. "-" .. Pad(f.day) end
  return Pad(f.day) .. "/" .. Pad(f.month) .. "/" .. f.year
end

-- "20:00"
function Time.FormatClock(ts, offset)
  local f = Time.Fields(ts, offset)
  return Pad(f.hour) .. ":" .. Pad(f.minute)
end

-- "sábado, 14 de novembro de 2026" (em inglês, "Saturday, November 14, 2026")
function Time.FormatLongDate(ts, offset)
  local f = Time.Fields(ts, offset)
  if English() then
    return EN.WEEKDAYS[f.weekday] .. ", " .. EN.MONTHS[f.month] .. " " .. f.day .. ", " .. f.year
  end
  return Time.WEEKDAYS[f.weekday] .. ", " .. f.day .. " de " .. Time.MONTHS[f.month] .. " de " .. f.year
end

-- "Novembro de 2026" (em inglês, "November 2026")
function Time.FormatMonth(year, month)
  if English() then return EN.MONTHS[month] .. " " .. year end
  return (string.gsub(Time.MONTHS[month], "^%l", string.upper)) .. " de " .. year
end

-- "UTC-3", "UTC+5:30"
function Time.FormatOffset(offset)
  local sign = offset < 0 and "-" or "+"
  local abs = math.abs(offset)
  local h, m = floor(abs / 3600), floor((abs % 3600) / 60)
  return "UTC" .. sign .. h .. (m > 0 and (":" .. Pad(m)) or "")
end

-- Quantidade de dias de um mês.
function Time.DaysInMonth(y, m)
  local ny, nm = y, m + 1
  if nm > 12 then ny, nm = y + 1, 1 end
  return Time.DaysFromCivil(ny, nm, 1) - Time.DaysFromCivil(y, m, 1)
end

-- Dia da semana (1 = domingo) do primeiro dia do mês.
function Time.FirstWeekday(y, m)
  return (Time.DaysFromCivil(y, m, 1) + 4) % 7 + 1
end

-- Soma `delta` meses a (ano, mês).
function Time.AddMonths(y, m, delta)
  local index = y * 12 + (m - 1) + delta
  return floor(index / 12), index % 12 + 1
end

ns.Time = Time
return Time
