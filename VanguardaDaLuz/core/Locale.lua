-- Idioma do addon: português no jogo em português do Brasil (ptBR) e inglês
-- em qualquer outro idioma. Os textos são escritos em português no código, com
-- L["texto"]; aqui fica a tradução de cada um para o inglês. Sem tradução, o
-- texto aparece em português.
local _, ns = ...

local EN = {}
ns.LocaleEN = EN -- usado pelo teste que confere se todo texto tem tradução

local locale = GetLocale and GetLocale() or "ptBR"
ns.locale = locale == "ptBR" and "ptBR" or "enUS"

local active = ns.locale == "enUS" and EN or {}
ns.L = setmetatable({}, {
  __index = function(_, key) return active[key] or key end,
})

-- Traduções para o inglês (preenchidas abaixo).
-- Os postos "Grão Lorde" e "Lorde" são nomes da guilda e não são traduzidos.

-- Comandos e mensagens no chat
EN["comandos (versão %s):"] = "commands (version %s):"
EN["/vdl  abre e fecha a janela do addon"] = "/vdl  opens and closes the addon window"
EN["/vdl importar  importa a string do site (Grão Lorde e Lordes)"] =
  "/vdl import  imports the website string (Grão Lorde and Lordes)"
EN["/vdl sincronizar  pede à guilda a exportação mais recente"] = "/vdl sync  asks the guild for the latest export"
EN["/vdl presencas  gera a string de presenças para o site (Grão Lorde e Lordes)"] =
  "/vdl attendance  generates the attendance string for the website (Grão Lorde and Lordes)"
EN["/vdl profissoes  mostra as profissões dos membros da guilda"] = "/vdl professions  shows the guild members' professions"
EN["/vdl membros  mostra a lista de membros da guilda"] = "/vdl members  shows the guild member list"
EN["/vdl main  define este personagem como main (os outros da conta viram alts)"] =
  "/vdl main  sets this character as your main (your other characters become alts)"
EN["/vdl alerta [texto]  envia um alerta de raide à guilda (Grão Lorde e Lordes)"] =
  "/vdl alert [text]  sends a raid alert to the guild (Grão Lorde and Lordes)"
EN["/vdl minimapa  mostra ou esconde o botão no minimapa"] = "/vdl minimap  shows or hides the minimap button"
EN["Aguardando."] = "Waiting."
EN["Comunicação restrita no momento. O envio será feito quando for permitido."] =
  "Communication is restricted right now. It will be sent when allowed."
EN["Enviando a exportação para a guilda…"] = "Sending the export to the guild…"
EN["Exportação enviada para a guilda."] = "Export sent to the guild."
EN["Perguntando à guilda pela exportação mais recente…"] = "Asking the guild for the latest export…"
EN["Eventos atualizados por %s."] = "Events updated by %s."
EN["Calendário atualizado por %s: %d alteração(ões)."] = "Calendar updated by %s: %d change(s)."
EN["Recebendo eventos de %s…"] = "Receiving events from %s…"
EN["A lista da guilda ainda não carregou. Tente de novo em alguns segundos."] =
  "The guild list has not loaded yet. Try again in a few seconds."
EN["%s agora é o seu main. Os outros personagens desta conta na guilda aparecem como alts ao logar."] =
  "%s is now your main. Your other characters in the guild appear as alts when you log in."
EN["Main desmarcado. Os personagens desta conta deixam de aparecer como main ou alt."] =
  "Main cleared. The characters of this account no longer appear as main or alt."
EN["Só é possível responder a eventos ativos que ainda não começaram."] =
  "You can only respond to active events that have not started yet."
EN["Comunicação restrita no momento (encontro, Mítica+ ou JxJ). O alerta não foi enviado."] =
  "Communication is restricted right now (encounter, Mythic+ or PvP). The alert was not sent."
EN["Você não está na guilda %s."] = "You are not in the guild %s."
EN["Somente o Grão Lorde e os Lordes podem enviar alertas."] = "Only the Grão Lorde and the Lordes can send alerts."
EN["Somente o Grão Lorde e os Lordes podem importar eventos."] = "Only the Grão Lorde and the Lordes can import events."
EN["Somente o Grão Lorde e os Lordes podem exportar as presenças."] =
  "Only the Grão Lorde and the Lordes can export attendance."
