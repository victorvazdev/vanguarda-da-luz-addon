-- Importação de uma string: valida tudo antes de alterar os dados e depois
-- aplica o retrato completo. Usada pelo administrador (colando a string) e
-- pelos membros (recebendo da guilda). Lógica pura.
--
-- `data` é a parte do SavedVariables com { export = meta|nil, events = {} }.
local _, ns = ...

local Import = {}

-- Valida a string e calcula as alterações, sem mexer em `data`.
-- Retorna { raw, export, diff } ou nil e o código do erro (ver ns.Codec.ERRORS).
function Import.Prepare(data, raw, options)
  local Config, Codec, Snapshot = ns.Config, ns.Codec, ns.Snapshot
  options = options or {}
  local export, code = Codec.Decode(raw, options.maxLength or Config.MAX_STRING_LENGTH)
  if not export then return nil, code end

  local expectedGame = options.game or ns.Flavor.exportGame
  if export.game ~= expectedGame then return nil, "game" end

  local last = data.export
  if last and export.exportNumber <= last.exportNumber then return nil, "old" end

  return {
    raw = ns.Text.Trim(raw),
    export = export,
    diff = Snapshot.Diff(data.events, export),
  }
end

-- Aplica uma importação preparada. `meta` traz { source, sender, receivedAt }.
function Import.Commit(data, prepared, meta)
  local export = prepared.export
  ns.Snapshot.Apply(data.events, prepared.diff)
  data.export = {
    raw = prepared.raw,
    exportNumber = export.exportNumber,
    windowStart = export.windowStart,
    windowEnd = export.windowEnd,
    count = export.count,
    receivedAt = meta.receivedAt,
    source = meta.source,
    sender = meta.sender,
  }
  return prepared.diff
end

ns.Import = Import
return Import
