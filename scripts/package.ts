/**
 * The addon's package: the family's (scripts/package-lib.ts, the kit's copy):
 * addon/Hearthtale as it is, one zip for every game, each game loading its own
 * TOC; its TOCs checked.
 *
 *   bun scripts/package.ts           dist/Hearthtale and dist/Hearthtale-<version>.zip
 *   bun scripts/package.ts --no-zip  the folder only (to copy into a game)
 *   bun scripts/package.ts --check   the TOCs only
 */
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { type Also, run, versionOf } from "./package-lib";

// Hearthtale_French, shipped beside it: the French a journal is written in,
// loaded on demand (French.lua) the first time a journal is in French. Its
// TOCs: each game's, its version Hearthtale's, on demand, after Hearthtale;
// its data complete (scripts/build.ts, FRENCH_COMPLETE).
const FRENCH = "Hearthtale_French";
const FRENCH_TOCS = [
  { toc: `${FRENCH}_Vanilla.toc`, interface: "11509", game: "Classic" },
  { toc: `${FRENCH}_Camelot.toc`, interface: "16001", game: "Forever" },
];
const FRENCH_FILES = [
  ...FRENCH_TOCS.map((t) => t.toc),
  ...FRENCH_TOCS.flatMap((t) => [`FrenchNames_${t.game}.lua`, `French_${t.game}.lua`]),
  "Share.lua",
];
const also: Also = {
  folder: FRENCH,
  files: FRENCH_FILES,
  check: ({ src, version, fail }) => {
    const files = existsSync(src) ? readdirSync(src).sort() : [];
    if (files.join() !== [...FRENCH_FILES].sort().join()) fail(`addon/${FRENCH}: ${files.join(", ")}, not ${FRENCH_FILES.join(", ")}`);
    for (const t of FRENCH_TOCS) {
      const toc = readFileSync(join(src, t.toc), "utf8");
      if (!toc.startsWith(`## Interface: ${t.interface}\n`)) fail(`${FRENCH}/${t.toc}: not "## Interface: ${t.interface}" first`);
      if (versionOf(toc) !== version) fail(`${FRENCH}/${t.toc}: version ${versionOf(toc)}, Hearthtale's is ${version}`);
      for (const need of ["## LoadOnDemand: 1", "## Dependencies: Hearthtale"])
        if (!toc.includes(`${need}\n`)) fail(`${FRENCH}/${t.toc}: no "${need}"`);
      const loads = toc.split("\n").filter((l) => l.trim() && !l.startsWith("#"));
      const want = [`FrenchNames_${t.game}.lua`, `French_${t.game}.lua`, "Share.lua"];
      if (loads.join() !== want.join()) fail(`${FRENCH}/${t.toc} loads ${loads.join(", ")}, not ${want.join(", ")}`);
      if (!readFileSync(join(src, `French_${t.game}.lua`), "utf8").includes("ns.frenchComplete = true\n"))
        fail(`${FRENCH}/French_${t.game}.lua: not complete (scripts/build.ts, FRENCH_COMPLETE)`);
    }
  },
};

// (each game's own files: the game's data and names: each game's own, Forever's own writing too)
run({ root: join(import.meta.dir, ".."), name: "Hearthtale", games: { classic: ["Data_Classic.lua", "Client_Classic.lua", "English_Classic.lua"], forever: ["Data_Forever.lua", "Client_Forever.lua", "English_Forever.lua", "Forever.lua"] }, also });
