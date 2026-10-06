import type { Book, Client } from "@hearthtale/shared";
import { sql } from "drizzle-orm";
import { boolean, integer, jsonb, pgTable, serial, text, timestamp } from "drizzle-orm/pg-core";

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
  book: jsonb("book").$type<Book>().notNull(),
  updatedAt: timestamp("updated_at", { withTimezone: true })
    .notNull()
    .default(sql`now()`),
});

/** Tiny key/value store for the site's own state. */
export const state = pgTable("state", {
  key: text("key").primaryKey(),
  value: text("value").notNull(),
  updatedAt: timestamp("updated_at", { withTimezone: true })
    .notNull()
    .default(sql`now()`),
});

export type CharacterRow = typeof characters.$inferSelect;
