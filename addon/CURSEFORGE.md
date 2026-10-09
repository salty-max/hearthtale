# Hearthtale

<!-- Project description for curseforge.com (paste as the project's description). -->

**Your character's own journal, written as you play.** Every quest, every new foe, every place, every close call, the gear you first wear and the trades you learn are written down as they happen, in your character's own voice, and a chapter closes when you rest: when you log out at an inn, in a city or by a campfire. On Hardcore, a death closes the book with an epitaph, and the life joins the Hall of the Fallen.

For Classic Era (Hardcore, Season of Discovery) and World of Warcraft: Forever. A sibling of [Lorekeeper's Codex](https://www.curseforge.com/wow/addons/lorekeepers-codex) and [Explorer's Field Journal](https://github.com/salty-max/field-journal), in the same look, but it stands alone.

## A page of it

> I reached Kharanos, took a room at Thunderbrew Distillery, then took up skinning. I began to learn leatherworking, learned what boars are like and found the Crag Boar Ribs Ragnar Thunderbrew wanted, six in all. After that, I put on a Handstitched Leather Vest, made with my own hands.
>
> Later that day, I walked into Shimmer Ridge and dealt with a Frostmane Snowstrider. I kept watch there more than I slept.

## What a chapter tells

A chapter runs from one rest to the next. Logging out in the wild is a night outdoors, and the chapter goes on; after four hours of play, the next logout closes it wherever you are.

- **The road**: where the chapter began, the lands and places seen for the first time, the inn you made your home, your flights, the campfires you sat by, the nights outdoors.
- **The work**: what each quest had you do (the wolves you hunted, the meat you brought, the message you carried), told where you did it, for whom, and who you returned to. A quest you abandon is left out.
- **The fights**: each new creature fought, the first of each kind, elites, rares, and the close calls (under a tenth of your health, and alive to tell it), by night or day; when the chapter closes, what you fought most.
- **The company**: who you grouped with, the dungeons and raids you went into and the bosses who stayed there.
- **The other side**: a player of the other faction you kill in the open world, by name, race and class, or several together when the fighting runs on. Battlegrounds are not part of the tale.
- **Death**: on a normal realm, how you died and how you came back: the run back from the graveyard as a ghost, the spirit healer's bargain, or a companion who raised you.
- **What you became**: what the trainer taught you; a druid's new forms, a warlock's new demons, a class's own steed; the professions you took up and their ranks, riding and the first ride; each piece of gear the first time you wear it (and if you made it yourself, the journal says so); a hunter's new pets, and the times they fell.
- **The rest**: the rare finds you loot (blue and better; a quest's reward is told when you wear it), an evening at your craft in one line, your professions' milestones, and at the end the time it took and the gold it brought.

The journal ends when you reach the highest level of your game: the last chapter closes there, with the journey's end.

A character you already play gets a prologue from what the game knows of its life so far, and chapters from there.

## How it is written

- Each chapter is a diary entry: the stretch as your character would write it at the rest that ends it, in your race's own voice. The milestones of your life first (a first demon, a new form, a companion, an element's favour), then what you did that mattered, told as you did it and why (from the quests' own words), picking up a story left off in an earlier entry, the dangers, the foes worth naming, new lands and powers. A quiet stretch is a short entry; a big one runs longer.
- In the first person, in scenes: what happened in one place is told together ("I reached Kharanos, took a room at Thunderbrew Distillery and found the boar ribs Ragnar Thunderbrew wanted"), and the road and the hours between scenes link them (I went back to Anvilmar; later that day; that night). Close calls, rares, nights and new powers get a sentence of their own. Now and then, the turns of phrase of your race and class: a dwarf's beard and ale, a Forsaken's second life, a paladin's Light, a hunter's pet.
- Graver on Hardcore, and graver still as the levels climb.
- Some 730 sentences and phrases, chosen to fit the moment: the hour, the first time or the tenth, how close the call, alone or in a group. A place just named becomes "there"; a sentence doesn't come back soon after it was used.
- The chapter grows as you play: the scene you are in may still grow its last sentence; what is written before it stays as it is.
- Written from what the addon records each time you open the book, so better sentences in later versions reach your old chapters too. At each logout the book is also saved as written, for hearthtale.app.

## Hardcore: the Hall of the Fallen

When a Hardcore character dies, its book closes: an epitaph telling how it ended and what the life was, a line in chat and the game's alert. The book joins the **Hall of the Fallen**, shared by all your characters, where every fallen life can be read again, chapter by chapter. On other realms, a death is told in its chapter, and the book goes on.

## Read it on hearthtale.app

Your journal, on your phone too: **[hearthtale.app](https://hearthtale.app)** shows each book exactly as the game wrote it. It's optional: the addon works on its own, in game.

1. Install **[Ravenpost](https://github.com/salty-max/ravenpost)**, the free companion app (Windows and macOS, open source; it also serves WoWLocker). Addons can't use the network: Ravenpost sends each character's book a few seconds after you log out or `/reload`.
2. In Ravenpost, click **Link Hearthtale** and sign in with Battle.net on hearthtale.app: your Classic Era characters are recognised on their own.
3. World of Warcraft: Forever characters (or any Battle.net can't find): get a code in the library on hearthtale.app and type `/ht link CODE` in game.

Books are private: only you see them. Ravenpost sends the book and who it belongs to, nothing else; the addon's records stay on your computer. Step by step: [hearthtale.app/start](https://hearthtale.app/start).

## The book

`/hearthtale` (or `/ht`), or the book by the minimap, opens it: your portrait and who you are; the chapters on the left (a skull marks a close call, a star a rare); the chapter's diary entry on the right. A second tab holds the Hall of the Fallen. When a chapter closes, a line in chat links to it.

## In English

The journal is written in English, for English game clients. On a client in another language, the names it uses (places, creatures, quests, items) come from your game in that language, inside English sentences, and a few lines that rely on the game's English names are left out: a first fight with a kind of beast, learning to ride, a trade's new rank.

## Two packages

Each game has its own file: pick the one for yours (the CurseForge app does it for you).

- **Classic**: Classic Era, Hardcore, Season of Discovery.
- **Forever**: World of Warcraft: Forever. Forever closes the combat log to addons, so kills come from the game's own kill event. Inside a Forever dungeon that event hides which creature fell, so only the kills a quest counts are told there.

## Settings

Options → AddOns → Hearthtale (or `/ht settings`, or right-click the minimap button): a line in chat for each chapter, the alert when a book closes, the minimap button. Where the game can't tell whether a character is Hardcore, a setting lets you say so.

Other commands: `/ht hall` opens the Hall of the Fallen; `/ht link CODE` links this character to your library on hearthtale.app; `/ht minimap` shows or hides the button.

## Source

Open source under GPL-3.0-or-later: [github.com/salty-max/hearthtale](https://github.com/salty-max/hearthtale). What the writer knows of the game comes from [cmangos classic-db](https://github.com/cmangos/classic-db) and [pfQuest](https://github.com/shagu/pfQuest); for Forever's new content, from [AllTheThings](https://github.com/ATTWoWAddon/AllTheThings) and [QuestieDB](https://github.com/Questie/QuestieDB)'s traces of the beta. Thanks to all of them. Not affiliated with Blizzard Entertainment.
