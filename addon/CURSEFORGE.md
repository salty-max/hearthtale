# Hearthtale

<!-- Project description for curseforge.com (paste as the project's description). -->

**Your character's own journal, written as you play.** The addon records your life as it happens (every quest, foe, place and close call), and each time you rest (a logout at an inn, in a city or by a campfire) the stretch becomes a diary entry in your character's own voice: what mattered, and what it meant to them. On Hardcore, a death closes the book with an epitaph, and the life joins the Hall of the Fallen.

For Classic Era (Hardcore, Season of Discovery) and World of Warcraft: Forever. A sibling of [Lorekeeper's Codex](https://www.curseforge.com/wow/addons/lorekeepers-codex) and [Explorer's Field Journal](https://github.com/salty-max/field-journal), in the same look (each in its own colours), but it stands alone.

## A page of it

> I took to the road in Durotar, and it looked friendly enough, which in my experience is the moment to look twice. I came into the Barrens for the first time, and wondered straight away what grew and swam there and how much of it was good to eat. I thinned the Razormane quilboars that had been attacking the supply lines from Durotar, for Thork at the Crossroads. I tamed my first companion and called it Dusk, and from then on I did not hunt alone. I rested in the Barrens, and gave my curiosity a rest along with my legs.

## What an entry tells

An entry runs from one rest to the next. Logging out in the wild is a night outdoors, and the entry goes on; after four hours of play, the next logout ends it wherever you are. It tells what weighs most:

- **The milestones of a life**, always: what defines your class as you grow into it (a warlock's demons and summoning circle, a hunter's companions, a druid's forms, Moonglade and Rebirth, a shaman's favour from each element and the ghost wolf, a warrior's charge, stances and second weapon, a paladin's auras, Lay on Hands, Redemption and Divine Shield, a rogue's second blade, poisons and vanishing, a priest's own people's prayers, a mage's sheep and first way home), and what a class's own quest taught you.
- **The story**: the work that mattered most, told as you did it and why (from the quests' own words: "I killed Hogger, the huge gnoll who had overpowered every attempt at his capture"), naming who was at your side when it was done, picking up a story left off in an earlier entry, and now and then a word on what it meant to you.
- **The dangers**: how you died and came back, or the closest call (under a tenth of your health, and alive to tell it); the foes worth naming, rares and elites; a dungeon and its last boss; a player of the other faction killed in the open world (battlegrounds are not part of the tale).
- **The road**: the lands, towns and dungeons seen for the first time, each described as your character meets it; your people's capital; the company you kept; the fires you stopped at (shared with companions, or one of Forever's camps); a rare find (epic and better).
- **What you became**: the way you chose (your specialization, never the talents themselves), the spells worth a line of their own, a new way of fighting, a trade taken up and what your hands made, the gear you first put on while the levels are low (a blue piece, or one you made yourself), learning to ride and your first ride on your people's own mount, the first bag and the first gold piece, a companion at your side, and the times it fell.

A quiet stretch is a short entry; a big one runs longer. Reaching the highest level of your game is a moment of its own, and the journal goes on after it.

The journal is yours too: give an entry a title of your own, or write a note in its margin, from the Edit button on its page (or `/ht title TEXT` and `/ht note TEXT` for the last entry). The journal's own words never change; yours show beside them, in the game and on hearthtale.app.

A character you already play gets a prologue from what the game knows of its life so far, and entries from there.

## How it is written

- In the first person, in your race's own voice: what it notices and how it says so (a dwarf's eye for stonework, a troll's appetite, a Forsaken's dry patience), never a caricature. Graver on Hardcore, and graver still as the levels climb.
- About 1,900 lines and phrases, some 240 descriptions of places, and over 3,200 quests' own stories, chosen to fit the moment: the hour, the first time or the tenth, how close the call, alone or in a group. A line doesn't come back soon after it was used.
- Each entry is titled by its weightiest moment, in the game's own words: a companion's name, a dungeon, the quest that mattered most ("The Stolen Journal", "Zalazane", "Escape Through Stealth").
- The entry you are living is written again as you play; a finished one stays as it was.
- Written from what the addon records each time you open the book, so better sentences in later versions reach your old entries too. At each logout the book is also saved as written, for hearthtale.app.

## Hardcore: the Hall of the Fallen

When a Hardcore character dies, its book closes: an epitaph telling how it ended and what the life was, a line in chat and the game's alert. The book joins the **Hall of the Fallen**, shared by all your characters, where every fallen life can be read again, entry by entry. On other realms, a death is told in its entry, and the book goes on.

## Read it on hearthtale.app

Your journal, on your phone too: **[hearthtale.app](https://hearthtale.app)** shows each book exactly as the game wrote it. It's optional: the addon works on its own, in game.

1. Install **[Ravenpost](https://github.com/salty-max/ravenpost)**, the free companion app (Windows and macOS, open source; it also serves WoWLocker). Addons can't use the network: Ravenpost sends each character's book a few seconds after you log out or `/reload`.
2. In Ravenpost, click **Link Hearthtale** and sign in with Battle.net on hearthtale.app: your Classic Era characters are recognised on their own.
3. World of Warcraft: Forever characters (or any Battle.net can't find): get a code in the library on hearthtale.app and type `/ht link CODE` in game.

Books are private: only you see them. Ravenpost sends the book and who it belongs to, nothing else; the addon's records stay on your computer. Step by step: [hearthtale.app/start](https://hearthtale.app/start).

## The book

`/hearthtale` (or `/ht`), or the book by the minimap, opens it: your portrait, and on Hardcore its mark beside it (a skull, then "Fallen" once the book closes); the entries on the left by their titles (a skull marks a close call, a star a rare); the open one on the right, its number and whether it is still being written above the title, where, at which levels and when under it. A second tab holds the Hall of the Fallen. When an entry is written, a line in chat links to it.

## In English

The journal is written in English, for English game clients. On a client in another language, the names it uses (places, creatures, quests, items) come from your game in that language, inside English sentences, and a few lines that rely on the game's English names are left out, learning to ride among them.

## Two packages

Each game has its own file: pick the one for yours (the CurseForge app does it for you).

- **Classic**: Classic Era, Hardcore, Season of Discovery.
- **Forever**: World of Warcraft: Forever. Forever closes the combat log to addons, so kills come from the game's own kill event. Inside a Forever dungeon that event hides which creature fell, so only the kills a quest counts are told there.

## Settings

The first time each character logs in with Hearthtale, a welcome page introduces the journal and offers its choices (`/ht welcome` shows it again). After that: Options → AddOns → Hearthtale (or `/ht settings`, or right-click the minimap button): a line in chat for each entry, the alert when a book closes, the minimap button and where it sits. Where the game can't tell whether a character is Hardcore, a setting lets you say so.

Settings are each character's own, as in most interface addons. A new character can take another's: choose one of your characters of the same game from a list (on the welcome page or the Options page), or bring them from anywhere, another game or another account, with a code: `/ht export` (or the welcome page's Give a code) on one character, `/ht import CODE` (or Use a code) on the other.

Other commands: `/ht title [N] TEXT` names entry N (the last one without N), `/ht note [N] TEXT` writes in its margin (no TEXT removes it); `/ht hall` opens the Hall of the Fallen; `/ht link CODE` links this character to your library on hearthtale.app; `/ht minimap` shows or hides the button.

## Source

Open source under GPL-3.0-or-later: [github.com/salty-max/hearthtale](https://github.com/salty-max/hearthtale). What the writer knows of the game comes from [cmangos classic-db](https://github.com/cmangos/classic-db) and [pfQuest](https://github.com/shagu/pfQuest); for Forever's new content, from [AllTheThings](https://github.com/ATTWoWAddon/AllTheThings) and [QuestieDB](https://github.com/Questie/QuestieDB)'s traces of the beta. Thanks to all of them. Not affiliated with Blizzard Entertainment.
