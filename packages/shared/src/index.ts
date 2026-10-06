/**
 * The wire contract between the addon's saved file, the API and the web app.
 * Source of truth for the shapes; the addon side is addon/Hearthtale/Save.lua.
 */

/** The game a book was written on (the addon's two packages). */
export type Client = "classic" | "forever";

/** One chapter as the addon wrote it at logout (Save.lua). */
export type BookChapter = {
  number: number;
  /** The prose, paragraphs separated by a blank line. Missing: nothing to tell yet. */
  text?: string;
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
