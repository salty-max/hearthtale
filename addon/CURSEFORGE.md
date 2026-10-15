# Hearthtale

<!-- Project description for curseforge.com (paste as the project's description). -->

<!-- Summary (the project's summary on CurseForge and Wago, and the TOCs' Notes):
A diary for your WoW character, written as you play, with an epitaph and a saved journal when a Hardcore life ends. -->

Hearthtale keeps a diary for your character as you play. Quests, close calls, new places and the people you travel with become entries written in the first person, with a different voice for each race. On Hardcore, a death ends the journal with an epitaph and saves it in the Hall of the Fallen.

For Classic Era (including Hardcore and Season of Discovery) and World of Warcraft: Forever.

## A page from the journal

> I took to the road in Durotar, and it looked friendly enough, which in my experience is the moment to look twice. I came into the Barrens for the first time, and wondered straight away what grew and swam there and how much of it was good to eat. I thinned the Razormane quilboars that had been attacking the supply lines from Durotar, for Thork at the Crossroads. I tamed my first companion and called it Dusk, and from then on I did not hunt alone. I rested in the Barrens, and gave my curiosity a rest along with my legs.

## What goes into an entry

An entry covers the time between rests. Log out at an inn, in a city or by a campfire, and it closes. Log out in the wild, and the journal records a night outdoors but keeps the entry going. After four hours of play, your next logout closes it wherever you are.

The journal picks out the events worth remembering:

- **Quests and their stories.** It tells what you did and why, using the quest's own story, and names the companions who were there. A quest chain can carry on across several entries.
- **Class milestones.** A hunter's first pet, a warlock's demons, a druid's forms, a shaman's totems, a mage's first teleport. Class quests and defining spells get room of their own.
- **Danger.** Deaths, recoveries, close calls below 10% health, rares, elites and dungeon bosses. Open-world PvP kills can appear too. Battlegrounds are left out.
- **Travel and company.** New lands, towns and dungeons, your race's capital, the players you travelled with and the campfires where you stopped.
- **Progress.** Your specialization, professions, things you made, notable gear and epic finds, your first bag, first gold piece and first mount. Pets have a place in the story, including the times they fall.

A quiet evening makes a short entry. A dungeon run or a day full of quests gives it more to tell. Reaching the level cap is recorded too, and the journal continues afterwards.

You can give any entry your own title and add a note beneath it. Use the **Edit** button, or `/ht title TEXT` and `/ht note TEXT` for the latest entry. Your words are saved separately from the journal's text and appear both in game and on hearthtale.app.

Starting with a character you already play is fine. The journal opens with a prologue based on what the game knows, then follows your adventures from there.

## How the writing works

Hearthtale uses about 1,900 written lines and phrases, around 240 place descriptions and the stories of over 3,200 quests. It chooses them to suit what happened, the time of day and whether you were alone or with others. Recently used lines are held back to reduce repetition.

Each race has its own way of looking at things. A dwarf notices stonework, a troll wonders what's edible, and a Forsaken takes a drier view. Hardcore entries grow more serious as the character gets further.

Titles come from the game: a pet's name, a dungeon or a quest such as "The Stolen Journal" or "Escape Through Stealth". The current entry develops as you play. A finished entry keeps its words, even after an update improves the writing: it stays as you first read it. To have the whole journal written again with the latest writing, type `/ht rewrite`. At logout, Hearthtale saves a readable copy for the website.

## The Hall of the Fallen

When a Hardcore character dies, Hearthtale writes an epitaph and closes the book. A chat message and an alert mark the death. The journal is kept in the **Hall of the Fallen**, shared by your characters, so you can return to that life and read its entries again.

On other realms, death is recorded in the journal and the book carries on.

## Read on your phone

**[hearthtale.app](https://hearthtale.app)** lets you read the same journal away from the game. The website is optional. You can use the addon entirely in game.

1. Install **[Ravenpost](https://github.com/salty-max/ravenpost)**, the free, open source companion for Windows and macOS. It uploads your books a few seconds after you log out or use `/reload`.
2. In Ravenpost's window, click **Sign in with Battle.net**. That one sign-in links Hearthtale, and Classic Era characters are recognised automatically.
3. For Forever characters, or any character Battle.net cannot find, get a code from **Link a character** at the top of hearthtale.app and enter `/ht link CODE` in game.

Your books are private, and the notes you add stay yours even when you share a book. Ravenpost sends the written book and the information needed to identify its character. The addon's underlying records stay on your computer. Ravenpost also works with WoWLocker if you use both.

Full setup instructions: [hearthtale.app/start](https://hearthtale.app/start).

## Opening the book

Type `/hearthtale` or `/ht`, or click the minimap button. Pick an entry from the list to read it, with its location, levels and dates. A skull marks a close call and a star marks a rare. The second tab holds the Hall of the Fallen. New entries are linked in chat, and each login says whether you're resuming an entry or starting a new one.

## Compatibility

One download covers Classic Era, Hardcore, Season of Discovery and World of Warcraft: Forever.

The journal is written in **English**, on any game client. On other clients, the game's names in it (places, creatures, people, quests, items, trades and spells) are kept in English too. Around it, the book, its settings and its messages speak English, French and German (the German a first translation: corrections are welcome on GitHub).

Forever restricts what addons can read about kills. In its dungeons, Hearthtale can only tell kills that are also counted by a quest.

## Settings and commands

The welcome page appears once for each character. Open it again with `/ht welcome`, or find the settings under **Options > AddOns > Hearthtale**, through `/ht settings` or by right-clicking the minimap button.

You can change the alert when a book closes and the minimap button. Chat lines always show. If the game cannot identify a Hardcore character, you can mark it yourself in the settings.

Settings are saved per character. Copy them from another character of the same game on the welcome or settings page, or transfer them between games and accounts with `/ht export` and `/ht import CODE`.

- `/ht title [N] TEXT` gives entry N a title. Leave out N for the latest entry.
- `/ht note [N] TEXT` adds a note. Leave out the text to remove it.
- `/ht hall` opens the Hall of the Fallen.
- `/ht link CODE` links the character to your website library.
- `/ht rewrite` writes the whole journal again with the current version's writing, after asking. Your titles and notes stay.
- `/ht minimap` shows or hides the minimap button.

## Help the addons keep up with Forever

Forever brings new quests and creatures, and the usual databases take weeks to catch up with them. You can help Hearthtale and its sister addons get there sooner. Tick **Share what you see** on the welcome page or in the options, and Hearthtale keeps what the game tells you of quests, creatures and NPCs. **[Ravenpost](https://github.com/salty-max/ravenpost)**, a small free app for Windows and macOS, sends it to the addons' shared database a few seconds after you log out, once you **Sign in with Battle.net** in it: one account, one voice when players' games disagree. What you see lets the journal tell Forever's new quests in their own words. Every player who shares makes a real difference, and it's truly appreciated.

Your name, class and race are replaced by the game's own placeholders, lines that name another player are left out, and your chat is never kept. Sharing is off until you turn it on, and turning it off forgets everything kept.

## Other addons

These share Hearthtale's book style and work independently:

- **[Lorekeeper's Codex](https://www.curseforge.com/wow/addons/lorekeepers-codex)** ([Wago](https://addons.wago.io/addons/j6jAL0NR)) unlocks lore pages as you explore Azeroth and meet its people.
- **[Yonder](https://www.curseforge.com/wow/addons/yonder)** ([Wago](https://addons.wago.io/addons/ZKbq5y61)) offers exploration riddles, rare hunts, a bestiary, an atlas and records of your fish and herbs.

## Support

Hearthtale is free and will stay free. If you've enjoyed reading your character's journal, you can support the addon and hearthtale.app with a coffee on [Ko-fi](https://ko-fi.com/salty_max). Thanks for your support.

## Source

Open source under GPL-3.0-or-later: [github.com/salty-max/hearthtale](https://github.com/salty-max/hearthtale).

Game data comes from the game clients' own tables (via [wago.tools](https://wago.tools)), [QuestieDB](https://github.com/Questie/QuestieDB) and [cmangos classic-db](https://github.com/cmangos/classic-db), gathered in [wow-data](https://github.com/salty-max/wow-data). Forever's new quests also draw on [AllTheThings](https://github.com/ATTWoWAddon/AllTheThings) for their rewards, [Wowhead](https://www.wowhead.com/forever) for their texts, levels and givers, and what players choose to share. Thanks to their contributors. Not affiliated with Blizzard Entertainment.
