# Página do CurseForge

Textos para o projeto no CurseForge, seguindo as [regras de moderação](https://support.curseforge.com/support/solutions/articles/9000197279-moderation-policies):

- nome em inglês e funcional, sem o nome do jogo nem número de versão;
- resumo de uma frase, sem copiar a descrição;
- descrição que diz o que o addon faz, com o inglês antes de outros idiomas;
- links externos (site e Discord) no fim da descrição, sem links de download;
- avatar de 400x400 em JPG (o envio de PNG e WebP falhou): [`assets/curseforge-avatar.jpg`](../assets/curseforge-avatar.jpg);
- changelog em cada arquivo enviado.

Ao criar o projeto, escolha o editor em **Markdown** e cole a descrição abaixo.

## Nome

```
Vanguarda da Luz Guild Hub
```

## Resumo

```
Event calendar, attendance, professions and raid alerts for members of the Vanguarda da Luz guild.
```

## Descrição

```markdown
**Vanguarda da Luz Guild Hub** is the companion addon of the **Vanguarda da Luz** guild on WoW Forever. It brings the guild's event calendar into the game, lets members confirm attendance, shows everyone's professions and lets officers send raid alerts.

> **Guild members only.** Every feature requires being in the guild named *Vanguarda da Luz*. Players outside the guild only see a welcome window with the guild's Discord invite. The interface is in **English** or **Brazilian Portuguese**, following the game language.

## Features

### Home
- Shows the guild's **Message of the Day** and **Guild Information**.
- Links in those texts are clickable: clicking one puts it in a selected box, ready to copy with Ctrl+C.
- Shows the **next event** (with how many members confirmed) and how many members are online.

### Event calendar
- Monthly calendar with the guild's events, the day's events and full event details.
- Events are created on the guild website. An officer imports the website's export string once, and the addon **sends the events to every guild member** through the guild addon channel. Members who log in later receive them automatically.
- Times are shown in Brasília time (UTC−3), with the server time next to them when it is different.
- The import validates the string (format, checksum, version) and shows a summary of new, changed and cancelled events before applying anything.

### Attendance (RSVP)
- Members confirm or cancel their attendance on upcoming events with one click.
- Responses are shared between members, so everyone sees who confirmed.
- Officers generate an attendance string to paste back on the guild website.

### Professions
- Lists every guild member with their **primary professions and skill level** (for example, "Blacksmithing 88/150").
- Professions come from the game's guild roster. Skill levels are shared by members who run the addon. Members without it show the profession without the level.
- Filter by profession (sorted from highest to lowest level), show online members only (the default) and **whisper** a member with one click.

### Item level and main/alt in the member list
- The guild window's **Members** list shows each member's equipped item level and whether the character is a main or an alt (for example, "231 · Alt"). The row tooltip shows the full text ("Item level 231 · Alt de Victor Vaz").
- Set your main once with `/vdl main`. Your other characters in the guild are marked as its alts automatically when you log in.
- Item levels are shared by members who run the addon.

### Raid alerts
- Officers send an alert that appears in the center of the screen of every online member, with the raid warning sound, and is also posted once in guild chat.
- Rate-limited, and never sent during encounters where addon communication is restricted.

### Members
- A **Members** list with each member's name in class color, level, item level, main/alt, zone and rank. Click a column title to sort; show everyone or online members only; right-click a member to whisper or invite to your group.
- It also replaces the guild window's Members tab, with a button to open Blizzard's original list (for promoting, demoting, removing and notes).

### Time with the guild
- Counts how long each member plays grouped with guildmates (same zone, nobody away). Alts add up to the main.
- Shown in the Members list and as a "most time playing with the guild" ranking on the Home tab.

### Settings
- A **Settings** tab to set your main, show or hide the minimap button and turn each guild window feature on or off.

### Guild window integration
- Adds **Events**, **Professions** and **Administration** tabs to the *Guild & Communities* window (J), below Blizzard's own tabs.
- The **Guild Information** tab shows the addon's Home, with a button to open Blizzard's original (to edit the Message of the Day and Guild Information, and see news and the event log).

## Permissions
- **Guild Master** and the **"Lorde"** rank: import events, export attendance and send raid alerts. Other members only accept data and alerts from these ranks, verified against the guild roster.
- **All members**: calendar, attendance, professions and whispers.

## Commands
| Command | What it does |
| --- | --- |
| `/vdl` | Opens the addon window on the Home tab |
| `/vdl importar` | Imports the export string from the website (officers) |
| `/vdl sincronizar` | Asks the guild for the latest events |
| `/vdl presencas` | Generates the attendance string for the website (officers) |
| `/vdl profissoes` | Opens the professions list |
| `/vdl main` | Sets the current character as your main (your other characters become alts) |
| `/vdl alerta [text]` | Sends a raid alert (officers) |
| `/vdl minimapa` | Shows or hides the minimap button |

The minimap button and the addon compartment open the addon window. Right-click opens a shortcut menu: Home, Events, Professions, Sync, Administration (officers only) and hide the minimap button.

## Privacy and network
- The addon never accesses the internet. Data only travels through the guild's addon channel inside the game.
- Everything is saved per account in the addon's SavedVariables.

## Feedback
Found a bug or have a suggestion? Talk to an officer in game or on the guild's Discord.

---

**Guild website:** https://vanguarda-da-luz.web.app
**Discord:** https://discord.gg/uGyPjtEsBw

---

## Português (Brasil)

**Vanguarda da Luz Guild Hub** é o addon da guilda **Vanguarda da Luz** no WoW Forever. Ele traz para o jogo o calendário de eventos do site da guilda, permite confirmar presença, mostra as profissões dos membros e deixa os oficiais enviarem alertas de raide.

> **Só para membros.** Todas as funções exigem estar na guilda *Vanguarda da Luz*. Quem não é da guilda vê apenas uma janela de boas-vindas com o convite do Discord.

- **Início:** mensagem do dia e informações da guilda com links para copiar, próximo evento e membros online.
- **Calendário:** eventos criados no site; um oficial importa a string e o addon envia para todos os membros da guilda. Horários de Brasília.
- **Presença:** confirme ou cancele com um clique; os oficiais geram a string de presenças para o site.
- **Profissões:** profissões primárias e nível de cada membro, com filtro, só online e botão de sussurrar.
- **Alerta de raide:** aviso no centro da tela de todos os membros online e no chat da guilda (Grão Lorde e Lordes).
- **Item level e main/alt:** na lista de Membros da janela da guilda, com `/vdl main` para definir o main.
- **Janela da guilda:** abas Eventos, Profissões e Administração na janela *Guilda e comunidades* (J), e o Início do addon na aba Informações.

Comandos: `/vdl` (abre a janela), `/vdl importar`, `/vdl sincronizar`, `/vdl presencas`, `/vdl profissoes`, `/vdl main`, `/vdl alerta [texto]`, `/vdl minimapa`.
```

## Changelog da versão 0.2.0

```markdown
### New
- **English interface.** The addon uses English when the game is not in Brazilian Portuguese. Commands also accept English names in any language (`/vdl import`, `/vdl sync`, `/vdl attendance`, `/vdl professions`, `/vdl members`, `/vdl alert`, `/vdl minimap`).
- **Members tab.** A guild member list with the name in class color, level, item level, main/alt, zone, rank and time played with the guild. Click a column title to sort; show everyone or online members only; right-click a member to whisper or invite to your group. Default order: online first, then rank, then level (highest first).
- **Item level and main/alt.** Each member's addon shares their equipped item level. Use `/vdl main` (or Settings) once to set your main; your other characters in the guild are marked as its alts automatically when you log in.
- **Time played with the guild.** The addon counts how long each member plays grouped with guildmates (same zone, nobody away). Alts add up to the main. Shown in the Members tab and as a "most time playing with the guild" ranking on the Home tab.
- **Guild window.** The Information and Members tabs of the Guild & Communities window now show the addon's Home and member list, each with a "View Blizzard's original" button (to edit the Message of the Day, see news and the log, or manage members).
- **Settings tab.** Set your main, show or hide the minimap button, and turn each guild window feature on or off.

### Changes
- Profession levels are matched by profession ID, so members playing in different languages see each other's levels. Members still on 0.1.x keep working.
- Away members show a yellow dot and busy members a red dot in the Members and Professions lists.
- The original Blizzard Members list also shows each member's item level and main/alt.
- Long Message of the Day and Guild Information texts scroll instead of overlapping, and clicking a link opens the copy box over the text (click outside to close it).
- The Members list in the guild window hides the time column to save space.

### Fixes
- Tabs no longer leave an empty space for members without an officer rank.
- Officer-only hints and the Administration option in Settings are only shown to the Grão Lorde and the Lordes.
- Button borders no longer disappear at some interface scales.
- The first line of the Message of the Day is no longer clipped.
```

## Changelog da versão 0.1.1

```markdown
- Fixed: members without an officer rank could open the import window (minimap right-click or `/vdl importar`). Only the Guild Master and the "Lorde" rank can import events now.
- Minimap button right-click now opens a shortcut menu: Home, Events, Professions, Sync, Administration (officers only) and hide the minimap button. Also works from the addon compartment.
```

## Changelog da versão 0.1.0

```markdown
First public release.

- Event calendar imported from the guild website and synced to all guild members.
- Attendance (RSVP) in game, synced between members, with export to the website.
- Guild professions list with skill levels, profession filter, online-only filter and whisper button.
- Raid alerts for officers (center of the screen and guild chat).
- Events, Professions and Administration tabs in the Guild & Communities window.
- Home tab with the guild's Message of the Day, Guild Information (copyable links), next event and online members.
- Welcome window with the Discord invite for players outside the guild.
```

## Envio do arquivo

- **Arquivo:** `dist/VanguardaDaLuz-<versão>.zip` (`scripts/package.sh`).
- **Versão do jogo:** Forever (1.60.1). Não marque Retail nem Classic.
- **Tipo:** Beta enquanto o roteiro de teste do README não estiver todo confirmado no jogo; depois, Release.
- **Rejeição:** não apague o projeto nem o arquivo para enviar de novo; corrija e responda à moderação.

## Imagens

Título e descrição de cada print da galeria, na ordem sugerida. Envie em JPG ou PNG (não WebP).

1. **Home tab**: The addon window opens on Home: the guild's Message of the Day, Guild Information with clickable links to copy, the next event with how many members confirmed, and how many members are online.
2. **Event calendar**: Monthly calendar with the guild's events, imported from the guild website and shared with every member. Brasília time, with the server time when it is different.
3. **Event details and attendance**: Selecting a day shows its events and the full details: date and time, organizer, who confirmed in game and the description. One click confirms or cancels your attendance.
4. **Guild professions**: Every guild member with their primary professions and skill levels, shared by members who run the addon. Filter by profession or online members, and whisper anyone with one click.
5. **Administration (officers)**: For the Guild Master and the "Lorde" rank: sync status, import events from the website, generate the attendance string for the website and send raid alerts.
6. **Events tab in the guild window**: The calendar is also available as a tab in the Guild & Communities window (J), below Blizzard's own tabs.
7. **Professions tab in the guild window**: The professions list, with filters and whisper buttons, inside the Guild & Communities window.
8. **Administration tab in the guild window**: Officer tools in the Guild & Communities window: import events, export attendance and raid alerts.
9. **Welcome window for non-members**: Players outside the Vanguarda da Luz guild only see this window, with the guild's Discord invite ready to copy.
