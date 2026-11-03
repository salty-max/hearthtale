/**
 * The wire contract between the addon's saved file, the API and the web app.
 * Source of truth for the shapes; the addon side is addon/Hearthtale/Save.lua.
 */

/** Battle.net regions. */
export type Region = "us" | "eu" | "kr" | "tw";
export const REGIONS: Region[] = ["us", "eu", "kr", "tw"];

/** The signed-in account. */
export type Me = { battletag: string | null; regions: Region[]; test?: boolean };

/** A code to type in the game: `/ht link CODE`. */
export type LinkCode = { code: string; expiresAt: string };

/** The game a book was written on (each loads its own part of the addon). */
export type Client = "classic" | "forever";

/** One chapter as the addon wrote it at logout (Save.lua). */
export type BookChapter = {
  number: number;
  /** A book saved before diary entries were: the chapter's prose, read in their place. */
  text?: string;
  /** The chapter as the character's diary entry (Diary.lua), paragraphs separated by a blank line. Missing: nothing to tell yet. */
  diary?: string;
  /** Its title: its weightiest moment in the game's own words (a quest's title, a name, a place), or one the player gave it. Missing: "Entry N". */
  title?: string;
  /** The player's own note in its margin, in their words (lines separated by newlines). */
  note?: string;
  /** Where it closed, or where it began while still being written. */
  place?: string;
  /** The levels it covers. */
  from: number;
  to: number;
  /** Still being written. */
  open?: boolean;
  /** Holds a rare slain / a close call (the book's marks). */
  rare?: boolean;
  close?: boolean;
  /** Unix seconds. */
  began?: number;
  ended?: number;
};

/** A journal's language, chosen in the game: the client's at the first login, then kept. */
export type Language = "enUS" | "frFR";

/** The book as the addon wrote it at the last logout: shown as is, never rewritten. */
export type Book = {
  /** The addon version that wrote it. */
  version?: string;
  client: Client;
  /** The journal's language (a book saved before it was kept: English). */
  language?: Language;
  /** The character's sex as the game counts it (2 a man, 3 a woman): French names agree with it. */
  sex?: 2 | 3;
  /** Unix seconds: when it was written. */
  at: number;
  level?: number;
  prologue?: string;
  chapters: BookChapter[];
  /** A Hardcore death closed it. */
  epitaph?: string;
};

export type Health = { ok: true; version: string };

/** A character on the site, for the library. */
export type CharacterSummary = {
  id: number;
  /** Shown in the public Hall of the Fallen (fallen books only). */
  inHall?: boolean;
  name: string;
  realm?: string;
  region?: number;
  /** The game's tokens: "Dwarf", "HUNTER". */
  race: string;
  class: string;
  client: Client;
  /** The book's language and the character's sex (its frame: lib/frame.ts). */
  language?: Language;
  sex?: 2 | 3;
  level: number;
  hardcore: boolean;
  fallen: boolean;
  chapters: number;
  /** The book's latest entry (the one being written, else the last): for the library's card. */
  latest?: LatestEntry;
  /** ISO time of the last upload. */
  updatedAt: string;
};
/** An entry as the library shows it: its number, its title, where, when (Unix seconds: its end, else its start). */
export type LatestEntry = { number: number; title?: string; place?: string; at?: number; open?: boolean };

/** A character and its book. */
export type CharacterBook = { character: CharacterSummary; book: Book };

// ── the companion (Ravenpost) ───────────────────────────────────────────────

/** POST /api/companion/pair/start: the companion opens `url` and polls with `pollToken`. */
export type PairStart = { code: string; pollToken: string; url: string; expiresIn: number };
/** POST /api/companion/pair/poll. */
export type PairPoll = { status: "pending" } | { status: "expired" } | { status: "paired"; token: string; battletag: string | null };

/** POST /api/companion/upload: each character's saved record (HearthtaleChar), as the companion parsed it. */
export type UploadRequest = { characters: unknown[] };
/** What became of each character: kept, or waiting to be linked (`/ht link CODE`), or unreadable. */
/** removed: its owner removed the book from the site; uploads wait for a new link code. */
/** owned: another account holds the character, a link code can't move it. */
export type UploadStatus = "saved" | "unlinked" | "invalid" | "removed" | "owned";
export type UploadResult = { characters: { guid: string; name: string; status: UploadStatus; chapters?: number; characterId?: number }[] };

// ── sharing ─────────────────────────────────────────────────────────────────

/** Who a shared book belongs to: what the page shows, nothing private. */
export type PublicCharacter = Pick<CharacterSummary, "name" | "realm" | "region" | "race" | "class" | "level" | "hardcore" | "fallen" | "language" | "sex">;

/** A share link of one of my books: the whole book (no part) or one part ("prologue", "3", "epitaph"). */
export type Share = { token: string; part?: string; url: string; createdAt: string };

/** What a share link (or the Hall) shows: the book, cut to what it covers. */
export type SharedBook = { character: PublicCharacter; book: Book; part?: string };

/** A life in the public Hall of the Fallen. */
export type HallEntry = { id: number; character: PublicCharacter; epitaph?: string; chapters: number; diedAt?: number };

export { frameFor, type Frame, type Sex } from "./frame";
