# Vanguarda da Luz: addon para WoW Forever

Calendário de eventos da guilda **Vanguarda da Luz** dentro do World of Warcraft: Forever.

Os eventos são criados no [site da guilda](https://vanguarda-da-luz.web.app/). Para levá-los ao jogo, um administrador gera uma string em **Exportar para o addon** e a importa no addon. Depois disso:

- o addon mostra os eventos num calendário próprio;
- a exportação é enviada aos membros da guilda pelo canal de addons;
- os membros confirmam presença nos eventos dentro do jogo, e as presenças voltam ao site por outra string;
- todos os membros veem as profissões primárias e o nível de cada membro, com um botão para sussurrar.

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
| `/vdl` | Abre a janela do addon no Início, ou fecha se estiver aberta |
| `/vdl importar` | Abre o modal para colar a string do site |
| `/vdl sincronizar` | Pergunta à guilda qual é a exportação mais recente |
| `/vdl presencas` | Gera a string de presenças para colar no site (Grão Lorde e Lordes) |
| `/vdl profissoes` | Abre e fecha a lista de profissões dos membros |
| `/vdl alerta [texto]` | Envia um alerta de raide à guilda. Sem texto, abre o modal do alerta (Grão Lorde e Lordes) |
| `/vdl minimapa` | Mostra ou esconde o botão no minimapa |
| `/vdl ajuda` | Lista os comandos |

O botão no minimapa e a entrada no compartimento de addons também abrem a janela no Início. Com o clique direito, abrem a importação.

A janela tem as abas **Início**, **Eventos**, **Profissões** e **Administração** (só Grão Lorde e Lordes). O rodapé mostra a última exportação recebida, o estado da sincronização e o botão **Sincronizar**.

Na janela **Guilda e comunidades** do jogo (J), com a guilda selecionada, o addon acrescenta três botões abaixo dos botões laterais da Blizzard: **Eventos**, **Profissões** e **Administração** (só Grão Lorde e Lordes).

## Permissões

| Ação | Quem pode |
| --- | --- |
| Ver o calendário do addon | Membros da guilda **Vanguarda da Luz** (`GUILD_NAME` em `core/Config.lua`) |
| Fora da guilda (sem guilda ou em outra) | Só a janela de boas-vindas, com o logo, o nome da guilda e o link do Discord (`DISCORD_URL`) para copiar. O addon não sincroniza nem recebe alertas |
| Importar uma string | Qualquer membro. A importação só atualiza o próprio calendário do addon. |
| Enviar a exportação à guilda | Cargos aceitos (`TRUSTED_MAX_RANK_INDEX` e `TRUSTED_RANK_NAMES` em [`core/Config.lua`](VanguardaDaLuz/core/Config.lua)). Hoje são o **Grão Lorde** (Mestre da Guilda, aceito pelo índice 0, mesmo que o cargo seja renomeado) e o **Lorde** (aceito pelo nome, que precisa ser idêntico ao do jogo). |
| Receber dados da guilda | Os membros só aceitam dados de remetentes com cargo aceito, conferido no roster da guilda |
| Confirmar ou cancelar presença | Qualquer membro, com o personagem logado, em eventos ativos que não começaram |
| Exportar presenças para o site | Cargos aceitos (Grão Lorde e Lorde) |
| Ver as profissões e sussurrar | Qualquer membro |
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
| `P\|<evento>\|<1 ou 0>\|<horário>` | Presença do próprio remetente: confirmada (1) ou cancelada (0) |
| `R` | Pedido das presenças conhecidas, enviado junto com o `Q` |
| `L\|<VDLP1>` | Presenças conhecidas, numa string `VDLP1` |
| `F\|<horário>\|<lista>` | Profissões primárias e níveis do próprio remetente |
| `G` | Pedido dos níveis de profissão conhecidos, enviado junto com o `Q` |
| `K\|<lista>` | Níveis de profissão conhecidos de todos os membros |

- Só responde quem tem cargo aceito e dados mais novos. A resposta sai depois de uma espera aleatória de 1 a 6 s e é cancelada se outro remetente avisar (`H`) ou enviar (`D`) a mesma exportação ou uma mais nova.
- Ao confirmar uma importação, um Grão Lorde ou Lorde envia a exportação à guilda na hora.
- Os membros aplicam as mesmas validações e regras, ignoram dados antigos e só atualizam o calendário do addon.
- Durante encontros de chefe, M+ e partidas JxJ, a comunicação de addons fica bloqueada. Nesse caso, os envios esperam o fim do bloqueio. Um envio interrompido é refeito por inteiro.
- **Tempo de envio:** o servidor permite cerca de 1 mensagem de 255 bytes por segundo por prefixo. Uma exportação típica de 60 dias leva alguns segundos. O máximo de 30.000 caracteres leva cerca de 2 minutos.

### Início

A janela do addon abre sempre no Início, com:

- **Mensagem do dia** (`GetGuildRosterMOTD`) e **Informações da guilda** (`GetGuildInfoText`), atualizadas quando a guilda muda (`GUILD_MOTD` e `GUILD_ROSTER_UPDATE`);
- os links desses textos (`http://`, `https://` e `www.`) em azul. O jogo não deixa um addon copiar para a área de transferência, então o clique no link põe o link numa caixa já selecionada, para o Ctrl+C. Os links são hyperlinks do próprio addon (`|Hvdlurl:…|h`); se o jogo não aceitar hyperlinks no quadro, a caixa já mostra o primeiro link das informações;
- **Próximo evento** ativo, com o horário de Brasília, quantos confirmaram no jogo e o botão **Ver no calendário**, que abre a aba Eventos nesse dia;
- **Guilda**: total de membros, quantos estão online e o personagem com que você está jogando.

### Lista de presença

No detalhe de um evento ativo que ainda não começou, o botão **Confirmar presença** (ou **Cancelar presença**) registra o personagem logado. O detalhe mostra "Confirmados no jogo (N)" com os nomes.

- Esta lista é do jogo e não mostra as presenças do site, porque a string `VDL1` não traz a lista de confirmados nem o limite de vagas.
- Cada membro anuncia só a própria presença (`P`), e o jogo garante quem é o remetente.
- Ao entrar no jogo ou em **Sincronizar**, o addon pede as presenças (`R`), e qualquer membro online responde com a lista que conhece (`L`), depois de uma espera aleatória. Em cada personagem e evento vale a resposta mais recente.
- Presenças de eventos que o addon não tem mais são apagadas.
- O Grão Lorde e os Lordes geram em **Administração** > **Gerar string** (ou `/vdl presencas`) a string `VDLP1`, com as confirmações e os cancelamentos dos eventos que ainda não começaram, para um administrador colar no site. Formato: [`docs/formato-string-presencas.md`](docs/formato-string-presencas.md).

### Profissões

A aba **Profissões** da janela (ou `/vdl profissoes`, que abre uma janela só com a lista) abre a lista dos membros da guilda com as profissões primárias e o nível, para todos os membros.

- Quem é membro, quais profissões tem e se está online vem da lista da guilda do jogo (`C_Club`). Ela traz as profissões de todos, mesmo sem o addon, mas no WoW Forever o nível vem sempre 1.
- Por isso o nível vem do addon de cada membro: ele lê as próprias profissões (`GetProfessions` e `GetProfessionInfo`) e anuncia (`F`) ao entrar no jogo e quando um nível muda (`SKILL_LINES_CHANGED`, 10 s depois, juntando vários pontos num envio). Só anuncia se algo mudou desde o último anúncio.
- Ao entrar no jogo ou em **Sincronizar**, o addon pede os níveis (`G`), e qualquer membro online responde com os que conhece (`K`), depois de uma espera aleatória. Em cada personagem vale a leitura mais recente. Níveis de quem saiu da guilda são apagados.
- Quem não tem o addon aparece com o nível como "—".
- Filtros: profissão (com a profissão escolhida, a lista fica do maior nível para o menor) e **Mostrar**, que começa em "só online" e alterna para "todos".
- **Sussurrar** abre o chat com `/w <Nome Sobrenome>`. Fica desativado para quem está offline e não aparece na linha do próprio jogador.

### Abas na janela da guilda

O addon espera a janela "Guilda e comunidades" carregar (`Blizzard_Communities`) e põe três botões abaixo do botão de Informações da guilda, com o mesmo espaçamento dos botões da Blizzard. Os nomes dos quadros da Blizzard ficam em `Flavor.guildWindow`.

- **Eventos:** o calendário num layout compacto (células com o número do dia, o marcador e a quantidade de eventos), com a lista do dia, o detalhe e a presença.
- **Profissões:** a mesma lista da janela Profissões.
- **Administração:** estado da sincronização e cartões para importar a string, exportar as presenças e enviar o alerta (abrem os mesmos modais da janela do addon).
- Os botões só aparecem com a guilda Vanguarda da Luz selecionada (junto com o botão de Informações da guilda) e com a janela no tamanho normal (não minimizada).
- O painel do addon fica por cima da área de conteúdo. O addon não esconde nem altera os quadros da Blizzard: só acrescenta os botões e "escuta" os cliques nos botões dela (`HookScript`), que fecham o painel.

### Alerta de raide

O Grão Lorde ou um Lorde envia um alerta com `/vdl alerta <texto>` ou em **Administração** > **Enviar alerta** na janela, aba que só aparece para esses cargos.

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
           Time (fusos), Protocol (mensagens), Trust (cargos), Text (UTF-8 e links), Alert (alerta de raide),
           Attendance e PresenceCodec (lista de presença e string VDLP1), Professions
  game/    Store (SavedVariables), Guild, Comm (AceComm), Warning (alerta de raide),
           Presence (lista de presença), GuildProfessions (profissões)
  ui/      Theme (identidade do site), painéis reaproveitáveis HomePanel, CalendarPanel, ProfessionsPanel e AdminPanel,
           MainFrame, ImportDialog, AlertBanner, AlertDialog, WelcomeFrame, PresenceExport,
           ProfessionsFrame, GuildTabs (abas na janela da guilda), MinimapButton
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
  attendance = { [idDoSite] = { ["Nome Sobrenome"] = { s = 1|0, t = horário } } },
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
5. Sussurrar para `"Nome Sobrenome"` (com espaço) pelo `ChatFrame_SendTell` chega ao personagem, e `Enum.ClubMemberPresence` marca online/ausente/ocupado como no Retail.
6. `RaidNotice_AddMessage(RaidWarningFrame, …)` mostra o alerta no centro da tela, e `C_ChatInfo.SendChatMessage(…, "GUILD")` publica no chat da guilda sem clique. Se o quadro não existir, aparece a faixa própria.

### Administrador

1. `/vdl` abre a janela e `/vdl` de novo fecha. O botão no minimapa e o compartimento de addons fazem o mesmo.
2. `/vdl importar`: cole `abc` e clique em **Validar**. Deve aparecer o erro de prefixo.
3. Cole o conteúdo de `docs/exemplos-addon/corrompida.txt` e clique em **Validar**. Deve aparecer o erro de string incompleta ou corrompida.
4. No site, gere uma exportação real, cole e clique em **Validar**. Confira o resumo e clique em **Confirmar importação**.
5. Os eventos aparecem no calendário do addon. Os cancelados aparecem como "Cancelado". O cabeçalho mostra quando os dados foram gerados e recebidos.
6. Importe a mesma string de novo. Deve aparecer o aviso de exportação antiga.
7. No site, edite um evento, cancele outro e exclua um terceiro, que precisa estar cancelado antes. Exporte e importe. O resumo deve mostrar 1 alterado, 1 cancelado e 1 removido, e o calendário do addon deve refletir as três mudanças.
8. O calendário da Blizzard não muda.

### Início

1. Clique no botão do minimapa: a janela abre no **Início**, com a mensagem do dia e as informações da guilda iguais às da janela da guilda (J).
2. Clique no link `https://vanguarda-da-luz.web.app` das informações: a caixa abaixo mostra o link selecionado, e Ctrl+C copia. Passar o mouse no link mostra "Clique para copiar o link".
3. **Próximo evento** mostra o evento futuro mais próximo. **Ver no calendário** abre a aba Eventos com o dia e o evento selecionados.
4. Mude a mensagem do dia na janela da guilda: o Início atualiza.
5. Feche e abra a janela em outra aba: ela volta ao Início.

### Lista de presença

1. Com o Lorde e o membro online, o membro abre um evento futuro e clica em **Confirmar presença**. Os dois veem o nome dele em "Confirmados no jogo".
2. O membro clica em **Cancelar presença**: o nome sai da lista nos dois.
3. Com o Lorde offline, o membro confirma presença. O Lorde entra no jogo e, em alguns segundos, vê a confirmação.
4. O Lorde clica em **Administração** > **Gerar string**: a string `VDLP1` aparece selecionada, com o resumo de eventos, confirmações e cancelamentos.
5. Eventos cancelados ou que já começaram não mostram o botão de presença.

### Profissões

1. Abra **Profissões** com o Lorde e o membro online, os dois com o addon. Cada um vê as próprias profissões com o nível (por exemplo, "Ferraria 88/150") e as do outro em poucos segundos.
2. Membros sem o addon aparecem com as profissões e o nível "—". A contagem de membros bate com a janela da guilda.
3. Suba um ponto de profissão no membro. Cerca de 10 s depois, o Lorde vê o nível novo.
4. Com o membro offline, o Lorde sai e entra no jogo: o nível do membro continua aparecendo (repasse `K`, ou SavedVariables).
5. Filtre por uma profissão: só aparece quem a tem, do maior nível para o menor. A lista abre só com os online; **Mostrar: só online** alterna para todos e de volta.
6. **Sussurrar** num membro online abre o chat com `/w Nome Sobrenome` e a mensagem chega a ele. Para offline, o botão fica desativado.

### Abas na janela da guilda

1. Abra a janela da guilda (J) com a guilda selecionada. Abaixo dos 4 botões laterais aparecem **Eventos** e **Profissões** e, no Lorde, **Administração**. Os botões têm a mesma moldura dos da Blizzard e mostram o nome ao passar o mouse. No membro comum, **Administração** não aparece.
2. **Eventos** mostra o calendário compacto: dá para trocar o mês, escolher o dia, ver o detalhe e confirmar presença. O conteúdo da Blizzard não aparece por baixo.
3. **Profissões** mostra a lista, com filtro e Sussurrar.
4. **Administração**: **Importar**, **Gerar string** e **Enviar alerta** abrem os modais por cima da janela da guilda.
5. Clique em Chat ou Membros: o painel do addon some e o conteúdo da Blizzard volta, com o botão certo marcado.
6. Selecione outra comunidade na lista da esquerda: os botões do addon somem. Volte à guilda: eles voltam.
7. Minimize a janela da guilda: os botões do addon somem.
8. Feche e abra a janela, troque de aba várias vezes e entre em combate com a janela aberta: não deve aparecer o erro "ação bloqueada" (`/console taintLog 1` registra a causa, se aparecer).
9. Os ícones de ferraria e de chave aparecem. Se aparecer um quadrado verde, o ícone não existe no WoW Forever e precisa ser trocado em `Flavor.guildWindow.icons`.

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
3. No membro, `/vdl alerta teste`: deve aparecer que só o Grão Lorde e os Lordes podem enviar. A aba **Administração** não aparece na janela do membro.
4. Num encontro de chefe, tente enviar: deve aparecer o aviso de comunicação restrita, e nada é publicado.
5. Um membro que entra depois do alerta não o vê.
