Ajuste a aplicação do **backup do addon** (`VDLB1`) para uma novidade do addon: **o Grão Lorde e os Lordes agora podem excluir no jogo um evento cancelado**, como o botão "Excluir evento" da administração de eventos do site. Siga o fluxo do projeto: pesquise o código atual, proponha o plano e espere a minha aprovação antes de implementar. Não faça commit nem push sem eu pedir.

## O que mudou no formato

Só um valor novo. O campo 7 dos eventos (`status`) aceita agora `ativo`, `cancelado` **ou `excluido`**. O resto da string `VDLB1` não muda: cabeçalho, ordem dos campos, quantidades e demais seções continuam iguais. Um evento com `excluido` traz os mesmos 11 campos, com os dados que o evento tinha quando foi excluído.

A especificação atualizada está em `../vanguarda-da-luz-addon/docs/formato-string-backup.md`:
- seção "De onde vêm os dados";
- tabela "1. Eventos";
- seção "Como o site deve aplicar um backup › Eventos".

Copie-a de novo para `docs/` do site, para os dois repositórios continuarem iguais. O decodificador do site deve aceitar `excluido` e continuar recusando qualquer outro valor.

## Como o addon trata a exclusão

- O evento sai do calendário e das presenças do addon, mas fica um registro oculto da exclusão, que aguarda o site e vai no backup.
- Enquanto o registro existe, uma `VDL1` que ainda traz o evento com uma versão igual ou mais antiga que a exclusão não o traz de volta.
- O registro sai quando chega uma `VDL1` gerada depois da exclusão **sem o evento**. Por isso o site precisa excluir o documento de verdade.
- Se a `VDL1` trouxer uma versão do site mais nova que a exclusão (por exemplo, evento reativado), ela vale.

## O que o site deve fazer ao aplicar um backup

Para cada evento com `status = excluido`:

1. **O evento existe no site, está cancelado e o `updatedAt` do backup é mais recente que a última alteração do site:**
   - Excluir o evento com a mesma rotina do botão do site (`deleteCancelledEvent` em `src/app/core/data/events.ts`): documento, confirmados, visitantes e cancelamentos.
   - Na prévia e no relatório, isso aparece como **excluir**.
2. **O evento existe no site e está ativo, ou a alteração do site é mais recente:**
   - **Conflito** no relatório, e vale o site. Nada é excluído.
3. **O ID não existe no site** (já excluído, ou criado no jogo e nunca aplicado):
   - Ignorar sem aviso. Pode aparecer na prévia como "já excluído", sem contar como erro.
4. **Presenças do backup para um evento excluído** (neste backup ou antes): ignorar, sem recriar nada.

Ordem: aplique as exclusões depois das criações e edições do mesmo backup e antes das presenças. Assim, um evento criado, cancelado e excluído no jogo antes de chegar ao site não é criado. Se a rotina de exclusão falhar no meio, o relatório mostra o erro e as demais alterações continuam valendo, como já acontece hoje.

`firestore.rules` já permite a um administrador excluir um evento cancelado e as subcoleções. Confira se o caminho do backup usa as mesmas condições e ajuste se precisar.

## Testes e documentação

- **Codificador e decodificador:**
  - ida e volta com um evento `excluido`;
  - um `status` desconhecido continua inválido.
- **Prévia e aplicação, um caso de teste para cada situação:**
  - exclusão de evento cancelado;
  - conflito com evento ativo;
  - conflito com alteração do site mais recente;
  - ID inexistente;
  - presenças de evento excluído ignoradas.
- **Integração:** teste em `tests/integration/` excluindo de verdade o evento e as subcoleções.
- **Critérios de aceite:** atualize `docs/criterios-de-aceite.md` na história "Aplicar backup do addon".
- `npm run check` passando.
