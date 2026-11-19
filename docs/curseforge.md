# Página do CurseForge

Textos para o projeto no CurseForge, seguindo as [regras de moderação](https://support.curseforge.com/support/solutions/articles/9000197279-moderation-policies):

- nome em inglês e funcional, sem o nome do jogo nem número de versão;
- resumo de uma frase, sem copiar a descrição;
- descrição em inglês que diz o que o addon faz;
- link do Discord no fim da descrição, sem links de download;
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
- Officers can also **create, edit and cancel events in game**. Changes reach every member right away and go to the website in the next backup.

### Addon backup
- Officers generate a backup string with events created in game, attendance, professions, item levels, mains and time played together, to keep on the guild website.
- The website hands the data back as a restore string. Restoring only adds newer data; nothing is deleted.

### Attendance (RSVP)
- Members confirm or cancel their attendance on upcoming events with one click.
- Responses are shared between members, so everyone sees who confirmed, with class, item level and an **Invite** button in front of each online name to build the group.
- A reminder shows on screen 15 minutes before an event you confirmed.
- Officers generate an attendance string to paste back on the guild website.

### Professions
- Lists every guild member with their **primary professions and skill level** (for example, "Blacksmithing 88/150").
- Professions come from the game's guild roster. Skill levels are shared by members who run the addon. Members without it show the profession without the level.
- Filter by profession (sorted from highest to lowest level), show online members only (the default) and **whisper** a member with one click.

### Item level and main/alt in the member list
- The guild window's **Members** list shows each member's equipped item level and whether the character is a main or an alt (for example, "231 · Alt"). The row tooltip shows the full text ("Item level 231 · Alt de Victor Vaz"), also in the member list beside the guild chat.
- Set your main once with `/vdl main`, in Settings or when the addon asks at login. Your other characters in the guild are marked as its alts automatically when you log in.
- Item levels are shared by members who run the addon.

### Raid alerts
- Officers send an alert that appears in the center of the screen of every online member, with the raid warning sound, and is also posted once in guild chat.
- Rate-limited, and never sent during encounters where addon communication is restricted.

### Recruitment message
- The Guild Master and the Lords write a recruitment message in Administration. The text is shared among them, so everyone sends the same one.
- One click sends it to the chat channel you pick (General by default). There is no automatic sending, and there are 60 s between sends.

### Members
- A **Members** list with each member's name in class color, level, item level, main/alt, zone and rank. Offline members show how long ago they last logged in ("Offline · 3 d ago").
- Click a column title to sort, and the dot at the top of the first column to go back to the default order. Show everyone or online members only.
- Right-click a member to whisper, invite to your group or request to join theirs, following Blizzard's rule. Members whose rank can invite also get an **Invite to guild** button.
- It also replaces the guild window's Members tab, with a button to open Blizzard's original list (for promoting, demoting, removing and notes).

### Guild map
- Online members with the addon show on the world map as a square in their class color, with name, level, rank and zone on mouseover.
- They also show on the minimap when they are close, following the minimap zoom and rotation. Members in your group are left out, since Blizzard already shows them.
- Sharing your position, showing members on the map and showing them on the minimap can each be turned off in Settings.

### Time with the guild
- Counts how long each member plays grouped with guildmates (same zone, nobody away). Alts add up to the main.
- Shown in the Members list and as a "most time playing with the guild" ranking on the Home tab.

### Members nearby
- The guild logo shows above the nameplate of guild members near you (with friendly nameplates on), and their tooltip shows rank, item level and main/alt.

### Guild chat
- A **Chat** tab with the guild chat, including recent messages from before you logged in: names in class color, "(alt of …)" for alts, clickable links to copy, item and quest tooltips on mouseover, and a click on a name to whisper or invite. Write to the guild from the tab (Shift+click items and quests to link them). Officers also get the officer channel.

### Settings
- A **Settings** tab to set your main, show or hide the minimap button, choose a **key binding** to open the addon, turn sharing your map position or showing members on the map and minimap on or off, and turn each guild window feature on or off.

### New version warning
- The addon tells you in chat, once per session, when a guild member has a newer version. No addon can check CurseForge from inside the game, so the warning shows up once someone in the guild has updated.

### Diagnostics
- `/vdl status` shows the addon version, your rank, calendar and sync state, whether addon communication is restricted, how many online members have the addon and the map state. Useful when something did not arrive.

### Guild window integration
- Adds **Events**, **Professions** and **Administration** tabs to the *Guild & Communities* window (J), below Blizzard's own tabs.
- The **Chat** tab shows the addon's chat, and the **Guild Information** tab shows the addon's Home, each with a button to open Blizzard's original (news and the event log are there). Officers click the Message of the Day or the Guild Information to edit it.

## Permissions
- **Guild Master** and the **"Lorde"** rank: import events, create, edit and cancel events in game, export attendance, create and restore backups, write and send the recruitment message and send raid alerts. Other members only accept data and alerts from these ranks, verified against the guild roster.
- **All members**: calendar, attendance, reminders, professions, members, map, chat and whispers.

## Commands
| Command | What it does |
| --- | --- |
| `/vdl` | Opens the addon window on the Home tab |
| `/vdl importar` | Imports the export string from the website (officers) |
| `/vdl sincronizar` | Asks the guild for the latest events |
| `/vdl presencas` | Generates the attendance string for the website (officers) |
| `/vdl profissoes` | Opens the professions list |
| `/vdl membros` | Opens the members list |
| `/vdl main` | Sets the current character as your main (your other characters become alts) |
| `/vdl alerta [text]` | Sends a raid alert (officers) |
| `/vdl minimapa` | Shows or hides the minimap button |
| `/vdl status` | Shows the addon diagnostics (version, sync, communication) |

Commands also accept English names in any language: `/vdl import`, `/vdl sync`, `/vdl attendance`, `/vdl professions`, `/vdl members`, `/vdl alert`, `/vdl minimap`.

The minimap button and the addon compartment open the addon window. Right-click opens a shortcut menu: Home, Events, Professions, Sync, Administration (officers only) and hide the minimap button.

## Privacy and network
- The addon never accesses the internet. Data only travels through the guild's addon channel inside the game.
- Everything is saved per account in the addon's SavedVariables.

## Feedback
Found a bug or have a suggestion? Talk to an officer in game or on the guild's Discord.

---

**Discord:** https://discord.gg/uGyPjtEsBw

```

## Changelog da versão 0.7.1

```markdown
### Fixes
- **Memory no longer keeps growing while guild members are on the minimap.** Ten times a second the minimap read your position as game vectors and rebuilt the member list, creating about 50 KB of garbage per second. That made the addon climb to the top of the memory list until the game cleaned it up. Now your position is read as plain numbers, the member list is kept until something changes, and the squares are only redrawn when you move, turn, zoom or a member's position arrives.
```

## Changelog da versão 0.7.0

```markdown
### New
- **Guild members on the minimap.** Online members with the addon who are close to you now also show on the minimap, as a smaller square in their class color with the same tooltip as the world map. The squares follow the minimap zoom, indoor and outdoor ranges and the "Rotate Minimap" option. Members in your group are left out, since Blizzard already shows them. Positions arrive every few seconds, so the squares move in steps.
- Settings > Map has a new **Show members on the minimap** option, on by default.
- **Guild members nearby.** The guild logo shows above the nameplate of every guild member near you, even those without the addon (turn on friendly nameplates with Shift+V; the game does not allow it in dungeons and raids). Mousing over a guild member adds a line to the tooltip with their rank and, for members with the addon, item level and main/alt. Both can be turned off in Settings > Members nearby, where you can also make the logo bigger (up to three times the default size).

### Changes
- The Settings tab scrolls, so every option fits.

### Fixes
- **Less memory and no more hitches when a guild member logs in.** The addon read the whole guild roster again for every addon message it received (map positions arrive every few seconds), which used a lot of memory in large guilds and caused hitches when the game cleaned it up. It also scanned every guild member each time the roster changed, like when someone logs in. Now the roster is read only when the game says it changed, and several changes in a row are handled once.
```

## Changelog da versão 0.6.0

```markdown
### New
- **Recruitment message.** The Guild Master and the Lords write a recruitment message in Administration > Recruitment message. The text is shared among them, and one click sends it to a chat channel you pick (General by default). Sending is always your click, with 60 s between sends.
- **New version warning.** The addon tells you in chat, once per session, when a guild member has a newer version. No addon can check CurseForge from inside the game, so the warning shows up once someone in the guild has updated.
- **Event reminder.** 15 minutes before an event you confirmed, a notice shows in the center of the screen with the raid warning sound, and in chat.
- **Who confirmed.** The event detail lists each confirmed member with class color, item level and main/alt, and an **Invite** button in front of each online name (or **Suggest**/**Request**, following Blizzard's rule), so you can build the raid group one invite at a time.
- **Last online.** Offline members in the Members tab show how long ago they last logged in ("Offline · 3 d ago").
- **Diagnostics.** `/vdl status` shows the addon version, your rank, calendar and sync state, whether communication is restricted, how many online members have the addon and the map state.
- **Request to join a group.** The right-click menu on a member (Members tab and names in Chat) now picks the group option like Blizzard's own menu: **Invite to group**, **Suggest invite** when you are in a group but not the leader, or **Request to join group** when you have no group and the member is in one.

### Changes
- **Invite to group** is disabled for members already in your group.
- The Members tab of the addon window now comes right after Chat, before Events.
- In the Members list, click the dot at the top of the first column to go back to the default order (online first, then rank, level and name).
```

## Changelog da versão 0.5.0

```markdown
### New
- **Guild members on the world map.** Online members with the addon show on the world map as a square in their class color (unlike the round party and raid dots), on the zone, continent and city maps. Mouse over a square to see name, level, rank, main/alt, zone and how recent the position is. Settings > Map turns off sharing your position or showing members. The game gives no position inside instances.

### Changes
- The addon window is a little taller, so every option of the Settings tab fits.
- The "most time playing with the guild" ranking on the Home tab shows the top 10 instead of 5.

### Fixes
- With the Settings tab open, keys you pressed (like moving) could become the addon's key binding without clicking the button first. Now only a click on the button starts waiting for a key.
- In the guild window, the addon's Info and Members views no longer end up hidden behind Blizzard's view. The Chat view did not have this problem.
```

## Changelog da versão 0.4.0

```markdown
### New
- **Create events in game.** The Guild Master and the Lords can create events from the Events tab (**+ Event** on the day card), edit or cancel any upcoming event, and delete cancelled events. Changes reach every guild member right away, are shown as "waiting for the website" and go to the website in the next backup.
- **Addon backup.** Administration > Addon backup creates a string with events created or changed in game, attendance, professions, item levels, mains and time played together, to paste on the guild website. **Restore** pastes a string from the website back into the addon; it only adds newer data and never deletes anything.
- **Invite to guild.** Members whose guild rank has the invite permission get an **Invite to guild** button in the Members tab. It opens Blizzard's own invite window (from the addon window, it opens the guild window first).
- **Chat separators.** The Chat tab shows "Today", "Yesterday" or the date before each day's messages, and "Unread messages" before the messages you have not seen yet, like the Blizzard chat.

### Changes
- The Administration tab now shows one action per row, with the new backup buttons.
- Importing events from the website keeps the events created in game that the website does not have yet. An event deleted on the website is still removed, even if it was edited in game before.

### Fixes
- The Chat tab now shows the whole guild chat history, including the messages before the "Unread messages" or "Today" separator.
```

## Changelog da versão 0.3.3

```markdown
### Fixes
- No more Lua errors during boss fights. In encounters the game hides some guild data from addons (member list, roster, chat history); the addon now keeps showing what it had before the fight and reads again when it ends.
```

## Changelog da versão 0.3.2

```markdown
### Fixes
- Map location links (and other links or icons with an icon inside) no longer show as code in the Chat tab. They look and work like in Blizzard's chat: clicking a map location opens the map with the pin.
```

## Changelog da versão 0.3.1

```markdown
### Fixes
- The **Officers** channel of the Chat tab now shows its message history. Before, it stayed empty until someone wrote, because the game only loads a channel's history when asked.
```

## Changelog da versão 0.3.0

```markdown
### New
- **Chat tab.** The guild chat inside the addon window, right after Home. It opens with the recent messages from before you logged in and shows new ones as they arrive: time, names in class color and "(alt of …)" for alts. Click a name to whisper or invite to your group, click a web link to copy it, and hover item and quest links to see their tooltip (click works like Blizzard's chat). Write to the guild from the box at the bottom, and Shift+click items and quests to link them. The Guild Master and the "Lorde" rank also get the officer channel.
- **Chat in the guild window.** The Chat tab of the Guild & Communities window now shows the addon's chat, with a "View Blizzard's original" button. It can be turned off in Settings.
- **Edit the Message of the Day and Guild Information.** In the Guild & Communities window, the Guild Master and the "Lorde" rank click the Message of the Day or the Guild Information on the Home tab (outside a link) to open Blizzard's edit window, already filled with the current text. In the addon window's Home tab, clicking the text opens the guild window to edit it there. A hint shows this only to them. Not available during combat.

### Fixes
- Card borders no longer fade or disappear at the top inside the guild window.
```

## Changelog da versão 0.2.1

```markdown
### New
- **Main character prompt.** When your account has no main set, the addon asks at login whether the current character is your main. "Yes" sets it; "No" stops asking on that character (your other characters are still asked until a main is set); "Don't ask again" turns the prompt off for the whole account. You can still set your main anytime in Settings or with `/vdl main`.
- **Key binding.** New **Key binding** option in Settings: click the button and press a key (Shift, Ctrl and Alt combinations work) to open and close the addon window. It is saved for the whole account and does not change Blizzard's key bindings. If the key is already used by the game, Settings tells you which action it replaces; **Clear** gives the key back. Changes made during combat are applied when combat ends.

### Fixes
- The item level next to member names no longer shows in the narrow member list beside the guild chat, where it covered long names. It still shows in the Members list, and the tooltip keeps the full text in both.
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
