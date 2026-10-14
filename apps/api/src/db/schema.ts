import type { Book, Client, Region } from "@hearthtale/shared";
import { sql } from "drizzle-orm";
import { bigint, boolean, index, integer, jsonb, pgTable, primaryKey, serial, text, timestamp, uniqueIndex } from "drizzle-orm/pg-core";

/**
 * An account: a Battle.net login creates it (or finds it) and opens a session.
 * Logging in also proves which characters are the account's (their Battle.net
 * ids, per region): their books become its own.
 */
export const accounts = pgTable("accounts", {
  id: serial("id").primaryKey(),
  bnetId: bigint("bnet_id", { mode: "number" }).notNull().unique(),
  battletag: text("battletag"),
  /** Battle.net character ids the account owned at its last login, per region. */
  owned: jsonb("owned").$type<{ region: Region; ids: number[] }[]>().notNull().default(sql`'[]'::jsonb`),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  lastSeenAt: timestamp("last_seen_at", { withTimezone: true }).notNull().defaultNow(),
});

/** A signed-in browser: the cookie holds a random token, only its SHA-256 is kept. */
export const sessions = pgTable(
  "sessions",
  {
    tokenHash: text("token_hash").primaryKey(),
    accountId: integer("account_id")
      .notNull()
      .references(() => accounts.id, { onDelete: "cascade" }),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
    expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
  },
  (t) => [index("sessions_account").on(t.accountId), index("sessions_expiry").on(t.expiresAt)],
);

/** A computer's companion (Ravenpost), linked to an account: it uploads that account's books. Only its token's hash is kept. */
export const companionLinks = pgTable(
  "companion_links",
  {
    id: serial("id").primaryKey(),
    tokenHash: text("token_hash").notNull().unique(),
    accountId: integer("account_id")
      .notNull()
      .references(() => accounts.id, { onDelete: "cascade" }),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
    lastUploadAt: timestamp("last_upload_at", { withTimezone: true }),
  },
  (t) => [index("companion_links_account").on(t.accountId)],
);

/** Short-lived state shared by every server instance (a login under way, a link code). */
export const ephemeral = pgTable(
  "ephemeral",
  {
    kind: text("kind").notNull(),
    key: text("key").notNull(),
    data: jsonb("data").notNull(),
    expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
  },
  (t) => [primaryKey({ columns: [t.kind, t.key] }), index("ephemeral_expiry").on(t.expiresAt)],
);

/**
 * A character and its book, as the addon saved them at its last logout
 * (addon/Hearthtale/Save.lua): the book is shown as is, never rewritten.
 */
export const characters = pgTable("characters", {
  id: serial("id").primaryKey(),
  /** The game's GUID ("Player-<server>-<id>"): one journal per character. */
  guid: text("guid").notNull().unique(),
  name: text("name").notNull(),
  realm: text("realm"),
  /** Battle.net region (1 US, 2 KR, 3 EU, 4 TW, 5 CN). */
  region: integer("region"),
  /** The game's tokens: "Dwarf", "HUNTER". */
  race: text("race").notNull(),
  class: text("class").notNull(),
  client: text("client").$type<Client>().notNull(),
  level: integer("level").notNull(),
  hardcore: boolean("hardcore").notNull().default(false),
  /** A Hardcore death closed the book. */
  fallen: boolean("fallen").notNull().default(false),
  /** The Battle.net character id (from the GUID: "Player-6113-03D658B8" is 64379064). */
  bnetCharId: bigint("bnet_char_id", { mode: "number" }),
  /** Whose book it is: proved by a Battle.net login, a link code or the account's companion. Private to them. */
  ownerId: integer("owner_id").references(() => accounts.id, { onDelete: "set null" }),
  /** A fallen book its owner shows in the public Hall of the Fallen. */
  inHall: boolean("in_hall").notNull().default(false),
  book: jsonb("book").$type<Book>().notNull(),
  updatedAt: timestamp("updated_at", { withTimezone: true })
    .notNull()
    .default(sql`now()`),
});

/**
 * A share link: anyone with its token reads what it covers, the whole book or
 * one part (part: "prologue", a chapter's number, "epitaph"), nothing else.
 * Deleted to revoke.
 */
export const shares = pgTable(
  "shares",
  {
    token: text("token").primaryKey(),
    characterId: integer("character_id")
      .notNull()
      .references(() => characters.id, { onDelete: "cascade" }),
    part: text("part"),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [index("shares_character").on(t.characterId)],
);

/**
 * A book its owner removed from the site: its character's uploads are refused
 * (the companion is told "removed", nothing is stored) until the owner links
 * it again with a new code typed in the game (`/ht link CODE`).
 */
export const removed = pgTable(
  "removed",
  {
    accountId: integer("account_id")
      .notNull()
      .references(() => accounts.id, { onDelete: "cascade" }),
    guid: text("guid").notNull(),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [primaryKey({ columns: [t.accountId, t.guid] })],
);

/**
 * A device that asked to be told of new entries (a browser's push
 * subscription): its endpoint and keys, for its account's books. Deleted when
 * the browser turns it off, or the push service says it is gone.
 */
export const pushSubscriptions = pgTable(
  "push_subscriptions",
  {
    endpoint: text("endpoint").primaryKey(),
    accountId: integer("account_id")
      .notNull()
      .references(() => accounts.id, { onDelete: "cascade" }),
    p256dh: text("p256dh").notNull(),
    auth: text("auth").notNull(),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [index("push_subscriptions_account").on(t.accountId)],
);

/**
 * What players' games told them of the world, shared by those who said yes in
 * an addon (the kit's collector) and sent by Ravenpost: one fact a row (a
 * quest's text, a creature's level, an NPC's line, an item a source gave), in
 * the language it came in, kept once; who saw it, as the hashes of anonymous
 * Ravenpost installs (at most a few: enough to count how many agree). The
 * addons' database (wow-data) takes them in through the export.
 */
export const observations = pgTable(
  "observations",
  {
    id: serial("id").primaryKey(),
    game: text("game").notNull(), // classic | forever
    locale: text("locale").notNull(),
    kind: text("kind").notNull(), // quest | npc | say | gossip | loot
    entity: text("entity").notNull(), // its id ("448", or a loot source "npc:448")
    field: text("field").notNull(),
    value: text("value").notNull(),
    valueHash: text("value_hash").notNull(),
    build: text("build"),
    contributors: jsonb("contributors").$type<string[]>().notNull().default(sql`'[]'::jsonb`),
    firstSeen: timestamp("first_seen", { withTimezone: true }).notNull().defaultNow(),
    lastSeen: timestamp("last_seen", { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [
    uniqueIndex("observations_fact").on(t.game, t.locale, t.kind, t.entity, t.field, t.valueHash),
    index("observations_seen").on(t.lastSeen),
  ],
);

/** Tiny key/value store for the site's own state. */
export const state = pgTable("state", {
  key: text("key").primaryKey(),
  value: text("value").notNull(),
  updatedAt: timestamp("updated_at", { withTimezone: true })
    .notNull()
    .default(sql`now()`),
});

export type CharacterRow = typeof characters.$inferSelect;
export type AccountRow = typeof accounts.$inferSelect;
export type CompanionLinkRow = typeof companionLinks.$inferSelect;
export type ShareRow = typeof shares.$inferSelect;
