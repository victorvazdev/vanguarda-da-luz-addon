-- Configuração geral do addon. Valores que dependem da versão do jogo ficam em
-- core/Flavor_<Jogo>.lua.
local _, ns = ...

ns.Config = {
  -- Prefixo das mensagens de addon (até 16 caracteres).
  COMM_PREFIX = "VanguardaDaLuz",

  -- Formato da string (docs/formato-string-addon.md).
  FORMAT_VERSION = 1,
  MAX_STRING_LENGTH = 30000,

  -- Cargos aceitos como fonte de dados. O índice do cargo começa em 0, que é
  -- sempre o Mestre da Guilda ("Grão Lorde" na Vanguarda da Luz), mesmo se o
  -- cargo for renomeado.
  TRUSTED_MAX_RANK_INDEX = 0,
  -- Nomes de cargo aceitos além dos índices acima. O nome precisa ser igual ao
  -- do jogo, com acentos e maiúsculas.
  TRUSTED_RANK_NAMES = { "Lorde" },

  -- Horário de Brasília: UTC-3, sem horário de verão desde 2019.
  BRASILIA_OFFSET = -3 * 3600,

  -- Limites do calendário do jogo, em bytes. Textos maiores são cortados no
  -- jogo e continuam completos no calendário do addon.
  GAME_TITLE_MAX_BYTES = 31,
  GAME_DESCRIPTION_MAX_BYTES = 255,
  -- Prefixo do título de um evento cancelado no calendário do jogo.
  GAME_CANCELLED_PREFIX = "[Cancelado] ",

  -- Sincronização: esperas aleatórias, em segundos.
  REQUEST_DELAY_MIN = 5,
  REQUEST_DELAY_MAX = 15,
  RESPONSE_DELAY_MIN = 1,
  RESPONSE_DELAY_MAX = 6,

  -- Alerta de raide.
  ALERT_MAX_CHARS = 200,          -- tamanho máximo do texto, em caracteres
  ALERT_CHAT_PREFIX = "[Alerta] ", -- prefixo da mensagem no chat da guilda
  ALERT_SEND_INTERVAL = 30,       -- espera mínima entre dois envios, em segundos
  ALERT_RECEIVE_INTERVAL = 20,    -- intervalo mínimo aceito do mesmo remetente
  ALERT_DISPLAY_SECONDS = 10,     -- tempo do aviso na tela (faixa própria)
}

return ns.Config
