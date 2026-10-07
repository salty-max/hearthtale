# Hearthtale

A World of Warcraft addon: the character's own journal, written as it plays,
in the first person, in scenes (the moments in one place told together), a
chapter from rest to rest (a
logout at an inn, in a city, by a campfire); on Hardcore, an epitaph and the
Hall of the Fallen. Sibling of Lorekeeper's Codex and Explorer's Field Journal
(same games, look and tooling), but standalone: it reads none of their records.
The plan and its decisions: PLAN.md.

## Layout

- `writing/<kind>.md`: the sentences of one kind of moment (front matter
  `kind:`; one `- sentence` per line, optional `[tags]` = the conditions it
  needs). Built by `scripts/build.ts` into `addon/Hearthtale/Data_Classic.lua`
  and `Data_Forever.lua` (one per game; `client:` tags keep a sentence to one).
- `writing/voices/<Race>/<kind>.md`: a race's own sentences (same format,
  `<Race>` as the game names it: `Scourge`, `NightElf`). The writer prefers
  them, lets a used one back after `OWN_GAP` uses of the kind, and falls back
  on the shared ones; `STYLE` in `Writer.lua` keeps three clauses available
  for every race and varies time words. Flavour comes from outlook and phrasing, never
  from broken grammar or a racial caricature. `docs/race-voices.md` records
  the lore sources, cultural outlooks and limits on expression for all races.
  Skyborne traditions require the recorded faction and the Forever catalog.
- `writing/r-<pool>.md` (and `voices/<Race>/r-<pool>.md`): remarks, the
  narrator's reaction a routine clause may end with ("…, with rather more
  appetite for a cooked supper"). Pools by subject: `r-foe`, `r-first`,
  `r-item`, `r-task`, `r-gear`, `r-lesson`, `r-road`, `r-inn`, `r-company`
  (`ROUTINE` in `Writer.lua` maps each clause kind to its pool). Each is a
  phrase after a comma: lower case, no stop, no leading "and". At least 12
  shared, 8 per race.
