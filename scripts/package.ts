/**
 * Builds one package per game from addon/Hearthtale:
 *   dist/classic/Hearthtale  + dist/Hearthtale-classic.zip   Classic Era (Hardcore, Season of Discovery)
 *   dist/forever/Hearthtale  + dist/Hearthtale-forever.zip   World of Warcraft: Forever
 * Each gets the shared code, its game's data file as Data.lua, and a TOC
 * claiming its game's interface versions. The source folder is not itself an
 * installable addon (its TOC has an @INTERFACE@ placeholder).
 *
 *   bun scripts/package.ts           both folders and zips
 *   bun scripts/package.ts --no-zip  folders only (to copy into a game)
 */
import { cpSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const ROOT = join(import.meta.dir, "..");
const SRC = join(ROOT, "addon/Hearthtale");
const DIST = join(ROOT, "dist");
const GAMES = [
  { name: "classic", content: "Data_Classic.lua", interface: "11509" },
  { name: "forever", content: "Data_Forever.lua", interface: "16001" },
];
// Files of one game only (Forever's own content): left out of the others,
// and out of their TOC.
const ONLY: Record<string, string> = { "Forever.lua": "forever" };

const toc = readFileSync(join(SRC, "Hearthtale.toc"), "utf8");
if (!toc.includes("@INTERFACE@")) throw new Error("Hearthtale.toc: no @INTERFACE@ placeholder");

for (const game of GAMES) {
  const dir = join(DIST, game.name, "Hearthtale");
  rmSync(join(DIST, game.name), { recursive: true, force: true });
  mkdirSync(dir, { recursive: true });
  for (const f of readdirSync(SRC)) {
    if (!f.endsWith(".lua") || f.startsWith("Data_") || (ONLY[f] && ONLY[f] !== game.name)) continue;
    cpSync(join(SRC, f), join(dir, f));
  }
  cpSync(join(SRC, game.content), join(dir, "Data.lua"));
  const lines = toc.replace("@INTERFACE@", game.interface).split("\n");
  writeFileSync(join(dir, "Hearthtale.toc"), lines.filter((l) => !(ONLY[l.trim()] && ONLY[l.trim()] !== game.name)).join("\n"));
  if (!process.argv.includes("--no-zip")) {
    const zip = join(DIST, `Hearthtale-${game.name}.zip`);
    if (existsSync(zip)) rmSync(zip);
    const r = spawnSync("zip", ["-qr", zip, "Hearthtale", "-x", "*.DS_Store"], { cwd: join(DIST, game.name), stdio: "inherit" });
    if (r.status !== 0) throw new Error(`zip failed for ${game.name}`);
  }
  console.log(`✓ ${game.name}: dist/${game.name}/Hearthtale${process.argv.includes("--no-zip") ? "" : `, dist/Hearthtale-${game.name}.zip`} (interface ${game.interface})`);
}
