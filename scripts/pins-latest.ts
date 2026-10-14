// Have the game's builds moved past the pins (scripts/pins.json)? For
// .github/workflows/client-tables.yml, and by hand:
//   bun scripts/pins-latest.ts                 says what is newer
//   bun scripts/pins-latest.ts --write         and moves the builds' pins
//   … --summary FILE                           writes what it found, in Markdown
// A pinned build moves to the newest of its product with the same major
// version (wago.tools files Forever's beta, 1.60, under the same product as
// Mists of Pandaria's, 5.5). Forever's builds under another product (wowf,
// its own at launch) are told, never followed: changing a product is a
// person's call. The community databases' newer commits are told too, never
// followed (their data changes what the writer says: a person reads it).
import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

const ROOT = path.join(import.meta.dir, "..");
const PINS = path.join(ROOT, "scripts/pins.json");
const UA = { "User-Agent": "Hearthtale/1.0 (addon; github.com/salty-max/hearthtale)" };
const args = process.argv.slice(2);
const WRITE = args.includes("--write");
const summaryAt = args.indexOf("--summary");
const SUMMARY = summaryAt >= 0 ? args[summaryAt + 1] : undefined;

type Pin = { product: string; build: string };
type Pins = { builds: Record<string, Pin>; repos: Record<string, { repo: string; commit: string }> };
const pins: Pins = JSON.parse(readFileSync(PINS, "utf8"));

// "1.60.1.70374" > "1.60.1.70291"
function newer(a: string, b: string) {
  const x = a.split(".").map(Number),
    y = b.split(".").map(Number);
  for (let i = 0; i < Math.max(x.length, y.length); i++) {
    if ((x[i] ?? 0) !== (y[i] ?? 0)) return (x[i] ?? 0) > (y[i] ?? 0);
  }
  return false;
}
const major = (v: string) => v.split(".")[0];
const family = (v: string) => v.split(".").slice(0, 2).join(".");

const res = await fetch("https://wago.tools/api/builds", { headers: UA });
if (!res.ok) throw new Error(`wago.tools builds: ${res.status}`);
const builds: Record<string, { version: string }[]> = await res.json();

const lines: string[] = [];
let moved = false;
for (const [game, pin] of Object.entries(pins.builds)) {
  const versions = (builds[pin.product] ?? []).map((b) => b.version).filter((v) => major(v) === major(pin.build));
  const latest = versions.reduce((best, v) => (newer(v, best) ? v : best), pin.build);
  if (latest !== pin.build) {
    lines.push(`- ${game}: ${pin.product} ${pin.build} → **${latest}**`);
    if (WRITE) pin.build = latest;
    moved = true;
  } else {
    lines.push(`- ${game}: ${pin.product} ${pin.build}, the latest`);
  }
  // (the same game's builds under another product)
  for (const [product, list] of Object.entries(builds)) {
    if (product === pin.product) continue;
    const there = list.map((b) => b.version).filter((v) => family(v) === family(pin.build) && newer(v, pin.build));
    if (there.length) {
      const best = there.reduce((a, v) => (newer(v, a) ? v : a));
      lines.push(`  - also under ${product}: ${best} (not followed: a product changes by hand, in scripts/pins.json)`);
    }
  }
}

// the community databases: newer commits on their default branch
const token = process.env.GITHUB_TOKEN;
const repoLines: string[] = [];
for (const [name, r] of Object.entries(pins.repos)) {
  const head = await fetch(`https://api.github.com/repos/${r.repo}/commits?per_page=1`, {
    headers: { ...UA, Accept: "application/vnd.github+json", ...(token ? { Authorization: `Bearer ${token}` } : {}) },
  });
  if (!head.ok) {
    repoLines.push(`- ${name} (${r.repo}): could not ask (${head.status})`);
    continue;
  }
  const [latest] = (await head.json()) as { sha: string; commit: { committer: { date: string } } }[];
  repoLines.push(
    latest && latest.sha !== r.commit
      ? `- ${name} (${r.repo}): newer commits, ${latest.sha.slice(0, 12)} of ${latest.commit.committer.date.slice(0, 10)} (pinned ${r.commit.slice(0, 12)}; not followed: bump it by hand and read the audit)`
      : `- ${name} (${r.repo}): the pinned commit is the latest`,
  );
}

if (WRITE && moved) writeFileSync(PINS, JSON.stringify(pins, null, 2) + "\n");
const text = [
  "### The game's builds",
  "",
  ...lines,
  "",
  "### The community databases",
  "",
  "Forever's own new creatures and quests come from these, not from the client's tables.",
  "",
  ...repoLines,
  "",
].join("\n");
console.log(text);
if (SUMMARY) writeFileSync(SUMMARY, text);
// (for the workflow: whether a pin moved)
if (process.env.GITHUB_OUTPUT) writeFileSync(process.env.GITHUB_OUTPUT, `moved=${moved}\n`, { flag: "a" });
