Ajuste a importação do **backup do addon** (`VDLB1`) para uma mudança de regra no addon: **um evento excluído no site continua excluído, mesmo que tenha sido editado no jogo antes da exclusão.** Siga o fluxo do projeto: pesquise o código atual, proponha o plano e espere a minha aprovação antes de implementar. Não faça commit nem push sem eu pedir.

## O que mudou no addon

Antes, um evento editado no jogo ficava "aguardando o site" e nenhuma `VDL1` o removia. Agora o addon remove esse evento quando todas estas condições valem:

- o evento veio do site (`origin = site`);
- a `VDL1` importada não traz o evento e tem `exportNumber` (horário de geração) **maior** que o `updatedAt` da alteração feita no jogo;
- o início do evento está dentro da janela da exportação.

Isso significa que o site excluiu o evento depois da alteração. O addon também recusa essa alteração quando ela chega por mensagem de outro membro da guilda, para o evento não voltar. Eventos criados no jogo (`origin = jogo`) continuam sendo mantidos até o backup ser aplicado.

O formato da string **não mudou**. A especificação atualizada está em `../vanguarda-da-luz-addon/docs/formato-string-backup.md`, nas seções "De onde vêm os dados" e "Como o site deve aplicar um backup › Eventos". Copie-a de novo para `docs/` do site, para os dois repositórios continuarem iguais.

## O que o site deve fazer

1. **Aplicar o backup:** um evento com `origin = site` cujo ID **não existe** no site foi excluído no site. Ele deve ser **ignorado**, com um aviso no relatório da prévia e no histórico, por exemplo "Evento excluído no site; a alteração do jogo foi ignorada". O site não deve recriar o evento.
   - Confira como a implementação atual trata esse caso. Se ela recria o evento, marca como conflito ou falha a aplicação inteira, ajuste para a regra acima.
   - Um evento com `origin = jogo` e ID inexistente continua sendo criado com o ID da string, como já é feito hoje.
2. **"Exportar para o addon" (`VDL1`):** confira que um evento excluído nunca aparece na exportação, e que `exportNumber` é o horário da geração. O addon depende dos dois pontos para remover o evento. Não mude o formato da `VDL1`.
3. **Testes:**
   - teste unitário ou de integração: um backup com um evento `origin = site` inexistente gera o aviso, não cria documento e não impede a aplicação dos demais eventos e presenças;
   - as presenças desse evento, se vierem no backup, seguem a regra atual da importação da `VDLP1` para evento inexistente;
   - `npm run check` passando.
4. **Documentação:** atualize `docs/criterios-de-aceite.md` na história "Aplicar backup do addon" com esse critério.
