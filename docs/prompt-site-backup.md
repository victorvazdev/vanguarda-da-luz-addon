Implemente no site a **área administrativa de backup do addon** da guilda (string `VDLB1`). Siga o fluxo do projeto: pesquise o código atual, proponha o plano e espere a minha aprovação antes de implementar. Não faça commit nem push sem eu pedir.

## Contexto

O addon da guilda no WoW Forever (versão 0.4.0) agora gera um **backup** com os dados que só existem no jogo. Como o addon não acessa a internet, o Grão Lorde ou um Lorde gera no jogo uma string `VDLB1:...`, e um administrador do site a cola numa tela nova da administração. O site:

1. **aplica** os eventos criados, editados ou cancelados no jogo e as presenças;
2. **guarda** a string e os demais dados (profissões, item level e main, tempo jogado junto);
3. **devolve** uma string `VDLB1` para restaurar esses dados no jogo.

Isso fecha o ciclo com as strings que já existem:
- a `VDL1` (`core/data/addon-format.ts`, "Exportar para o addon");
- a `VDLP1` (`core/data/addon-presence-format.ts` e `presence-import*`, "Importar presenças").

Os eventos criados no jogo têm um ID de 20 letras e dígitos gerado pelo addon, no mesmo formato dos IDs do Firestore. **O site deve criar o evento usando esse ID como ID do documento.** Assim, quando o evento volta na próxima `VDL1`, o addon o reconhece, sem duplicar e sem tabela de ligação.

A especificação completa está no repositório do addon:
- `../vanguarda-da-luz-addon/docs/formato-string-backup.md`;
- o exemplo `../vanguarda-da-luz-addon/docs/exemplos-addon/backup.txt`;
- o resultado esperado `backup-esperado.lua`;
- o payload descompactado `backup-payload.txt`.

Leia esses arquivos primeiro. Copie a especificação e os exemplos para `docs/` e `docs/exemplos-addon/` do site, como já é feito com `formato-string-addon.md` e `formato-string-presencas.md`, e mantenha os dois repositórios iguais.

Resumo do formato: `VDLB1:<adler32 decimal>:<EncodeForPrint(deflate_bruto(payload))>`, com campos `<bytes>:<valor>`, igual à `VDL1` e à `VDLP1`. Reaproveite o código de `addon-format.ts`. O payload tem:

- **cabeçalho:** `VDLB`, `1`, `game`, `generatedAt`, `exportNumber`, `generatedBy`;
- **eventos** (11 campos): `id`, `origin` (`jogo` ou `site`), `title`, `startsAt`, `description`, `organizer`, `status`, `updatedAt`, `maxAttendees` (0 = sem alteração), `guestsAllowed` (`1`, `0` ou vazio = sem alteração) e `changedBy`;
- **presenças:** mesmo corpo da `VDLP1`;
- **profissões:** personagem, `updatedAt`, quantidade; por profissão: `id` (0 = desconhecido), `level`, `max`, `name`;
- **item level e main:** personagem, `updatedAt`, `itemLevel`, `main`;
- **tempo junto:** personagem, `seconds`.

## Regras decididas pela guilda

1. **Eventos criados no jogo** (`origin = jogo`, ID inexistente no site):
   - Criar com o ID da string, `game = forever` e os campos da string.
   - `maxAttendees` e `guestsAllowed` vêm preenchidos nos criados no jogo. Se vierem sem valor, use os padrões atuais (40 e sim).
   - Um evento que chega já cancelado e nunca existiu no site é ignorado, com aviso no relatório.
2. **Eventos que já existem no site** (`origin = site`, ou `jogo` já criado num backup anterior):
   - Vale a alteração mais recente. Aplique só se `updatedAt` for mais novo que a última alteração do evento no site. Se não for, mostre **conflito** no relatório e mantenha o site.
   - `maxAttendees = 0` e `guestsAllowed` vazio mantêm os valores do site.
   - Continuam valendo as regras atuais de edição e cancelamento: só eventos ativos que ainda não começaram, limite de vagas não abaixo dos confirmados, versão do jogo travada com confirmados, e as demais. Uma alteração que violaria uma delas não é aplicada e aparece no relatório com o motivo.
   - Um evento do site que foi **excluído** e chega editado no backup (`origin = site`, ID inexistente) é ignorado, com aviso no relatório. A exclusão vale: a próxima `VDL1`, sem o evento, também o remove no addon.
   - Ao aplicar, grave o `updatedAt` do site normalmente (`serverTimestamp`). Ele fica maior que o do jogo, e é isso que tira a marca "aguardando o site" no addon quando o evento volta na `VDL1`.