- `addon/Hearthtale/Names.lua` (generated, committed): how the game itself
  writes its names, counted over all its quest texts and NPC speech: places
  with or without "the", creatures by name ("Hogger"), as one of a kind ("the
  Defias Messenger") or with "a", quest items' plurals ("8 Tough Wolf Meat"),
  role owners in item names ("a Champion's Helm" vs "Zanzil's Seal"). Where the
  game is silent, `scripts/names.ts` decides from the name (English words
  and given names from npm: an-array-of-english-words, human-names) and the
  writer's rules the rest. `bun run audit`
  downloads the data (cmangos classic-db, pfQuest's places) into `.cache/`,
  regenerates Names.lua and runs `addon/test/audit.lua`: every place,
  creature, objective and item of the game through the writer, reviewed in
  `.cache/audit/report.txt` and checked for regressions; then
  `addon/test/playthrough.lua`: each race played from level 1 to 30 on the
  game's real quests (its levelling road, real givers, targets, droppers,
  enders and rewards), every chapter through the shared checks
  (`addon/test/inspect.lua`), the books in `.cache/audit/books/` to read.
  Fix by rule, never by name.
- `writing/scenery/<slug>.md`: a place described the first time a book meets
  it (front matter `place:`, `type:` zone | town | dungeon, `faction:`
  alliance | horde | neutral, optional `home:` races). Lines tagged by
  viewpoint: `[home]`, `[ally]`, `[foe]`, `[neutral]`, plus `[night]`; 2-3
  sentences each.
- `addon/Hearthtale/`: `Core.lua` (the character's record, events,
  `/hearthtale`), `Record.lua` (the chapters and their moments, as they happen;
  a logout settled at the next login: under 30 minutes away it's no break,
  nothing told; indoors without an inn, a night `inside`. Kills on Forever,
  without a combat log: the target watched through the fight, its health and
  flags, one fought and seen dying is a kill, not one another claimed),
  `Writer.lua` (the prose, written from the records when read),
  `Save.lua` (the book written into the saved file at each logout, for the
  site: it never writes its own),
  `Book.lua` (the window: chapters on the left, the open one on the right; a
  second tab for the Hall of the Fallen), `Hall.lua` (a Hardcore death: the
  book closed and copied to the account-wide Hall, a chat line, the toast),
  `Settings.lua` (account settings, the Options page), `Minimap.lua`.
- `addon/CURSEFORGE.md`: the project page. `assets/logo-master.png` is the
  painted logo master; `assets/logo.png` and `assets/logo-1024.png` are its
  512px and 1024px exports (resize the master with magick). The
  prompts are in `assets/logo-prompts.json`.
  The source TOC has an `@INTERFACE@` placeholder: not installable as is;
  `scripts/package.ts` builds `dist/classic` and `dist/forever`.
- `addon/test/game.lua`: the fake game (WoW API, events, a character to play,
  the addon loaded), shared by:
  - `addon/test/sim.lua`: a life replayed, every recording asserted, its book
    written. `FOREVER=1` runs it as Forever.
  - `addon/test/lives.lua`: lives played through the addon, as the game would
    send them (Brannok, a Hardcore dwarf hunter; Pippa, a Hardcore gnome mage
    who falls; Aldric, a human paladin met mid-life; Grashnak, an orc warrior;
    Aelyndra, a night elf druid; Mortis, a Forsaken priest; Edric, a human
    warrior's evening in the Deadmines, its quests, mobs, bosses and loot as in
    Classic), shared by:
  - `addon/test/sample.lua`: the first chapters, `luajit addon/test/sample.lua > docs/sample.md`;
    the evening, `luajit addon/test/sample.lua deadmines > docs/sample-deadmines.md`;
  - `addon/test/seed.lua`: the seven lives, logged out so the addon saves their
    books, as the site's test data (`bun run addon:seed` writes
    `apps/api/src/db/seed/characters.json`; `bun run db:seed` loads it).
- `addon/test/writer.lua`: hundreds of imaginary lives (every race and class,
  Hardcore or not, met mid-life), every chapter checked; every sentence must be
  reachable, none used again within 6 uses of its kind, and a chapter told one
  moment more keeps what it had (but its last sentence).
- `addon/test/voices.lua`: the same synthetic day for each narrator, to compare
  diction and rhythm without changing events: `FOREVER=1 luajit
  addon/test/voices.lua compare > .cache/race-comparison.md` (read, not kept).
  Its `moments` mode: flights, outdoor rests, setbacks, revival, dungeon
  endings and the final page for each voice.

## Writing the sentences

- Write a recollection through the protagonist's eyes. Let an observation
  lead to a reaction, and give danger, loss and a new power room to matter.
  Prefer connected thoughts to short fragments, a checklist or "Place: text".
  Concrete details should carry the feeling; avoid repeating abstract remarks
  about the account, the journey or remembering in every line.
- Scenery is experienced, not announced: what I notice, how it meets me,
  what that makes me think. Keep its landmarks true to the original game and
  its viewpoint appropriate to race, faction and time of day.
- Clauses (kinds `c-*`) make the scenes: lower case, no final stop, read after
  "I" ("bound my hearthstone {inn}"). Related work may share a sentence;
  an arrival frames one action. Internal commas are allowed; a semicolon or
  full sentence closes the thought. Test joins in the generated sample.
