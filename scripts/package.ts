/**
 * The addon's package: addon/Hearthtale as it is, one zip for every game, each
 * game loading its own TOC (Hearthtale_Vanilla.toc: Classic Era;
 * Hearthtale_Camelot.toc: World of Warcraft: Forever, with Forever.lua). The
 * BigWigs packager makes the release's (.pkgmeta, .github/workflows/release.yml);
 * this one is for a test in the game before a release, and checks the TOCs:
 * the same header and files but for the interface and each game's own files,
 * every one of them there, every Lua file of the folder loaded.
 *
 *   bun scripts/package.ts           dist/Hearthtale and dist/Hearthtale.zip
 *   bun scripts/package.ts --no-zip  the folder only (to copy into a game)
 *   bun scripts/package.ts --check   the TOCs only
 */
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync } from "node:fs";
import { dirname, join } from "node:path";
import { spawnSync } from "node:child_process";

const ROOT = join(import.meta.dir, "..");
const NAME = "Hearthtale";
const SRC = join(ROOT, "addon", NAME);
const DIST = join(ROOT, "dist");
// Each game's TOC, its interface and the files only it loads.
const GAMES = [
  { toc: `${NAME}_Vanilla.toc`, interface: "11509", own: ["Data_Classic.lua"] },
  { toc: `${NAME}_Camelot.toc`, interface: "16001", own: ["Data_Forever.lua", "Forever.lua"] },
];

const fail = (why: string) => {
  console.error(`✗ ${why}`);
  process.exit(1);
};

// The TOCs agree.
const shared = (game: (typeof GAMES)[number]) =>
  readFileSync(join(SRC, game.toc), "utf8")
    .split("\n")
    .filter((l) => !l.startsWith("#") || l.startsWith("## "))
    .filter((l) => !l.startsWith("## Interface:") && !game.own.includes(l.trim()));
const loaded = new Set<string>();
for (const game of GAMES) {
  const toc = readFileSync(join(SRC, game.toc), "utf8");
  if (!toc.startsWith(`## Interface: ${game.interface}\n`)) fail(`${game.toc}: not "## Interface: ${game.interface}" first`);
  const files = toc.split("\n").filter((l) => l.trim() && !l.startsWith("#"));
  for (const f of files) {
    if (!existsSync(join(SRC, f))) fail(`${game.toc} loads ${f}, which isn't there`);
    loaded.add(f);
  }
  for (const f of game.own) if (!files.includes(f)) fail(`${game.toc} doesn't load ${f}, its own`);
  if (shared(game).join("\n") !== shared(GAMES[0]).join("\n")) fail(`${game.toc} and ${GAMES[0].toc} differ in more than the interface and their own files`);
}
// The folder's files: those in git (what a release ships: the packager leaves
// the others out), and those not added yet, said so (a test before a commit).
const ls = (...opts: string[]) =>
  spawnSync("git", ["ls-files", "-z", ...opts, "--", `addon/${NAME}`], { cwd: ROOT, encoding: "utf8" })
    .stdout.split("\0")
    .filter(Boolean)
    .map((f) => f.slice(`addon/${NAME}/`.length));
const added = ls("--others", "--exclude-standard");
const files = [...ls(), ...added].filter((f) => existsSync(join(SRC, f)));
for (const f of added) console.warn(`! ${f}: not in git yet (a release would leave it out)`);
for (const f of files) if (f.endsWith(".lua") && !f.includes("/") && !loaded.has(f)) fail(`${f}: no TOC loads it`);
if (process.argv.includes("--check")) {
  console.log(`✓ ${GAMES.map((g) => g.toc).join(", ")}`);
  process.exit(0);
}

const dir = join(DIST, NAME);
rmSync(dir, { recursive: true, force: true });
for (const f of files) {
  mkdirSync(dirname(join(dir, f)), { recursive: true });
  cpSync(join(SRC, f), join(dir, f));
}
let out = `dist/${NAME}`;
if (!process.argv.includes("--no-zip")) {
  const zip = join(DIST, `${NAME}.zip`);
  if (existsSync(zip)) rmSync(zip);
  const r = spawnSync("zip", ["-qr", zip, NAME], { cwd: DIST, stdio: "inherit" });
  if (r.status !== 0) fail("zip failed");
  out += `, dist/${NAME}.zip`;
}
console.log(`✓ ${out} (${GAMES.map((g) => `${g.toc} ${g.interface}`).join(", ")})`);
