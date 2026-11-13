-- Configuração geral do addon. Valores que dependem da versão do jogo ficam em
-- core/Flavor_<Jogo>.lua.
local _, ns = ...

ns.Config = {
  -- Prefixo das mensagens de addon (até 16 caracteres).
  COMM_PREFIX = "VanguardaDaLuz",

  -- Formato da string (docs/formato-string-addon.md).
  FORMAT_VERSION = 1,
  MAX_STRING_LENGTH = 30000,

  -- O addon só funciona para quem está nesta guilda (nome igual ao do jogo).
  -- Os demais veem só a janela de boas-vindas com o convite do Discord.
  GUILD_NAME = "Vanguarda da Luz",
  DISCORD_URL = "https://discord.gg/uGyPjtEsBw",

  -- Cargos aceitos como fonte de dados. O índice do cargo começa em 0, que é
  -- sempre o Mestre da Guilda ("Grão Lorde" na Vanguarda da Luz), mesmo se o
  -- cargo for renomeado.
  TRUSTED_MAX_RANK_INDEX = 0,
  -- Nomes de cargo aceitos além dos índices acima. O nome precisa ser igual ao
  -- do jogo, com acentos e maiúsculas.
  TRUSTED_RANK_NAMES = { "Lorde" },

  -- Horário de Brasília: UTC-3, sem horário de verão desde 2019.
  BRASILIA_OFFSET = -3 * 3600,

  -- Sincronização: esperas aleatórias, em segundos.
  REQUEST_DELAY_MIN = 5,
  REQUEST_DELAY_MAX = 15,
  RESPONSE_DELAY_MIN = 1,
  RESPONSE_DELAY_MAX = 6,

  -- Profissões: espera depois de uma mudança de nível antes de anunciar, em
  -- segundos (vários pontos seguidos viram um anúncio só).
  PROFESSIONS_ANNOUNCE_DELAY = 10,

  -- Item level: espera depois de uma troca de equipamento antes de anunciar,
  -- em segundos (várias peças seguidas viram um anúncio só).
  MEMBERS_ANNOUNCE_DELAY = 10,

  -- Tempo com a guilda: intervalo da contagem e de anúncio do total, em segundos.
  TOGETHER_TICK = 60,
  TOGETHER_ANNOUNCE_INTERVAL = 600,

  -- Alerta de raide.
  ALERT_MAX_CHARS = 200,          -- tamanho máximo do texto, em caracteres
  ALERT_CHAT_PREFIX = "[Alerta] ", -- prefixo da mensagem no chat da guilda
  ALERT_SEND_INTERVAL = 30,       -- espera mínima entre dois envios, em segundos
  ALERT_RECEIVE_INTERVAL = 20,    -- intervalo mínimo aceito do mesmo remetente
  ALERT_DISPLAY_SECONDS = 10,     -- tempo do aviso na tela (faixa própria)
}

return ns.Config
