Implemente no site a **importação de presenças vindas do addon** da guilda (string `VDLP1`), seguindo o fluxo do projeto: pesquise o código atual, proponha o plano e espere a minha aprovação antes de implementar. Não faça commit nem push sem eu pedir.

## Contexto

O addon da guilda no WoW Forever ganhou uma lista de presença: os membros confirmam ou cancelam a presença nos eventos dentro do jogo, e o addon sincroniza isso entre eles. Como o addon não acessa a internet, o Grão Lorde ou um Lorde gera no jogo uma string `VDLP1:...` com as presenças, e um administrador do site a cola numa tela nova da administração de eventos. É o caminho inverso da string `VDL1` que o site já gera em "Exportar para o addon" (`core/data/addon-format.ts`).

A especificação completa do formato está no repositório do addon, em `../vanguarda-da-luz-addon/docs/formato-string-presencas.md`, com o exemplo `../vanguarda-da-luz-addon/docs/exemplos-addon/presencas.txt` e o resultado esperado `presencas-esperado.lua`. Leia esses arquivos primeiro. Copie a especificação e os exemplos para `docs/` e `docs/exemplos-addon/` do site, como já é feito com `formato-string-addon.md`, e mantenha os dois repositórios iguais.

Resumo do formato: `VDLP1:<adler32 decimal>:<EncodeForPrint(deflate_bruto(payload))>`. Compactação, codificação imprimível, checksum e codificação de campos `<bytes>:<valor>` são idênticos aos da `VDL1`, então reaproveite o código de `addon-format.ts`. O payload tem:

- cabeçalho: `VDLP`, `1`, `game`, `generatedAt`, `exportNumber`, `eventCount`;
- por evento: `id` do site e `recordCount`;
- por registro: `character` (`"Nome Sobrenome"`), `status` (`1` confirmado, `0` cancelado) e `updatedAt` (segundos Unix).

## Regras decididas pela guilda

1. **Associação:** compare `character` com o nome e o sobrenome dos personagens do WoW Forever cadastrados pelos membros (normalize espaços e maiúsculas, sem tirar acentos). Havendo correspondência, a presença é do membro dono do personagem, confirmada com aquele personagem.
2. **Sem membro correspondente:** a presença entra como **visitante**, com o nome e o sobrenome do personagem. Use o modelo de presença de visitante que já existe (`guest-attendance.ts`).
3. **Limite de vagas e duplicidade:** continuam valendo as regras atuais. Membros e visitantes somam no mesmo limite, o mesmo personagem não confirma duas vezes e o membro não tem duas presenças no evento. Uma confirmação que violaria essas regras não é aplicada e aparece no relatório.
4. **Cancelamento:** `status = 0` cancela no site a presença daquele personagem no evento, seja de membro ou de visitante. Assim, quem cancela no jogo tem a presença cancelada no site quando uma string nova for importada.
5. **Ordem:** aplique um registro só se o seu `updatedAt` for mais recente que a última alteração daquela presença no site, para uma alteração feita no site depois não ser desfeita por um dado mais antigo do jogo. Recuse strings com `generatedAt` menor ou igual ao da última string de presenças importada.
6. **Eventos:** ignore, com aviso no relatório, eventos desconhecidos, passados, cancelados ou que não são do WoW Forever.
7. **Quem importa:** só administradores, verificado em `firestore.rules`.

## O que entregar

- Um decodificador `VDLP1` sem dependências de framework, ao lado de `addon-format.ts`, com testes unitários que usem os exemplos copiados do addon (incluindo o nome com acentos `Árya Ñúñez`, que tem 14 bytes).
- Uma tela na administração de eventos para colar a string: validar, mostrar uma prévia do que vai mudar por evento (confirmações de membros, de visitantes, cancelamentos e itens recusados, com o motivo) e confirmar.
- A aplicação no Firestore, no navegador (o projeto não tem Cloud Functions): transações ou batches que respeitem o limite de vagas mesmo com confirmações simultâneas, como as confirmações normais.
- `firestore.rules` permitindo que um administrador crie e cancele presenças de membros e de visitantes em nome deles, com testes em `tests/rules/`, e testes de integração em `tests/integration/`.
- Registro da última string de presenças importada (`generatedAt`) para recusar strings antigas.
- Atualização de `docs/criterios-de-aceite.md` com uma história nova, "Importar presenças do addon", e `npm run check` passando.

Pontos que você deve levantar comigo na proposta, se o código atual não responder:
- como marcar a origem "addon" numa presença;
- o que mostrar ao membro quando a presença dele vier do jogo;
- como tratar dois membros com personagens de mesmo nome e sobrenome em rulesets diferentes, já que a string não traz o ruleset.
