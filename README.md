# Vanguarda da Luz: addon para WoW Forever

Calendário de eventos da guilda **Vanguarda da Luz** dentro do World of Warcraft: Forever.

Os eventos são criados no [site da guilda](https://vanguarda-da-luz.web.app/). Para levá-los ao jogo, um administrador gera uma string em **Exportar para o addon** e a importa no addon. Depois disso:

- o addon mostra os eventos num calendário próprio;
- a exportação é enviada aos membros da guilda pelo canal de addons.

## Instalação

1. Baixe `VanguardaDaLuz-<versão>.zip`, que pode vir do artefato do GitHub Actions ou ser gerado com `scripts/package.sh`.
2. Extraia o arquivo na pasta de addons do WoW Forever:
   - Windows: `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\`
   - macOS: `/Applications/World of Warcraft/_forever_/Interface/AddOns/`
3. Confira se existe a pasta `AddOns/VanguardaDaLuz/` com o arquivo `VanguardaDaLuz_Forever.toc` dentro.
4. No jogo, ative **Vanguarda da Luz** na lista de addons.

## Comandos

| Comando | O que faz |
| --- | --- |
| `/vdl` | Abre e fecha o calendário |
| `/vdl importar` | Abre o modal para colar a string do site |
| `/vdl sincronizar` | Pergunta à guilda qual é a exportação mais recente |
| `/vdl alerta [texto]` | Envia um alerta de raide à guilda. Sem texto, abre o modal do alerta (Grão Lorde e Lordes) |
| `/vdl minimapa` | Mostra ou esconde o botão no minimapa |
| `/vdl ajuda` | Lista os comandos |

O botão no minimapa e a entrada no compartimento de addons também abrem o calendário. Com o clique direito, abrem a importação.

## Permissões

| Ação | Quem pode |
| --- | --- |
| Ver o calendário do addon | Membros da guilda **Vanguarda da Luz** (`GUILD_NAME` em `core/Config.lua`) |
| Fora da guilda (sem guilda ou em outra) | Só a janela de boas-vindas, com o logo, o nome da guilda e o link do Discord (`DISCORD_URL`) para copiar. O addon não sincroniza nem recebe alertas |
| Importar uma string | Qualquer membro. A importação só atualiza o próprio calendário do addon. |
| Enviar a exportação à guilda | Cargos aceitos (`TRUSTED_MAX_RANK_INDEX` e `TRUSTED_RANK_NAMES` em [`core/Config.lua`](VanguardaDaLuz/core/Config.lua)). Hoje são o **Grão Lorde** (Mestre da Guilda, aceito pelo índice 0, mesmo que o cargo seja renomeado) e o **Lorde** (aceito pelo nome, que precisa ser idêntico ao do jogo). |
| Receber dados da guilda | Os membros só aceitam dados de remetentes com cargo aceito, conferido no roster da guilda |
| Enviar alerta de raide | Cargos aceitos (Grão Lorde e Lorde). Os membros só mostram alertas de remetentes com cargo aceito |

Contas trial e veteranas do WoW Forever não podem enviar mensagens de addon nem criar eventos no calendário.

Para mudar os cargos aceitos, edite `TRUSTED_MAX_RANK_INDEX` e `TRUSTED_RANK_NAMES` em `core/Config.lua` e distribua a nova versão a todos os membros.

## Como funciona

### Importação

`/vdl importar` → colar a string → **Validar** → conferir o resumo → **Confirmar importação**.

Antes de alterar qualquer dado, a validação confere:

- tamanho (até 30.000 caracteres);
- prefixo e versão do formato;
- codificação, compactação e Adler-32;
- estrutura dos campos;
- versão do jogo (só `forever`);
- se a exportação é mais nova que a última importada.

O resumo mostra os eventos novos, alterados, cancelados e removidos. Também mostra quantos ficaram sem alteração e quantos estão fora da janela.

A exportação é um **retrato completo** da janela de datas, seguindo [`docs/formato-string-addon.md`](docs/formato-string-addon.md):

| Situação | Resultado |
| --- | --- |
| Evento novo | Criado |
| Evento com `updatedAt` maior | Atualizado |
| Evento com situação `cancelado` | Marcado como cancelado |
| Evento salvo, dentro da janela, que não veio na exportação | Removido (foi excluído no site ou mudou para fora da janela) |
| Evento fora da janela | Mantido sem alteração |

### Calendário do jogo

O addon **não altera o calendário da Blizzard**. No WoW Forever, `C_Calendar.AddEvent()` é bloqueada para addons ("A ação falhou devido a um AddOn"), mesmo a partir de um clique ou de `/run`. Os eventos ficam só no calendário do addon. Quem quiser um anúncio no calendário do jogo precisa criá-lo à mão.

### Sincronização com a guilda

As mensagens usam o canal `GUILD` com o prefixo `VanguardaDaLuz`. A AceComm divide as mensagens grandes em partes, e a ChatThrottleLib controla o ritmo de envio.

| Mensagem | Significado |
| --- | --- |
| `Q\|<n>` | Pedido enviado ao entrar no jogo (após 5 a 15 s): "alguém tem uma exportação mais nova que `<n>`?" |
| `H\|<n>` | Aviso de que a exportação `<n>` vai ser enviada |
| `D\|<n>\|<string>` | A string original da exportação, para cada membro conferir o Adler-32 do site |
| `A\|<id>\|<texto>` | Alerta de raide (ver abaixo) |

- Só responde quem tem cargo aceito e dados mais novos. A resposta sai depois de uma espera aleatória de 1 a 6 s e é cancelada se outro remetente avisar (`H`) ou enviar (`D`) a mesma exportação ou uma mais nova.
- Ao confirmar uma importação, um Grão Lorde ou Lorde envia a exportação à guilda na hora.
- Os membros aplicam as mesmas validações e regras, ignoram dados antigos e só atualizam o calendário do addon.
- Durante encontros de chefe, M+ e partidas JxJ, a comunicação de addons fica bloqueada. Nesse caso, os envios esperam o fim do bloqueio. Um envio interrompido é refeito por inteiro.
- **Tempo de envio:** o servidor permite cerca de 1 mensagem de 255 bytes por segundo por prefixo. Uma exportação típica de 60 dias leva alguns segundos. O máximo de 30.000 caracteres leva cerca de 2 minutos.

### Alerta de raide

O Grão Lorde ou um Lorde envia um alerta com `/vdl alerta <texto>` ou pelo botão **Alerta** da janela, que só aparece para esses cargos.

- O texto vira uma linha só, sem `|`, com até 200 caracteres (e até 255 bytes com o prefixo no chat).
- O remetente envia a mensagem de addon `A|<id>|<texto>` pelo canal `GUILD` com prioridade `ALERT` e publica uma vez no chat da guilda: `[Alerta] <texto>`. Quem não tem o addon vê só essa linha.
- Quem tem o addon confere o cargo do remetente e mostra `<remetente>: <texto>` no centro da tela, no quadro do aviso de raide (`RaidNotice_AddMessage`), com o som padrão do aviso de raide, que não pode ser desativado. Se o quadro não existir, o addon usa uma faixa própria por 10 s.
- O alerta vale só para quem está online: não fica salvo nem é reenviado.
- Intervalo mínimo de 30 s entre envios. Quem recebe ignora IDs repetidos e alertas do mesmo remetente com menos de 20 s.
- Durante a restrição de comunicação (encontros de chefe, M+ e JxJ), o envio é recusado com um aviso, porque um alerta atrasado perde o sentido.

### Horários

Os horários do addon estão em **Brasília** (UTC−3). Quando o horário do servidor é diferente, ele aparece ao lado com o fuso (por exemplo, `UTC-8`). O horário do servidor é calculado com `C_DateAndTime.GetCurrentCalendarTime()` e `GetServerTime()`.

## Estrutura

```
VanguardaDaLuz/                  addon (vai para a pasta AddOns)
  VanguardaDaLuz_Forever.toc     Interface 16001
  core/    Init, Config, Flavor_Forever (o que depende da versão do jogo), Main (eventos e comandos)
  logic/   lógica pura, testada fora do jogo:
           Codec (string), Snapshot (retrato completo), Import,
           Time (fusos), Protocol (mensagens), Trust (cargos), Text (UTF-8), Alert (alerta de raide)
  game/    Store (SavedVariables), Guild, Comm (AceComm), Warning (alerta de raide)
  ui/      Theme (identidade do site), MainFrame, ImportDialog, AlertBanner, AlertDialog, WelcomeFrame,
           MinimapButton
  libs/    bibliotecas externas (ver libs/LIBRARIES.md)
  assets/  logo
  fonts/   Cinzel e Source Sans 3 (OFL)
assets/    logo original do site
docs/      formato da string, critérios de aceite e exemplos
tests/     testes busted (Lua 5.1) e teste de fumaça com a API do jogo simulada
scripts/   setup-dev.sh, check.sh, package.sh
```

### SavedVariables

`VanguardaDaLuzDB` é salvo por conta:

```lua
{
  schema = 1,
  export = { raw, exportNumber, windowStart, windowEnd, count, receivedAt, source, sender },
  events = { [idDoSite] = { id, title, startsAt, description, organizer, status, updatedAt } },
  settings = { minimap = { angle, hide } },
}
```

A chave `game`, usada por versões anteriores para ligar os eventos ao calendário do jogo, é apagada ao carregar.

### Versão Retail (futuro)

O que depende da versão do jogo fica em `core/Flavor_Forever.lua` e no `.toc`:

- número de Interface;
- valor de `game` aceito na string;
- detecção do bloqueio de mensagens;
- chat da guilda, aviso de raide e som.

Uma versão Retail teria um `Flavor_Retail.lua` e um `VanguardaDaLuz_Standard.toc`, com o mesmo resto do código.

## Desenvolvimento

Requer Python 3. As ferramentas ficam dentro do projeto (`.venv/` e `.lua/`, ignorados pelo git):

```bash
scripts/setup-dev.sh
```

```bash
scripts/check.sh
```

```bash
scripts/package.sh
```

- `setup-dev.sh` instala Lua 5.1, LuaRocks, busted e luacheck.
- `check.sh` roda o luacheck e os testes.
- `package.sh` gera `dist/VanguardaDaLuz-<versão>.zip`.

O GitHub Actions ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) roda o luacheck, os testes e o pacote a cada push e pull request.

Os testes usam os arquivos de [`docs/exemplos-addon/`](docs/exemplos-addon/). Eles cobrem string corrompida, jogo diferente, exportação antiga, evento cancelado, evento excluído dentro da janela, evento fora da janela, idempotência, limite de tamanho, fusos e protocolo.

## Roteiro de teste no jogo

Use dois personagens na guilda: um Lorde (ou o Grão Lorde) e um membro comum. Os dois precisam do addon.

### Confirmações pendentes

Estes pontos vieram da documentação ou da comunidade e ainda precisam ser confirmados no jogo:

1. `/dump select(4, GetBuildInfo())` mostra `16001`, e o addon aparece na lista sem o aviso "desatualizado".
2. A fonte (Cinzel e Source Sans 3) e o logo (TGA) aparecem na janela.
3. A diferença do horário do servidor está correta. Compare a linha "servidor" do detalhe com o relógio do jogo.
4. A mensagem de addon é adiada num encontro de chefe e enviada depois.
5. `RaidNotice_AddMessage(RaidWarningFrame, …)` mostra o alerta no centro da tela, e `C_ChatInfo.SendChatMessage(…, "GUILD")` publica no chat da guilda sem clique. Se o quadro não existir, aparece a faixa própria.

### Administrador

1. `/vdl` abre a janela e `/vdl` de novo fecha. O botão no minimapa e o compartimento de addons fazem o mesmo.
2. `/vdl importar`: cole `abc` e clique em **Validar**. Deve aparecer o erro de prefixo.
3. Cole o conteúdo de `docs/exemplos-addon/corrompida.txt` e clique em **Validar**. Deve aparecer o erro de string incompleta ou corrompida.
4. No site, gere uma exportação real, cole e clique em **Validar**. Confira o resumo e clique em **Confirmar importação**.
5. Os eventos aparecem no calendário do addon. Os cancelados aparecem como "Cancelado". O cabeçalho mostra quando os dados foram gerados e recebidos.
6. Importe a mesma string de novo. Deve aparecer o aviso de exportação antiga.
7. No site, edite um evento, cancele outro e exclua um terceiro, que precisa estar cancelado antes. Exporte e importe. O resumo deve mostrar 1 alterado, 1 cancelado e 1 removido, e o calendário do addon deve refletir as três mudanças.
8. O calendário da Blizzard não muda.

### Fora da guilda

1. Com um personagem sem guilda, `/vdl`, o botão do minimapa e `/vdl importar` abrem só a janela de boas-vindas, com o link do Discord selecionado. Ctrl+C copia o link.
2. Com um personagem de outra guilda: o mesmo comportamento, e nenhuma mensagem de addon é enviada.

### Membro

1. Com o Lorde online e com dados, entre no jogo com o membro. Em até cerca de 20 s, o calendário do addon do membro recebe os eventos. O cabeçalho diz "Recebido … de <Lorde>".
2. Com os dois online, o Lorde importa uma string nova. O membro recebe sem fazer nada.
3. `/vdl sincronizar` no membro, sem dados novos: nada muda.
4. No membro, `/vdl importar` com uma string mais antiga: deve aparecer o aviso de exportação antiga.
5. Com dois Lordes online, entre com o membro: só um deles deve responder. Para conferir, ative o log de mensagens de addon com `/etrace` ou um addon de debug.
6. Mova temporariamente um personagem para um cargo diferente de Grão Lorde e Lorde e importe com ele uma string mais nova: os membros não devem aceitá-la.
7. Saia e entre no jogo: os eventos continuam no calendário (SavedVariables).

### Alerta de raide

1. No Lorde, `/vdl alerta Raide no Núcleo às 20h | entrem`. O chat da guilda mostra `[Alerta] Raide no Núcleo às 20h / entrem`. O Lorde e o membro veem o aviso no centro da tela e ouvem o som do aviso de raide.
2. Envie outro alerta antes de 30 s: deve aparecer "Aguarde … s".
3. No membro, `/vdl alerta teste`: deve aparecer que só o Grão Lorde e os Lordes podem enviar. O botão **Alerta** não aparece na janela do membro.
4. Num encontro de chefe, tente enviar: deve aparecer o aviso de comunicação restrita, e nada é publicado.
5. Um membro que entra depois do alerta não o vê.