EN["Somente o Grão Lorde e os Lordes podem usar estas ações."] =
  "Only the Grão Lorde and the Lordes can use these actions."
EN["Botão do minimapa escondido. Use /vdl minimapa ou Configurações para mostrar de novo."] =
  "Minimap button hidden. Use /vdl minimap or Settings to show it again."
EN["Importação concluída: %d novo(s), %d alterado(s), %d cancelado(s), %d removido(s)."] =
  "Import complete: %d new, %d changed, %d cancelled, %d removed."
EN["Seu cargo não está entre os aceitos pela guilda; a exportação não foi enviada aos membros."] =
  "Your rank is not one the guild accepts; the export was not sent to the members."

-- Erros da string do site e do alerta
EN["Cole a string de exportação gerada no site."] = "Paste the export string generated on the website."
EN["A string passa do tamanho máximo aceito."] = "The string is longer than the maximum accepted size."
EN["Isto não é uma string de exportação da Vanguarda da Luz (deve começar com VDL)."] =
  "This is not a Vanguarda da Luz export string (it must start with VDL)."
EN["Esta string usa uma versão do formato que este addon não conhece. Atualize o addon."] =
  "This string uses a format version this addon does not know. Update the addon."
EN["A string tem caracteres inválidos. Copie de novo pelo botão \"Copiar\" do site."] =
  "The string has invalid characters. Copy it again with the website's \"Copiar\" button."
EN["A string está incompleta ou corrompida. Copie de novo pelo botão \"Copiar\" do site."] =
  "The string is incomplete or corrupted. Copy it again with the website's \"Copiar\" button."
EN["A string está corrompida: o checksum não confere. Copie de novo pelo botão \"Copiar\" do site."] =
  "The string is corrupted: the checksum does not match. Copy it again with the website's \"Copiar\" button."
EN["O conteúdo da string é inválido."] = "The string content is invalid."
EN["Esta exportação é de outra versão do jogo. Exporte os eventos do WoW Forever no site."] =
  "This export is for another game version. Export the WoW Forever events on the website."
EN["Esta exportação é igual ou mais antiga que a última importada."] =
  "This export is the same as or older than the last one imported."
EN["Escreva o texto do alerta."] = "Write the alert text."
EN["O alerta passou do limite de tamanho."] = "The alert is over the size limit."
EN["Aguarde %d s para enviar outro alerta."] = "Wait %d s to send another alert."

-- Janela principal e abas
EN["Início"] = "Home"
EN["Eventos"] = "Events"
EN["Profissões"] = "Professions"
EN["Membros"] = "Members"
EN["Administração"] = "Administration"
EN["Configurações"] = "Settings"
EN["Sincronizar"] = "Sync"
EN["Guilda Vanguarda da Luz"] = "Vanguarda da Luz guild"
EN["Horários de Brasília"] = "Brasília time"
EN["Fechar"] = "Close"
EN["Cancelar"] = "Cancel"

-- Início
EN["Mensagem do dia"] = "Message of the Day"
EN["Informações da guilda"] = "Guild Information"
EN["Nada definido."] = "Nothing set."
EN["Clique num link para copiar"] = "Click a link to copy it"
EN["Clique para copiar o link"] = "Click to copy the link"
EN["Link selecionado: pressione Ctrl+C para copiar"] = "Link selected: press Ctrl+C to copy"
EN["Próximo evento"] = "Next event"
EN["Nenhum evento marcado."] = "No events scheduled."
EN["%d confirmado(s) no jogo"] = "%d confirmed in game"
EN["você vai"] = "you're going"
EN["Ver no calendário"] = "View in calendar"
EN["Guilda"] = "Guild"
EN["%d membro(s)"] = "%d member(s)"
EN["%d online"] = "%d online"
EN["Jogando com"] = "Playing as"
EN["MAIS TEMPO JOGANDO COM A GUILDA"] = "MOST TIME PLAYING WITH THE GUILD"
EN["Ninguém ainda."] = "Nobody yet."

