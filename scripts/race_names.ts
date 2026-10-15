/**
 * i18n/<locale>/races.json: every race's name in a language, English one of
 * them, masculine and feminine, by its token ("Dwarf": ["Nain", "Nain"],
 * ["Anão", "Anã"]), from the clients' own tables (wow-data's databases,
 * ../wow-data: ChrRaces, Forever's then Classic Era's): the Hall names a
 * fallen life's race in the client's language by its token and sex, which
 * the game gives by id only in the masculine. A language whose client has no
 * feminine form names a woman as a man ("Nain", "Zwerg").
 *
 *   bun scripts/race_names.ts frFR
 */
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { openDb } from "../../wow-data/src/db";

const locale = process.argv[2];
if (!locale || !/^[a-z]{2}[A-Z]{2}$/.test(locale)) {
  console.error("usage: bun scripts/race_names.ts <locale> (enUS, frFR, deDE...)");
  process.exit(2);
}
const out: Record<string, [string, string]> = {};
for (const game of ["forever", "classic"] as const) {
  const db = openDb(game);
  const rows = db
    .query(
      `SELECT r.ClientFileString AS token, n.name, n.female FROM client_ChrRaces r
       JOIN name n ON n.kind = 'race' AND n.id = r.ID AND n.locale = ?
       WHERE r.ClientFileString <> '' ORDER BY r.ID`,
    )
    .all(locale) as { token: string; name: string; female: string | null }[];
  for (const r of rows) out[r.token] ??= [r.name.trim(), (r.female ?? r.name).trim()];
  db.close();
}
const dir = join(import.meta.dir, "..", "i18n", locale);
mkdirSync(dir, { recursive: true });
writeFileSync(join(dir, "races.json"), `${JSON.stringify(Object.fromEntries(Object.entries(out).sort(([a], [b]) => a.localeCompare(b))), null, 1)}\n`);
console.log(`✓ i18n/${locale}/races.json: ${Object.keys(out).length} races`);