- A remark reacts to what the record shows (the fight, the find, the walk,
  the hands, the hour) or to the narrator's own feeling, never a general moral
  ("a job done properly, the only sort worth doing") and never an invented
  fact: no lamps, fires, innkeepers, trainers' manners, payments, stories, a
  companion's looks or talk. After my own action (road, lesson, company,
  errand) it can't start with a past participle (it reads as a second verb:
  "I took up tailoring, practised…"; the build refuses it). "it" only with
  `[one]` (a lesson of several spells is "them"; the build refuses "it"
  without `[one]` in a lesson's remark).
- Name things once: within a paragraph, a person already named is not named
  again (a deed drops who asked; a return, a delivery, a message or a
  giver's request takes its `[again]` wording, "I reported back once more");
  a creature just killed is "five more" or "one of them"; a thing delivered
  just before is "it" (`[onward]`), further back "the ring". The playthroughs
  fail on a quest giver named three times in a paragraph.
- The races must sound apart (the build checks it): a remark's first three
  words open remarks of two races at most, and a pool holds two stock
  feelings ("glad", "pleased", "relieved", "curious", "surprised") at most.
  Reach for what the race notices and how it says so, not a feeling word.
- Routine clauses (`c-*`) are plain facts; the voice of a routine moment is
  in its remark (`r-*`). The writer adds one to roughly one routine clause in
  three, at most one per sentence, never in consecutive sentences, and none
  to a clause that already has a comma. A remark reacts to the subject (the
  foe, the find, the lesson, the place), with a range of feeling: curiosity,
  pride, unease, humour, not only weariness. It must read after one foe or
  several, one item or a plural one ("Sentinel Trousers"): `[one]`/`[!one]`
  for number, no "it" for an item, no "there" (the writer's own). Returns
  are `[back]`, first arrivals `[!back]`. A race's own remarks come first, and
  come back after `REMARK_GAP` (10) chapters; shared ones fill every other
  gap; otherwise the clause goes without. A routine clause avoids the verb of
  the one before. Race files hold only routine lines unique to the race.
- Moments of their own: a world PvP kill (`pvp-one`, by name, race and class
  when alone; `pvp-many` when several fall within ten minutes; nothing in a
  battleground), a death's aftermath (`revived`: `[corpse]` ghost run,
  `[healer]` spirit healer, `[ally]` raised by a companion, `[self]` soulstone
  or ankh), a dungeon's or raid's last boss (`boss-final`), the journey's end
  at the game's highest level (`summit`: the journal stops recording). A
  stretch at a craft is one clause (`c-made`); a raid is one moment (`c-raid`).
  A quest's work is told where it was done (`done`), its turn-in a short return
  (`c-report`); handed in on the spot (the turn-in next, same place), told once
  at the turn-in with whom it was for (`c-handed-item`, `c-handed-kill`:
  "I brought Sten Stoutarm eight Tough Wolf Meat"); an abandoned quest's work
  is taken back. A night and its waking under 30 minutes apart (older
  journals) aren't told; indoors, `night-in`/`wake-in`.
- Curation: in each place, the first two routine hand-ins (a delivery, a report
  back, a message, a favour known only by who asked, green gear) are told; the
  rest fold into one clause (`c-fold`: "saw to four more errands besides"),
  written once the place is left or the chapter ends, so finished sentences
  never change.
  Deeds, firsts, dangers and finds are always told.
- Weight (`weigh` in Writer.lua), from the moment alone so a later moment never
  rewrites what was read: 0 a hand-in (no remark), 1 the ordinary, 2 a deed,
  3 a highlight (a first, an elite, a tamed pet, one named foe asked for, an
  escort). A highlight has a sentence to itself (an arrival may frame it) and a
  remark whenever one is free, even after a remarked sentence. A remark never
  repeats a word of its clause's own wording (made/making, own, hand, work).
- Openings: a clause tagged `[turn]` has its own subject ("{foe} fell to me",
  "the road brought me to {place}"): it opens a sentence alone and is only
  chosen when no remark is wanted (a remark's subject is "I"). Frame pools
  (opening, rest, wake, campfire, recaps) mix in lines that don't start with
  "I". A routine hand-in fold is told once per place.
- Remarks about the moment: a foe's people or kind (`foeOf`: murloc, gnoll,
  outlaw, undead, ... from the game's name, humanoids only) and a find's kind
  (`thingOf`: egg, hide, paper, plant, stone, relic, remains, ...) tag the
  clause. A fresh remark about that subject wins over a general one, even the
  race's own; an ordinary fight (a stray kill) takes a specific remark or
  none (`GATED`). Number agreement is checked by the build ("their" needs
  [!one] in r-foe; "it"/counts in r-item).
- The chapter's recap (tasks, fighting, time) holds one thought: the others
  are its `[plain]` sentences. The rest that ends the chapter has its own.
- Topic tags (teeth, mechanical, cloth, meat, explore, escort, made) require
  evidence in the records. Taming objectives leave the telling to the pet record;
  no later pet event may remove an already written quest sentence.
- Connectors need evidence: time passing, nightfall, an arrival, or the
  aftermath of a close call. Do not scatter "then" between unrelated jobs.
  A return is a return. Emotional interpretation is welcome; an unrecorded
  action, spell cast, trophy, payment or another person's reaction is not a
  fact to invent. A dwarf hunter does not automatically wield a hammer.
- Tell a close call as an experience, with its consequences for the narrator;
  keep the health percentage in the record. Closing recaps should not repeat
  kills already described by quest objectives.
- One kind per file; the slots of each kind are listed in `scripts/build.ts`
  (KINDS), plus the voice: {home}, {kin}, {faith} (missing for some, so the
  sentence is skipped), {weapon} (an object only: "fell to {weapon}", never
  "{weapon} was").
- A place is named, then "there" once, then left out: a sentence with {at} must
  read well without it ("I put down {n} {foes} {at}."). Without a verb, use
  {in}, which always names the place ("{foe} {in}.").
- Tags are conditions: night, hc, high (level 40+), low (10 and under: no
  hunter's pet yet, so its lines are [class:HUNTER !low]), first,
  elite, lots, many, slow, quick; for a death: foe, fall, drowning, lava, nature,
  beast, people, player, inside; race:X, class:X, faction:x, client:x;
  "!night" = not at night. A tagged sentence is preferred while fresh, so voice
  lines come early; an epitaph's line that tells the cause always wins.
- The epitaph (epitaph, remembrance, farewell) is in the third person, by the
  name; the rest of the book in the first. A count of one never meets a
  plural ("one tasks"): such slots are left empty for one.
- After changing the writing: `bun run addon:build`, then `bun run addon:check`,
  regenerate `docs/sample.md` and the site seed (`bun run addon:seed`), and
  read the generated books again. Check flow across sentences, not just the
  quality of each template alone: read paragraphs. Concrete observation does
  more work than remarks about "the journey", "my account" or "remembering".
  A racial voice is a way of looking at the world, not an obligation to
  mention ale, honour, trees or the grave in every sentence. Places in
  flowing sentences, not chains of possessives ("the cold of Dun Morogh", not
  "Dun Morogh's cold"). Regenerate and read the race comparison (`voices.lua
  compare`) when changing racial expression; use the restraint and era
  boundaries in `docs/race-voices.md`.
- In `c-inn`, `{inn}` includes its preposition ("at Ratchet") or is "there" when the
  binding place has just been named. Do not add "at" or "to" before it.

## The site (hearthtale.app)

A monorepo around the addon (Turborepo + Bun workspaces, as WoWLocker): the
site shows the book the addon saves at logout (Save.lua), never writing its own.
Plan and steps: PLAN.md, "The site".

- `apps/api`: Hono on Bun (`src/app.ts`), Postgres through drizzle
  (`src/db/schema.ts`, migrations in `drizzle/`), `src/vercel.ts` the Vercel
  function (bundled by `scripts/vercel-build.sh`).
- `apps/web`: React 19 + Vite + Tailwind v4 + TanStack Router/Query, an
  installable PWA laid out as a native app: the window never scrolls (only
  `main`, and in the reader only the book's text), a top bar that never wraps,
  a bottom tab bar on phones (Library, Get started, Settings). Reading options
  (size, typeface, paper, line spacing) and the language code in `lib/settings.ts`
  (per device), set on `/settings`. Routes in `src/router.tsx`; every visible string in
  `src/lib/i18n.ts` (English only for now, the books being English: another
  language is one more catalog typed on `en` in CATALOGS, with its locale for
  dates; the language setting shows once there are two); the look (the in-game book: leather,
  parchment, the addon's gold) in `src/index.css`.
- `packages/shared` (`@hearthtale/shared`): the wire contract, the saved book's
  shape (mirrors Save.lua). Source of truth.
- Hosting: Vercel (team jellycat, project `hearthtale`, linked: `.vercel/`),
  Neon through the Vercel integration (DATABASE_URL pooled, DATABASE_URL_UNPOOLED
  for migrations, applied on production deploys). Battle.net keys in
  `apps/api/.env.local` (gitignored) and Vercel. `vercel link` and the Neon
  integration append `.env*` to .gitignore and drop vendor skills
  (`.agents/`, `.claude/skills`, `skills-lock.json`): keep them out.
- Local: `bun run db` (Postgres on :5435), `bun run db:migrate`,
  `bun run db:seed` (the test characters), `bun run dev` (api :3002, web :5175).
  The library (`/library`) and the reader (`/book/:id/:part`: one part per
  page, the contents in a drawer; `/book/:id` opens the part to read).
- Accounts (`lib/accounts.ts`, `lib/login.ts`): "Sign in with Battle.net" in a
  region (`/api/auth/login?region=eu`, back on `/api/auth/callback`: both
  APP_ORIGIN's, registered on develop.battle.net); the session is a cookie
  (`ht_session`, only its SHA-256 kept). Books are private: a character is its
  owner's (`characters.owner_id`), proved by the login (its Battle.net character
  ids: the GUID's hex part, `lib/guid.ts`) or by a link code (`lib/link.ts`:
  `/ht link CODE` in the game, kept in the saved file, claimed by the upload).
  Locally, "Use the test account" (`/api/auth/test`, never on Vercel) owns the
  test characters.
- Sharing (`lib/sharing.ts`, `lib/og.ts`): an owner's share links (`shares`:
  a token, the whole book or one part, deleted to revoke) read on `/s/:token`
  without an account, cut to what they cover (`cutBook`) with nothing private
  of the character (`PublicCharacter`); a fallen book its owner shows in the
  Hall (`characters.in_hall`) reads on `/hall` and `/hall/:id`. Link-preview
  crawlers on those pages get an OpenGraph card from the function
  (scripts/vercel-build.sh routes them by user agent; `/api/og/…` by hand).
  The web reader is one component (`components/Reader.tsx`, parts by address)
  for my books, share links and the Hall.
- The companion, Ravenpost (`lib/companion.ts`, `lib/upload.ts`): pairing
  device-code style (`/api/companion/pair/start` → the user confirms on
  `/pair?code=…` → `/pair/poll` hands the token over once; only its hash is
  kept), then `POST /api/companion/upload` (Bearer token) with
  `{ characters: [HearthtaleChar] }`, one character per request (Vercel takes
  4.5 MB). A book is kept only for a proven owner (Battle.net, already the
  account's, or a link code in the record); otherwise "unlinked", unstored.

## Commands

```bash
bun run addon:build | addon:check | addon:package   # the addon
bun run dev | typecheck | lint | test | build       # the site
bun run check                                       # everything
bun run db | db:generate | db:migrate | db:seed
bun run addon:seed                                  # regenerate the test characters
scripts/release.sh [--version X.Y.Z] NOTES.md       # the addon: tag, push; Actions publish
```

## Conventions

- Plain ASCII in `writing/` (' and plain quotes).
- Conventional Commits, lowercase subjects; push freely, ask before releasing.
- Lore and places true to the original game; the writing is in the first
  person, never the League's voice.
