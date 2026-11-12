-- Namespace do addon, avisos internos e mensagens no chat.
local ADDON_NAME, ns = ...

ns.name = ADDON_NAME
ns.path = "Interface\\AddOns\\" .. ADDON_NAME .. "\\"
ns.LibDeflate = LibStub("LibDeflate")
ns.version = (C_AddOns and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")) or "?"

-- Avisos entre módulos: ns.On("DATA_UPDATED", fn) e ns.Fire("DATA_UPDATED").
--   DATA_UPDATED     eventos do addon mudaram
--   SYNC_STATUS      estado da sincronização mudou
local listeners = {}

function ns.On(name, fn)
  listeners[name] = listeners[name] or {}
  table.insert(listeners[name], fn)
end

function ns.Fire(name, ...)
  for _, fn in ipairs(listeners[name] or {}) do
    local ok, err = pcall(fn, ...)
    if not ok then geterrorhandler()(err) end
  end
end

function ns.Print(message)
  print("|cfff2c94cVanguarda da Luz:|r " .. message)
end
