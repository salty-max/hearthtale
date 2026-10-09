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

/** The game a book was written on (the addon's two packages). */
export type Client = "classic" | "forever";

/** One chapter as the addon wrote it at logout (Save.lua). */
export type BookChapter = {
  number: number;
  /** The prose, paragraphs separated by a blank line. Missing: nothing to tell yet. */
  text?: string;
  /** The same stretch as the character's diary entry (Diary.lua): shown first, the prose a click away. */
  diary?: string;
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

/** The book as the addon wrote it at the last logout: shown as is, never rewritten. */
export type Book = {
  /** The addon version that wrote it. */
  version?: string;
  client: Client;
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
  level: number;
  hardcore: boolean;
  fallen: boolean;
  chapters: number;
  /** ISO time of the last upload. */
  updatedAt: string;
};

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
export type UploadStatus = "saved" | "unlinked" | "invalid" | "removed";
export type UploadResult = { characters: { guid: string; name: string; status: UploadStatus; chapters?: number; characterId?: number }[] };

// ── sharing ─────────────────────────────────────────────────────────────────

/** Who a shared book belongs to: what the page shows, nothing private. */
export type PublicCharacter = Pick<CharacterSummary, "name" | "realm" | "region" | "race" | "class" | "level" | "hardcore" | "fallen">;

/** A share link of one of my books: the whole book (no part) or one part ("prologue", "3", "epitaph"). */
export type Share = { token: string; part?: string; url: string; createdAt: string };

/** What a share link (or the Hall) shows: the book, cut to what it covers. */
export type SharedBook = { character: PublicCharacter; book: Book; part?: string };

/** A life in the public Hall of the Fallen. */
export type HallEntry = { id: number; character: PublicCharacter; epitaph?: string; chapters: number; diedAt?: number };
