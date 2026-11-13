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
  "Ambiguate", "BackdropTemplateMixin", "C_AddOns", "C_ChatInfo",
  "C_DateAndTime", "C_GuildInfo", "C_Timer", "CreateColor", "CreateFont",
  "CreateFrame", "Enum", "GameTooltip", "GetCursorPosition", "GetGuildInfo",
  "GetGuildRosterInfo", "GetNumGuildMembers", "GetServerTime", "InChatMessagingLockdown",
  "InCombatLockdown", "IsInGuild", "LibStub", "Minimap", "Mixin", "UIParent", "UnitName",
  "geterrorhandler", "GetTime", "PlaySound", "RaidNotice_AddMessage", "RaidWarningFrame",
  "SendChatMessage", "SOUNDKIT", "UnitGUID", "C_Club", "GetProfessions", "GetProfessionInfo",
  "GetAverageItemLevel", "PixelUtil", "RAID_CLASS_COLORS", "C_PartyInfo", "InviteUnit",
  "GetLocale", "UnitIsAFK", "GetZoneText", "GetNumGroupMembers", "IsInRaid", "UnitExists", "UnitIsUnit", "UnitIsConnected",
  "ChatFrameUtil", "ChatFrame_SendTell", "hooksecurefunc",
  "GetGuildRosterMOTD", "GetGuildInfoText",
}

files["tests/"] = { std = "+busted" }

-- Tabela de traduções: as chaves são os textos em português, inteiros.
files["VanguardaDaLuz/core/Locale.lua"] = { max_line_length = false }