-- Calendário
EN["(Brasília)"] = "(Brasília)"
EN["(servidor, %s)"] = "(server, %s)"
EN["Nenhuma exportação recebida ainda. Os eventos chegam do Grão Lorde ou de um Lorde da guilda."] =
  "No export received yet. Events come from the guild's Grão Lorde or a Lorde."
EN[" de %s"] = " from %s"
EN[" por importação"] = " by import"
EN["Gerado no site em %s  ·  Recebido em %s%s"] = "Generated on the website on %s  ·  Received on %s%s"
EN["Confirmados no jogo (%d):"] = "Confirmed in game (%d):"
EN["ninguém ainda"] = "nobody yet"
EN["Cancelar presença"] = "Cancel attendance"
EN["Confirmar presença"] = "Confirm attendance"
EN["CANCELADO"] = "CANCELLED"
EN["ATIVO"] = "ACTIVE"
EN["Cancelado"] = "Cancelled"
EN["Sem descrição."] = "No description."
EN["Hoje"] = "Today"
EN["Nenhum evento neste dia."] = "No events on this day."
EN["QUANDO"] = "WHEN"
EN["ORGANIZADOR"] = "ORGANIZER"
EN["PRESENÇA"] = "ATTENDANCE"
EN["DESCRIÇÃO"] = "DESCRIPTION"

-- Profissões e membros
EN["Profissões da guilda"] = "Guild professions"
EN["Os níveis vêm do addon de cada membro. Sem o addon, o nível aparece como —."] =
  "Levels come from each member's addon. Without the addon, the level shows as —."
EN["Profissão: %s"] = "Profession: %s"
EN["Todas"] = "All"
EN["Mostrar: só online"] = "Show: online only"
EN["Mostrar: todos"] = "Show: everyone"
EN["Nenhum membro encontrado com esse filtro."] = "No members found with this filter."
EN["Nenhum membro online."] = "No members online."
EN["MEMBRO"] = "MEMBER"
EN["PROFISSÃO 1"] = "PROFESSION 1"
EN["PROFISSÃO 2"] = "PROFESSION 2"
EN["Sem profissão"] = "No profession"
EN["  (você)"] = "  (you)"
EN["Sussurrar"] = "Whisper"
EN["Convidar para o grupo"] = "Invite to group"
EN["NV"] = "LVL"
EN["ILVL"] = "ILVL"
EN["MAIN/ALT"] = "MAIN/ALT"
EN["ZONA"] = "ZONE"
EN["POSTO"] = "RANK"
EN["TEMPO"] = "TIME"
EN["Offline"] = "Offline"
EN["Clique direito num membro: sussurrar ou convidar"] = "Right-click a member: whisper or invite"
EN["Main"] = "Main"
EN["Alt"] = "Alt"
EN["Alt de %s"] = "Alt of %s"
EN["Item level %d"] = "Item level %d"

-- Janela da guilda
EN["Eventos da guilda"] = "Guild events"
EN["Administração do addon"] = "Addon administration"
EN["Ver original da Blizzard"] = "View Blizzard's original"
EN["Para editar a mensagem do dia e as informações, ou ver notícias e registro, use a original."] =
  "To edit the Message of the Day and the information, or to see news and the log, use the original."
EN["Para ver notícias e registro, use a original."] = "To see news and the log, use the original."
EN["Para promover, rebaixar, remover ou editar notas, use a original."] =
  "To promote, demote, remove or edit notes, use the original."
EN["Para alterar a nota, use a original."] = "To change your note, use the original."

-- Administração, importação, alerta e presenças
EN["Importar eventos"] = "Import events"
EN["Cole a string gerada no site em \"Exportar para o addon\". Os eventos vão para o calendário e são enviados à guilda."] =
  "Paste the string generated on the website under \"Exportar para o addon\". The events go to the calendar and "
  .. "are sent to the guild."
EN["Importar"] = "Import"
EN["Exportar presenças"] = "Export attendance"
EN["Gera a string com as confirmações e os cancelamentos do jogo, para colar no site."] =
  "Generates the string with the in-game confirmations and cancellations, to paste on the website."
EN["Gerar string"] = "Generate string"
EN["Alerta de raide"] = "Raid alert"
EN["Mostra um aviso no centro da tela dos membros online e publica no chat da guilda."] =
  "Shows a warning in the center of the screen of online members and posts it in guild chat."
