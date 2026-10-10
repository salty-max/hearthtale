import data from "./samples.json";

/**
 * A page of each test journal, for the landing page: the longest finished
 * entry of four lives, each in its own voice, and the epitaph of one who fell.
 * Written by the addon's own writer from lives played through it in the tests
 * (`luajit addon/test/sample.lua landing`, part of `bun run addon:seed`):
 * never edited by hand.
 */
export type Sample = {
  name: string;
  race: string;
  class: string;
  hardcore: boolean;
  part: "entry" | "epitaph";
  number?: number;
  title?: string;
  place?: string;
  from?: number;
  to?: number;
  text: string;
};

export const SAMPLES = data as Sample[];
