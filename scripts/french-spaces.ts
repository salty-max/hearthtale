/**
 * French typography, as the client writes it: a no-break space (U+00A0) before
 * ":" "?" "!" and before a percent sign ("50 %", never a format blank like
 * "%d"). The French words (i18n/frFR/words.json, its values) and the French
 * Notes of the TOCs carry it; a plain space there is turned into one. Run again
 * it changes nothing.
 *
 *   bun scripts/french-spaces.ts           write the files
 *   bun scripts/french-spaces.ts --check   fail when a file would change (addon:ci)
 */
import { readFileSync, writeFileSync, readdirSync } from "node:fs";

const NBSP = " ";
const root = new URL("..", import.meta.url).pathname;

// The kit's rule (addon-kit/terms.ts, Q1) made a fix: a no-break space where a
// plain space or none stands before ":" "?" "!" (followed by a space or the
// end), and before a percent sign ("%%" in a format, or a figure then "%", never
// a blank like "%d"). A game's own title keeps its colon.
const TITLE = "World of Warcraft: Forever";
export function spaced(s: string): string {
  return s
    .split(TITLE)
    .map((part) =>
      part
        .replace(/[ \t]+([:?!])(?=\s|$)/g, `${NBSP}$1`)
        .replace(/(?<=[\p{L}\d)%.])([:?!])(?=\s|$)/gu, `${NBSP}$1`)
        .replace(/(?<!\u00a0)%%/g, `${NBSP}%%`)
        .replace(/(\d)[ \t]*%(?![sdif%$\d])/g, `$1${NBSP}%`),
    )
    .join(TITLE);
}

if (import.meta.main) {
  const words = `${root}i18n/frFR/words.json`;
  const tocDir = `${root}addon/Hearthtale/`;
  const tocs = readdirSync(tocDir).filter((f) => f.endsWith(".toc"));

  const changes: string[] = [];
  const write = (file: string, before: string, after: string) => {
    if (before === after) return;
    changes.push(file.replace(root, ""));
    if (!process.argv.includes("--check")) writeFileSync(file, after);
  };

  const before = readFileSync(words, "utf8");
  const json = JSON.parse(before) as Record<string, string>;
  for (const k of Object.keys(json)) json[k] = spaced(json[k]);
  write(words, before, JSON.stringify(json, null, 2) + "\n");

  for (const f of tocs) {
    const text = readFileSync(tocDir + f, "utf8");
    const out = text.replace(
      /^(## Notes-frFR: )(.*)$/m,
      (_, head, line) => head + spaced(line),
    );
    write(tocDir + f, text, out);
  }

  if (changes.length && process.argv.includes("--check")) {
    console.error(
      `French typography: a plain space before : ? ! % in ${changes.join(", ")} (bun scripts/french-spaces.ts)`,
    );
    process.exit(1);
  }
  console.log(
    changes.length
      ? `French typography: ${changes.join(", ")} written`
      : "French typography: nothing to change",
  );
}