EN["Enviar alerta"] = "Send alert"
EN["SINCRONIZAÇÃO"] = "SYNC"
EN["No chat da guilda:"] = "In guild chat:"
EN["O alerta aparece na tela de quem tem o addon e no chat da guilda para todos."] =
  "The alert appears on the screen of everyone with the addon and in guild chat for everyone."
EN["e mais %d"] = "and %d more"
EN["Exportação válida"] = "Valid export"
EN["Gerada em %s"] = "Generated on %s"
EN["Janela: %s a %s"] = "Window: %s to %s"
EN["%d evento(s) na exportação"] = "%d event(s) in the export"
EN["Novos"] = "New"
EN["Alterados"] = "Changed"
EN["Cancelados"] = "Cancelled"
EN["Removidos"] = "Removed"
EN["Sem alteração: %d"] = "Unchanged: %d"
EN["Fora da janela (mantidos): %d"] = "Outside the window (kept): %d"
EN["Cole a string gerada em \"Exportar para o addon\" no site e clique em Validar."] =
  "Paste the string generated under \"Exportar para o addon\" on the website and click Validate."
EN["No site, abra Administração de eventos > Exportar para o addon, clique em Copiar e cole abaixo com Ctrl+V."] =
  "On the website, open Administração de eventos > Exportar para o addon, click Copiar and paste it below with Ctrl+V."
EN["Confirmar importação"] = "Confirm import"
EN["Validar"] = "Validate"
EN["Limpar"] = "Clear"
EN["Confirmações e cancelamentos do jogo nos eventos que ainda não começaram. Copie com Ctrl+C e cole no site, na administração de eventos."] =
  "In-game confirmations and cancellations for events that have not started yet. Copy with Ctrl+C and paste it "
  .. "on the website, in the event administration."
EN["%d evento(s)  ·  %d confirmação(ões)  ·  %d cancelamento(s)"] =
  "%d event(s)  ·  %d confirmation(s)  ·  %d cancellation(s)"

-- Configurações
EN["Personagem"] = "Character"
EN["O item level e o main/alt aparecem na lista de Membros da janela da guilda."] =
  "The item level and main/alt appear in the guild window's Members list."
EN["Este personagem é o meu main"] = "This character is my main"
EN["Main atual da conta: %s. Este personagem aparece como alt."] =
  "Current main of this account: %s. This character appears as an alt."
EN["Os outros personagens desta conta na guilda aparecem como alts deste."] =
  "Your other characters in the guild appear as alts of this one."
EN["Nenhum main definido nesta conta."] = "No main set on this account."
EN["Minimapa"] = "Minimap"
EN["O compartimento de addons e /vdl continuam abrindo o addon."] =
  "The addon compartment and /vdl still open the addon."
EN["Mostrar o botão no minimapa"] = "Show the minimap button"
EN["Janela da guilda"] = "Guild window"
EN["O que o addon acrescenta à janela Guilda e comunidades (J). Desligado, a janela fica como a da Blizzard."] =
  "What the addon adds to the Guild & Communities window (J). When off, the window stays as Blizzard's."
EN["Aba Eventos"] = "Events tab"
EN["Aba Profissões"] = "Professions tab"
EN["Aba Administração"] = "Administration tab"
EN["Início do addon na aba Informações"] = "Addon Home on the Information tab"
EN["Lista de membros do addon na aba Membros"] = "Addon member list on the Members tab"
EN["Item level e main/alt na lista original de Membros"] = "Item level and main/alt on the original Members list"

-- Minimapa e boas-vindas
EN["Clique: abrir o addon"] = "Click: open the addon"
EN["Clique direito: atalhos"] = "Right-click: shortcuts"
EN["Clique: convite para a guilda"] = "Click: guild invite"
EN["Mostrar botão do minimapa"] = "Show minimap button"
EN["Esconder botão do minimapa"] = "Hide minimap button"
EN["Você ainda não faz parte da guilda %s. Entre no nosso Discord para conhecer a guilda:"] =
  "You are not part of the %s guild yet. Join our Discord to meet the guild:"
EN["O link já está selecionado: use Ctrl+C para copiar."] = "The link is already selected: press Ctrl+C to copy."
