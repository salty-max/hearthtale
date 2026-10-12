import type { Book, PublicCharacter } from "@hearthtale/shared";
import { paragraphs, partSub, partTitle, parts, type Part } from "@/lib/book";
import type { Strings } from "@/lib/i18n";
import { raceClass, realmName } from "@/lib/wow";
import { zip } from "@/lib/zip";

/**
 * A book to keep, as it reads on the site: every part in order, its title,
 * the line under it, its paragraphs, the player's note. As text (Markdown) or
 * an EPUB for e-readers; printing is the reader's own (PrintBook).
 */
type Who = PublicCharacter;

function textOf(book: Book, p: Part): string | undefined {
  if (p.kind === "prologue") return book.prologue;
  if (p.kind === "epitaph") return book.epitaph;
  const ch = book.chapters.find((c) => c.number === p.number);
  return ch?.diary ?? ch?.text;
}
function noteOf(book: Book, p: Part): string[] {
  if (p.kind !== "chapter") return [];
  const note = book.chapters.find((c) => c.number === p.number)?.note ?? "";
  return note.split(/\n+/).map((l) => l.trim()).filter(Boolean);
}

/** "Brannok-journal": a file's name, safe anywhere. */
export function fileName(who: Who): string {
  return `${who.name.normalize("NFD").replace(/[^\w-]+/g, "")}-journal`;
}

function about(t: Strings, who: Who): string {
  return [`${t.library.level(who.level)} ${raceClass(t, who)}`, realmName(t, who)].filter(Boolean).join(" · ");
}

export function markdown(t: Strings, locale: string, who: Who, book: Book): string {
  const out = [`# ${t.exports.by(who.name)}`, "", `*${about(t, who)}*`, ""];
  for (const p of parts(book)) {
    out.push(`## ${partTitle(t, book, p)}`, "");
    const sub = partSub(t, locale, who, book, p);
    if (sub) out.push(`*${sub}*`, "");
    for (const para of paragraphs(textOf(book, p))) out.push(para, "");
    const note = noteOf(book, p);
    if (note.length) out.push(`> **${t.book.note}**`, ...note.map((l) => `> ${l}`), "");
  }
  return out.join("\n");
}

const xml = (s: string) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

const CSS = `body { font-family: Georgia, serif; line-height: 1.55; margin: 0 5%; }
h1, h2 { font-weight: normal; text-align: center; color: #6b3f0f; }
.sub { text-align: center; font-style: italic; color: #6e5638; margin-bottom: 1.5em; }
.epitaph p { text-align: center; font-style: italic; }
.note { border-top: 1px solid #ccb; margin-top: 2em; padding-top: 0.5em; font-style: italic; }
.note-title { font-variant: small-caps; font-style: normal; color: #6e5638; }
`;

function page(title: string, body: string, lang: string): string {
  return `<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" lang="${lang}" xml:lang="${lang}">
<head><meta charset="utf-8"/><title>${xml(title)}</title><link rel="stylesheet" type="text/css" href="style.css"/></head>
<body>
${body}
</body>
</html>`;
}

/** The book as an EPUB 3: a title page, then each part a page of its own, and their contents. */
export function epub(t: Strings, locale: string, who: Who, book: Book, id: string): Uint8Array {
  const lang = locale.slice(0, 2);
  const title = t.exports.by(who.name);
  const all = parts(book);
  const files = all.map((p, i) => ({ p, file: `part-${i + 1}.xhtml`, title: partTitle(t, book, p) }));
  const pages = files.map(({ p, file, title: name }) => {
    const sub = partSub(t, locale, who, book, p);
    const note = noteOf(book, p);
    const body = [
      `<section class="${p.kind}" epub:type="chapter">`,
      `<h2>${xml(name)}</h2>`,
      sub ? `<p class="sub">${xml(sub)}</p>` : "",
      ...paragraphs(textOf(book, p)).map((para) => `<p>${xml(para)}</p>`),
      note.length ? `<div class="note"><p class="note-title">${xml(t.book.note)}</p>${note.map((l) => `<p>${xml(l)}</p>`).join("")}</div>` : "",
      "</section>",
    ].join("\n");
    return { name: `OEBPS/${file}`, data: page(name, body, lang) };
  });
  const cover = page(title, `<h1>${xml(title)}</h1>\n<p class="sub">${xml(about(t, who))}</p>`, lang);
  const nav = page(
    t.book.contents,
    `<nav epub:type="toc"><h2>${xml(t.book.contents)}</h2><ol>${files.map((f) => `<li><a href="${f.file}">${xml(f.title)}</a></li>`).join("")}</ol></nav>`,
    lang,
  );
  const modified = new Date(book.at * 1000).toISOString().replace(/\.\d+Z$/, "Z");
  const opf = `<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id" xml:lang="${lang}">
<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
<dc:identifier id="id">urn:hearthtale:${xml(id)}</dc:identifier>
<dc:title>${xml(title)}</dc:title>
<dc:creator>${xml(who.name)}</dc:creator>
<dc:language>${lang}</dc:language>
<dc:publisher>Hearthtale</dc:publisher>
<meta property="dcterms:modified">${modified}</meta>
</metadata>
<manifest>
<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
<item id="cover" href="cover.xhtml" media-type="application/xhtml+xml"/>
<item id="css" href="style.css" media-type="text/css"/>
${files.map((f, i) => `<item id="p${i + 1}" href="${f.file}" media-type="application/xhtml+xml"/>`).join("\n")}
</manifest>
<spine>
<itemref idref="cover"/>
${files.map((_, i) => `<itemref idref="p${i + 1}"/>`).join("\n")}
</spine>
</package>`;
  const container = `<?xml version="1.0" encoding="utf-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
<rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
</container>`;
  return zip([
    // (first and stored: how a reader knows it for an EPUB)
    { name: "mimetype", data: "application/epub+zip" },
    { name: "META-INF/container.xml", data: container },
    { name: "OEBPS/content.opf", data: opf },
    { name: "OEBPS/nav.xhtml", data: nav },
    { name: "OEBPS/cover.xhtml", data: cover },
    { name: "OEBPS/style.css", data: CSS },
    ...pages,
  ]);
}

/** Hands a file to the visitor's browser to save. */
export function save(name: string, data: Uint8Array | string, type: string): void {
  const blob = new Blob([data as BlobPart], { type });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = name;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
