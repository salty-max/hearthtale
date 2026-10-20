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
  string in `src/lib/i18n.ts` (English only for now, the books being English:
  another language is one more catalog typed on `en` in CATALOGS, with its
  locale for dates; the language setting shows once there are two); the look
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
- Local: `bun run db` (Postgres on :5435), `bun run db:migrate`,
  `bun run db:seed` (the test characters), `bun run dev` (api :3002, web :5175).
  The landing (`routes/Home.tsx`) shows a page of each sample journal, one
  voice at a time (`lib/samples.ts`: the writer's own, never edited by hand).
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
  (its same owner's) tells them, after the answer (`waitUntil`). Needs
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
