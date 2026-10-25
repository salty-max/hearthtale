/**
 * The addon's package: the family's (scripts/package-lib.ts, the kit's copy):
 * addon/Hearthtale as it is, one zip for every game, each game loading its own
 * TOC; its TOCs checked.
 *
 *   bun scripts/package.ts           dist/Hearthtale and dist/Hearthtale-<version>.zip
 *   bun scripts/package.ts --no-zip  the folder only (to copy into a game)
 *   bun scripts/package.ts --check   the TOCs only
 */
import { join } from "node:path";
import { run } from "./package-lib";

// (each game's own files: the game's data and names: each game's own, Forever's own writing too)
run({ root: join(import.meta.dir, ".."), name: "Hearthtale", games: { classic: ["Data_Classic.lua", "Client_Classic.lua", "English_Classic.lua"], forever: ["Data_Forever.lua", "Client_Forever.lua", "English_Forever.lua", "Forever.lua"] } });
