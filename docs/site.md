# The site (hearthtale.app)

(Moved from CLAUDE.md on 20 October 2026.)

A monorepo around the addon (Turborepo + Bun workspaces, as WoWLocker): the
site shows the book the addon saves at logout (Save.lua), never writing its own.
Plan and steps: PLAN.md, "The site".

- `apps/api`: Hono on Bun (`src/app.ts`), Postgres through drizzle
  (`src/db/schema.ts`, migrations in `drizzle/`), `src/vercel.ts` the Vercel
  function (bundled by `scripts/vercel-build.sh`).
- `apps/web`: React 19 + Vite + Tailwind v4 + TanStack Router/Query, an
  installable PWA laid out as a native app: the window never scrolls (only
  `main`, and in the reader only the book's text), a top bar that never wraps
  (the logo, the menu, signed in "Link a character": a popover with a link
  code, `LinkCharacter`; the day/night toggle), a bottom tab bar on phones
  (Library, Hall, Get started, Settings) that steps aside while a book is read
  (`lib/reading.ts`), a footer under every other page. The site by day or by
  night (`site`: as the device, day, night; `public/theme.js` sets it before
  the first paint, `lib/theme.ts` after), the reading options (size,
  typeface: a printed book's or plain; paper, line spacing) and the
  language code in `lib/settings.ts` (per device), set on `/settings`. Routes
  in `src/router.tsx`, each page its title (`lib/title.ts`); every visible
  string in `src/lib/i18n.ts` (a catalog typed on `en` in CATALOGS, with its
  locale for dates: English and French since 3 November 2026, French in the
  family's interface register, vous and nothing agreeing with the reader; none
  chosen, the browser's first language that has one; `<html lang>` follows
  it). The
  interface and the books are two languages, as in the game (3 November
  2026, the user's rule: the window's labels follow the client, the
  journal's prose its own language). Every label around a book is the
  interface's, `packages/shared/src/frame.ts` in the site's language
  (`useFrame()`: "Entry 3" or "Entrée 3", prologue, epitaph, the levels line,
  "to" between dates, a note's label, "The journal of X", the race and class
  with a woman's names), in the reader, contents, print, Markdown and EPUB,
  the road, a library card, the Hall, shared pages. The book's language
  (`Book.language`, "enUS" or "frFR", an old book English) only tags its own
  words with `lang` (`langOf`; `partLang` for a part's title: an entry's own
  title is the book's, "Entrée 3" the site's), and is the EPUB's
  `dc:language`. A push is worded in its device's site language
  (`push_subscriptions.language`, sent again on a change; one kept before
  it: the book's), a preview card in the crawler's Accept-Language
  (`frameLanguage`), else the book's. The sex the names agree with is the
  book's (`Book.sex`), else Battle.net's (`characters.sex`, from the
  sign-in's profile, kept per owned character in `accounts.owned`'s `women`
  and `men`, which Ravenpost's sign-in leaves as they were), else none:
  French's masculine. It is never shown as such (the user's choice, 3
  November 2026), only agreed with. A language switch in the
  game writes the whole journal again: the upload replaces the book, tells
  no "new entry" (`finishedSince`), and keeps share links (an entry number
  that is gone reads "gone"); the look
  in `src/index.css` (the in-game book: leather lit by a hearth, or a scribe's
  desk by day; parchment pages; the addon's gold; three faces, as
  WoWLocker's: Cinzel for titles and names (`font-display`), EB Garamond for
  the book (`font-book`, the reader's default), Inter for the rest
  (`font-sans`); `.panel`, `.btn`, `.title-gilded`,
  the class colours by day and night). The pictures (the
  logo at every size, the class crests: the game's UI-Classes-Circles) come
  from `apps/web/scripts/assets.py`, committed.
  The library (`/library`): the last written to first, each book's crest,
  latest entry, "New" since this device last read it, a button to the road
  so far (`lib/seen.ts`: what this device read, and where a book reopens). The
  reader: the contents beside the page on a wide screen, the arrow keys and a
  swipe turn the pages, an entry's dates as the addon's header; on my books,
  the road so far a button away (`/book/:id/road`: figures, the levels over
  the days, the places, each entry), and the More menu: share, download
  (`lib/export.ts`: EPUB through `lib/zip.ts`, text, or printed from
  `PrintBook`), remove. A shared book or a
  Hall book tells a visitor what Hearthtale is. A saved file brought by hand
  (`/upload`, read in the browser by `lib/luasv.ts`, a port of Ravenpost's
  parser) goes through the same upload as the companion's. Notifications of a
  new entry (Settings; `lib/push.ts`, `public/push-sw.js`, imported by the
  service worker). `/privacy`.
- `packages/shared` (`@hearthtale/shared`): the wire contract, the saved book's
  shape (mirrors Save.lua). Source of truth.
- Hosting: Vercel (team jellycat, project `hearthtale`, linked: `.vercel/`),
  Neon through the Vercel integration (DATABASE_URL pooled, DATABASE_URL_UNPOOLED
  for migrations, applied on production deploys). Battle.net keys in
  `apps/api/.env.local` (gitignored) and Vercel. `vercel link` and the Neon
  integration append `.env*` to .gitignore and drop vendor skills
  (`.agents/`, `.claude/skills`, `skills-lock.json`): keep them out.
- Dependencies: `bun audit` clean but for two dev-only ones with no fix
  (deepmerge under vite-plugin-pwa, esbuild 0.18 under drizzle-kit). The root
  `overrides` lifts zod past a memory advisory: `@vercel/cli-config` (under
  `@vercel/functions`' OIDC path, never in the API's bundle) pins 4.1.11
  exactly. Drop it once that pin reaches 4.6.6.
- Limits and upkeep (`lib/ratelimit.ts`): every route that writes or reaches
  Battle.net has a per-caller limit (a fixed window, counted in `ephemeral`
  under kind "rate", the address pseudonymised by a hash and an IPv6 one cut
  to its /64, a row a day at most), 429 with Retry-After past it (the sign-in
  back to `/library?signin=busy`), open if the counter fails. Expired ephemeral rows and sessions go in a daily
  Vercel cron (`/api/cron/sweep`, declared in `scripts/vercel-build.sh`'s
  config.json, guarded by CRON_SECRET, set in Vercel: without it the route is
  a 404), now and then on a login and on a limited request too.
- Local: `bun run db` (Postgres on :5435), `bun run db:migrate`,
  `bun run db:seed` (the test characters), `bun run dev` (api :3002, web :5175).
  The landing (`routes/Home.tsx`) shows a page of each sample journal, one
  voice at a time (`lib/samples.ts`: the writer's own, never edited by hand;
  one of them French: its words in French, the labels around them the site's).
  The library (`/library`) and the reader (`/book/:id/:part`: one part per
  page, the contents in a drawer; `/book/:id` opens the part to read).
- Accounts (`lib/accounts.ts`, `lib/login.ts`): "Sign in with Battle.net" in a
  region (`/api/auth/login?region=eu`, back on `/api/auth/callback`: both
  APP_ORIGIN's, registered on develop.battle.net); the session is a cookie
  (`ht_session`, only its SHA-256 kept). Books are private: a character is its
  owner's (`characters.owner_id`), proved by the login (its Battle.net character
  ids: the GUID's hex part, `lib/guid.ts`) or by a link code (`lib/link.ts`:
  `/ht link CODE` in the game, kept in the saved file, claimed by the upload).
  A code attaches only a character nobody owns or its own account owns, never
  one another account holds ("owned": a saved file is editable, so a code
  proves a request, not a GUID). To move a book between accounts the old owner
  removes it on the site first, or (Classic) Battle.net proves the new owner. The gap:
  on Forever characters Battle.net now lists (`profile-forever-<region>`,
  5 November 2026) the account owns them with no code, see "Forever
  ownership" below; for the rest (a character the list lacks), whoever links a GUID first
  keeps it, so a squat is released by hand once a player's report checks out:
  `bun run db:release <guid> --to <account id> --yes` gives the row to the
  verified owner (their next upload replaces the book, no code, no race),
  without `--to` the row goes. From the root it runs on Neon's production
  (`.env.local`), and it prints the database's host first.
  Locally, "Use the test account" (`/api/auth/test`, never on Vercel) owns the
  test characters.
- Forever ownership (`lib/accounts.ts`, `lib/ravenpost.ts`, `lib/upload.ts`
  `proof`, `lib/bnet.ts` `foreverTuple`): `accounts.owned` entries carry a
  `game` (none stored = `classic1x`, read through `gameOf`: no data migration);
  a Forever entry also holds `characters: [id, "<pseudo-realm>", "Name Surname"]`
  (6946 for every EU character seen). The passport's Forever entry is
  `{ region, game: "forever", ids, characters }`; Ravenpost's sign-in and the
  site's own (the account list of `profile-forever-<region>`, the realm read
  from each character's protected link, no link = not owned) write the same
  entry. An uploaded GUID is owned when its realm AND hex id are in the tuples
  (`owns`; `Player-6946-000A44D0` = 672976, **confirmed on 5 November 2026**
  against a real Forever GUID: realm part = the list's pseudo-realm, hex part =
  the character id; whether 6946 is per region or per ruleset is still unknown,
  so no realm grants anything by itself. The log line `forever.unmatched` `{ guid, name, unmatched }` (counts)
  after an upload says whether it held). The game is decided by the GUID's
  realm against the signed entries, never by the saved file's `client`; a
  Classic id is refused in a Forever realm already seen (`FOREVER_REALMS`, a
  list that only ever refuses, never grants), and Forever's
  claim never takes a row another account holds (so a squat on a listed
  character, by a link code, is still released by hand), and a row kept as
  Forever (`book.client`) is never taken on a Classic id, in any realm. The name fallback
  (`ownsByName`) is off unless `FOREVER_NAME_MATCH=1`: a name proves nothing
  about a GUID that is public in the game, so it is for the day the GUID rule
  is disproved only. The link code stays for what the list lacks; its top-bar
  panel is the account's, not per character, and stays. A site sign-in
  replaces the entry of a game only when that game's list answered (200 or 404).
- Sharing (`lib/sharing.ts`, `lib/og.ts`): an owner's share links (`shares`:
  a token, the whole book or one part, deleted to revoke) read on `/s/:token`
  without an account, cut to what they cover (`cutBook`) with nothing private
  of the character (`PublicCharacter`) nor the player's notes (`withoutNotes`,
  the Hall's books too); a fallen book its owner shows in the
  Hall (`characters.in_hall`) reads on `/hall` and `/hall/:id`. Link-preview
  crawlers on those pages get an OpenGraph card from the function
  (scripts/vercel-build.sh routes them by user agent; `/api/og/…` by hand).
  The web reader is one component (`components/Reader.tsx`, parts by address)
  for my books, share links and the Hall; a chapter reads as its diary entry
  (`BookChapter.diary`; a book saved before entries were, its prose, `text`),
  the player's own note under it (`note`).
- The companion, Ravenpost (`lib/companion.ts`, `lib/upload.ts`): pairing
  device-code style (`/api/companion/pair/start` → the user confirms on
  `/pair?code=…` → `/pair/poll` hands the token over once; only its hash is
  kept), then `POST /api/companion/upload` (Bearer token) with
  `{ characters: [HearthtaleChar] }`, one character per request (Vercel takes
  4.5 MB). Ravenpost's one sign-in (`lib/ravenpost.ts`): its inbox
  (salty-max/ravenpost, `inbox/`) signs the player in with Battle.net and
  hands Ravenpost a passport (the Battle.net id, BattleTag, the characters
  owned per region; Ed25519, ten minutes, once), which
  `POST /api/companion/signin` checks with the inbox's public key (in the
  code; its dev key trusted off Vercel only) and turns into the account
  (`loginAccount` per region) and an upload token, no pairing page; the
  device-code pairing stays for older Ravenposts. A book is kept only for a proven owner (Battle.net, already the
  account's, or a link code in the record); otherwise "unlinked", unstored.
- Notifications (`lib/push.ts`, `lib/webpush.ts` from WoWLocker: VAPID and
  aes128gcm on Web Crypto): a browser's subscription per device
  (`push_subscriptions`, `POST`/`DELETE /api/push/subscriptions`, the key at
  `/api/push/key`); an upload that finishes entries the book before it hadn't
  (its same owner's) tells them, after the answer (`waitUntil`). An endpoint
  must be at a browser's push service (`isPushEndpoint`: FCM, Apple, Mozilla,
  Windows), on subscribing and again before each send (a stored one elsewhere
  is dropped), each send given up on after ten seconds, no redirect followed.
  Needs
  VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY and VAPID_SUBJECT (apps/api/.env.local,
  Vercel), optional: without them, no notifications and no Settings section for them, the site otherwise the same.
- A saved file brought by hand: `POST /api/upload` (signed in), the
  companion's upload as the session's account (`uploadAs` in `lib/upload.ts`).
- Removing a book (`DELETE /api/characters/:id`, `lib/characters.ts`
  `removeBook`; the bin beside "Share" in the reader, `RemoveDialog`, once
  confirmed): the book and its share links go, and a note (`removed`: the
  account, the GUID) refuses its companion's uploads ("removed", unstored)
  until a new link code typed in the game brings it back (`decide` in
  `lib/upload.ts` lifts the note).
