-- luacheck: configuração do projeto. Rode com scripts/check.sh.
std = "lua51"
max_line_length = 120
codes = true
exclude_files = { "VanguardaDaLuz/libs/", ".lua/", ".venv/", "dist/" }

-- Globais que o addon define.
globals = {
  "VanguardaDaLuzDB",
  "SLASH_VANGUARDADALUZ1",
  "SlashCmdList",
  "UISpecialFrames",
  "VanguardaDaLuz_OnAddonCompartmentClick",
  "VanguardaDaLuz_OnAddonCompartmentEnter",
  "VanguardaDaLuz_OnAddonCompartmentLeave",
}

-- API do jogo usada pelo addon.
read_globals = {
  "Ambiguate", "BackdropTemplateMixin", "C_AddOns", "C_Calendar", "C_ChatInfo",
  "C_DateAndTime", "C_GuildInfo", "C_Timer", "CalendarFrame", "CreateColor", "CreateFont",
  "CreateFrame", "Enum", "GameTooltip", "GetCursorPosition", "GetGuildInfo",
  "GetGuildRosterInfo", "GetNumGuildMembers", "GetServerTime", "InChatMessagingLockdown",
  "InCombatLockdown", "IsInGuild", "LibStub", "Minimap", "Mixin", "UIParent", "UnitName",
  "geterrorhandler", "GetTime", "PlaySound", "RaidNotice_AddMessage", "RaidWarningFrame",
  "SendChatMessage", "SOUNDKIT", "UnitGUID",
}

files["tests/"] = { std = "+busted" }