3. **Presenças:** as mesmas regras da importação da `VDLP1` (`presence-import-plan.ts`). As presenças de eventos criados neste backup são aplicadas depois da criação deles.
4. **Profissões, item level, main e tempo junto:** não alteram nada no site. São guardados como backup, **visíveis só para administradores**.
5. **Histórico:**
   - Guarde cada backup aplicado: string original, `generatedAt`, `generatedBy`, quem aplicou e quando, e o relatório.
   - Mantenha também um **estado combinado** com o registro mais recente de cada personagem (pelo `updatedAt`) e o maior tempo junto.
   - Aplicar o mesmo backup duas vezes não muda nada.
   - Um backup com `generatedAt` menor ou igual ao último aplicado é aceito com aviso, porque cada Lorde conhece o que o próprio addon recebeu.
6. **Restauração (site → addon):**
   - Um botão **"Copiar string para restaurar"** gera uma `VDLB1` a partir do estado combinado: profissões, item level e main, tempo junto, e as presenças dos backups guardados.
   - Ela vai **sem eventos**, porque os eventos voltam pela `VDL1`. `generatedAt` é o agora, `exportNumber` é o da última `VDL1` gerada (ou 0), e `generatedBy` é vazio.
   - Cada backup do histórico também permite copiar a string original.
   - No jogo, a restauração só junta dados mais novos e nunca apaga.
7. **Quem usa:** só administradores, verificado em `firestore.rules`.

## O que entregar

- **Codificador e decodificador `VDLB1`**, sem dependências de framework, ao lado de `addon-format.ts`.
  - Testes unitários com os exemplos copiados do addon: ida e volta byte a byte com `backup.txt` e `backup-payload.txt`, incluindo nomes com acentos (`Árya Ñúñez` tem 14 bytes; `Mineração` tem 11).
  - Testes dos casos inválidos da especificação.
- **Uma tela na administração**, ao lado de "Importar presenças", por exemplo `admin/eventos/backup-addon`, para colar a string:
  - validar;
  - mostrar uma prévia por evento: criar, alterar, cancelar, conflito ou recusado, com o motivo;
  - mostrar a prévia das presenças, como na importação da `VDLP1`, e as quantidades de profissões, item levels e tempos;
  - confirmar.
- **A aplicação no Firestore**, no navegador (o projeto não tem Cloud Functions):
  - transações ou batches que respeitem o limite de vagas, como nas confirmações normais;
  - criação de evento com ID definido (`setDoc` em `doc(db, 'events', id)`), conferindo que o ID ainda não existe dentro da transação.
- **Uma página de histórico, só para administradores:**
  - a lista de backups aplicados, com o relatório;
  - tabelas do estado combinado, com filtro por nome: profissões e níveis, item level e main/alt, tempo jogado junto (somando os alts no main, como o addon);
  - o botão de restauração.
- **`firestore.rules`** permitindo a um administrador:
  - criar evento com ID escolhido;
  - aplicar as alterações;
  - gravar o histórico e o estado combinado.

  Ninguém além de administradores lê esses dados. Inclua testes em `tests/rules/` e testes de integração em `tests/integration/`.
- **Atualização de `docs/criterios-de-aceite.md`** com as histórias "Aplicar backup do addon", "Ver dados do addon" e "Restaurar dados no addon", e `npm run check` passando.

Pontos que você deve levantar comigo na proposta, se o código atual não responder:

- como marcar a origem "jogo" num evento criado pelo backup (por exemplo, `createdBy` do administrador que aplicou mais `source: 'addon'` e `changedBy` com o personagem), e se isso aparece para os membros;
- como modelar o histórico e o estado combinado no Firestore (coleções, tamanho dos documentos com o limite de 1 MiB, quantas versões manter);
- se a string de restauração deve incluir presenças de eventos já passados, que só servem de histórico no jogo.
