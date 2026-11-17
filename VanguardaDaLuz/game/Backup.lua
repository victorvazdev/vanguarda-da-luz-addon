-- Backup dos dados do addon (string VDLB1, docs/formato-string-backup.md):
-- gera a string para o site guardar e restaura uma string vinda do site. Só
-- para o Grão Lorde e os Lordes.
--
-- A restauração só junta: em cada registro vale o mais recente (no tempo
-- junto, o maior). Nada que o addon já tem é apagado. Depois, os dados
-- restaurados são oferecidos à guilda pela sincronização de sempre.
local _, ns = ...

local L = ns.L

local Backup = {}

-- Erros da restauração (traduzidos onde aparecem); os outros vêm de
-- Codec.ERRORS.
Backup.ERRORS = {
  empty = "Cole a string de backup copiada do site.",
  prefix = "Isto não é uma string de backup da Vanguarda da Luz (deve começar com VDLB).",
  game = "Este backup é de outra versão do jogo.",
}

-- Dados atuais em uma string VDLB1: eventos do jogo que aguardam o site,
-- presenças, profissões, item level e main, e tempo jogado junto.
function Backup.ExportString()
  local db = ns.db
  return ns.BackupCodec.Encode({
    game = ns.Flavor.exportGame,
    generatedAt = GetServerTime(),
    exportNumber = ns.Store.ExportNumber() or 0,
    generatedBy = ns.Guild.PlayerName() or "",
    events = ns.GameEvents.Pending(db.events, db.deleted),
    attendance = db.attendance or {},
    professions = db.professions or {},
    members = db.members or {},
    together = db.together or {},
  })
end

-- Valida uma string sem alterar nada. Retorna os dados ou nil e a mensagem.
function Backup.Prepare(raw)
  local data, code = ns.BackupCodec.Decode(raw)
  if data and data.game ~= ns.Flavor.exportGame then data, code = nil, "game" end
  if not data then
    local text = Backup.ERRORS[code] or ns.Codec.ERRORS[code]
    return nil, text and L[text] or code
  end
  return data
end

local function Merge(target, other, merge)
  if not target then return 0 end
  return merge(target, other)
end

-- Restaura (junta) os dados. Retorna a quantidade de alterações por seção.
function Backup.Restore(data)
  local db = ns.db
  local changed = {
    events = ns.GuildEvents.Merge(data.events),
    attendance = Merge(db.attendance, data.attendance, ns.Attendance.Merge),
    professions = Merge(db.professions, data.professions, ns.Professions.Merge),
    members = Merge(db.members, data.members, ns.Members.Merge),
    together = Merge(db.together, data.together, ns.Together.Merge),
  }
  ns.Fire("ATTENDANCE_UPDATED")
  ns.Fire("PROFESSIONS_UPDATED")
  ns.Fire("MEMBERS_UPDATED")
  ns.Fire("TOGETHER_UPDATED")
  -- Oferece os dados à guilda, como numa resposta a um pedido.
  ns.GuildEvents.OnRequest()
  ns.Presence.OnRequest()
  ns.GuildProfessions.OnRequest(true)
  ns.GuildProfessions.OnRequest(false)
  ns.GuildMembers.OnRequest()
  ns.GuildTogether.OnRequest()
  return changed
end

ns.Backup = Backup
