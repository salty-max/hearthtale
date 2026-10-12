/**
 * Reads a SavedVariables file as the game writes it (a port of Ravenpost's
 * luasv.go):
 *
 *   HearthtaleChar = {
 *   ["name"] = "Brannok",
 *   ...
 *   }
 *
 * A small subset of Lua (assignments of tables, strings, numbers, booleans and
 * nil, plus comments), so a dedicated parser, not a Lua interpreter: nothing
 * in the file is ever run. Tables become arrays when their keys are exactly
 * 1..n (Lua arrays), objects otherwise, as the API reads them.
 */
export type LuaValue = string | number | boolean | null | LuaValue[] | { [key: string]: LuaValue };

const MAX_DEPTH = 64;

export class LuaError extends Error {}

export function parseSavedVariables(src: string): Record<string, LuaValue> {
  const p = new Parser(src);
  const out: Record<string, LuaValue> = {};
  for (;;) {
    p.skip();
    if (p.eof()) return out;
    const name = p.ident();
    if (!name) throw p.error("expected a variable name");
    p.skip();
    if (!p.consume("=")) throw p.error(`expected '=' after ${name}`);
    out[name] = p.value(0);
    p.skip();
    p.consume(";");
  }
}

const isIdentStart = (c: string) => c === "_" || (c >= "a" && c <= "z") || (c >= "A" && c <= "Z");
const isIdent = (c: string) => isIdentStart(c) || (c >= "0" && c <= "9");

class Parser {
  pos = 0;
  constructor(readonly src: string) {}

  eof(): boolean {
    return this.pos >= this.src.length;
  }
  error(what: string): LuaError {
    const line = 1 + (this.src.slice(0, this.pos).match(/\n/g)?.length ?? 0);
    return new LuaError(`SavedVariables line ${line}: ${what}`);
  }
  at(i = 0): string {
    return this.src[this.pos + i] ?? "";
  }
  consume(c: string): boolean {
    if (this.at() === c) {
      this.pos++;
      return true;
    }
    return false;
  }

  /** Whitespace and comments (-- line, --[[ block ]], --[==[ block ]==]). */
  skip(): void {
    while (!this.eof()) {
      const c = this.at();
      if (c === " " || c === "\t" || c === "\n" || c === "\r") {
        this.pos++;
      } else if (this.src.startsWith("--", this.pos)) {
        this.pos += 2;
        const level = this.longBracket();
        if (level !== null) {
          const end = "]" + "=".repeat(level) + "]";
          const i = this.src.indexOf(end, this.pos);
          this.pos = i >= 0 ? i + end.length : this.src.length;
          continue;
        }
        const i = this.src.indexOf("\n", this.pos);
        this.pos = i >= 0 ? i + 1 : this.src.length;
      } else {
        return;
      }
    }
  }

  /** "[[" or "[==[": its level, consumed; else null. */
  longBracket(): number | null {
    if (this.at() !== "[") return null;
    let i = this.pos + 1;
    while (this.src[i] === "=") i++;
    if (this.src[i] !== "[") return null;
    const level = i - this.pos - 1;
    this.pos = i + 1;
    return level;
  }

  ident(): string {
    const start = this.pos;
    if (!isIdentStart(this.at())) return "";
    while (!this.eof() && isIdent(this.at())) this.pos++;
    return this.src.slice(start, this.pos);
  }

  value(depth: number): LuaValue {
    this.skip();
    if (this.eof()) throw this.error("unexpected end of file");
    const c = this.at();
    if (c === "{") {
      if (depth >= MAX_DEPTH) throw this.error("tables nested too deep");
      return this.table(depth + 1);
    }
    if (c === '"' || c === "'") return this.str();
    if (c === "[") {
      const level = this.longBracket();
      if (level === null) throw this.error("unexpected '['");
      return this.longString(level);
    }
    if (c === "-" || c === "." || (c >= "0" && c <= "9")) return this.number();
    const word = this.ident();
    if (word === "true") return true;
    if (word === "false") return false;
    if (word === "nil") return null;
    if (word === "") throw this.error(`unexpected ${JSON.stringify(c)}`);
    throw this.error(`unexpected ${JSON.stringify(word)} (not data)`);
  }

  table(depth: number): LuaValue {
    this.pos++; // {
    const entries: { key: string; idx: number; val: LuaValue }[] = [];
    let next = 1; // the implicit index of the next positional value
    for (;;) {
      this.skip();
      if (this.consume("}")) break;
      let key: string;
      let idx = 0;
      if (this.at() === "[" && this.at(1) !== "[" && this.at(1) !== "=") {
        // [key] = value
        this.pos++;
        const k = this.value(depth);
        this.skip();
        if (!this.consume("]")) throw this.error("expected ']'");
        this.skip();
        if (!this.consume("=")) throw this.error("expected '='");
        if (typeof k === "string") key = k;
        else if (typeof k === "number") {
          if (Number.isInteger(k) && k >= 1 && k <= 2 ** 31) idx = k;
          key = String(k);
        } else if (typeof k === "boolean") key = String(k);
        else throw this.error("unsupported table key");
      } else if (isIdentStart(this.at())) {
        // name = value, or a bare true/false/nil value
        const save = this.pos;
        const name = this.ident();
        this.skip();
        if (this.consume("=")) key = name;
        else {
          this.pos = save;
          idx = next;
          key = String(next++);
        }
      } else {
        idx = next;
        key = String(next++);
      }
      const val = this.value(depth);
      if (val !== null) entries.push({ key, idx, val }); // (nil entries don't exist in Lua)
      this.skip();
      if (!this.consume(",") && !this.consume(";")) {
        this.skip();
        if (!this.consume("}")) throw this.error("expected ',' or '}'");
        break;
      }
    }
    // An array when the keys are exactly 1..n (in any order).
    const seen = new Set<number>();
    const isArray = entries.length > 0 && entries.every((e) => e.idx >= 1 && e.idx <= entries.length && !seen.has(e.idx) && seen.add(e.idx));
    if (isArray) {
      const arr: LuaValue[] = new Array(entries.length);
      for (const e of entries) arr[e.idx - 1] = e.val;
      return arr;
    }
    if (entries.length === 0) return [];
    const obj: Record<string, LuaValue> = {};
    for (const e of entries) obj[e.key] = e.val;
    return obj;
  }

  str(): string {
    const quote = this.at();
    this.pos++;
    let out = "";
    let bytes: number[] = []; // \ddd escapes: bytes, decoded together (a UTF-8 letter may take several)
    const flush = () => {
      if (bytes.length) out += new TextDecoder().decode(new Uint8Array(bytes));
      bytes = [];
    };
    const ESCAPES: Record<string, string> = { n: "\n", t: "\t", r: "\r", a: "\x07", b: "\b", f: "\f", v: "\v", "\n": "\n", "\\": "\\", '"': '"', "'": "'" };
    for (;;) {
      if (this.eof()) throw this.error("unterminated string");
      const c = this.at();
      this.pos++;
      if (c === quote) {
        flush();
        return out;
      }
      if (c === "\n") throw this.error("newline in string");
      if (c !== "\\") {
        flush();
        out += c;
        continue;
      }
      if (this.eof()) throw this.error("unterminated string");
      const e = this.at();
      this.pos++;
      if (e in ESCAPES) {
        flush();
        out += ESCAPES[e];
      } else if (e >= "0" && e <= "9") {
        let n = Number(e);
        for (let i = 0; i < 2 && this.at() >= "0" && this.at() <= "9"; i++) {
          n = n * 10 + Number(this.at());
          this.pos++;
        }
        if (n > 255) throw this.error(`bad escape \\${n}`);
        bytes.push(n);
      } else {
        throw this.error(`bad escape \\${e}`);
      }
    }
  }

  longString(level: number): string {
    const end = "]" + "=".repeat(level) + "]";
    const i = this.src.indexOf(end, this.pos);
    if (i < 0) throw this.error("unterminated long string");
    const s = this.src.slice(this.pos, i);
    this.pos = i + end.length;
    return s.startsWith("\n") ? s.slice(1) : s; // (Lua drops a newline right after [[)
  }

  number(): number {
    const start = this.pos;
    if (this.consume("-")) this.skip();
    while (!this.eof()) {
      const c = this.at();
      const prev = this.src[this.pos - 1];
      if (/[0-9.eExXa-fA-F]/.test(c) || ((c === "+" || c === "-") && (prev === "e" || prev === "E"))) {
        this.pos++;
        continue;
      }
      break;
    }
    const lit = this.src.slice(start, this.pos).replace(/\s/g, "");
    const neg = lit.startsWith("-");
    const digits = neg ? lit.slice(1) : lit;
    let n: number;
    if (/^0[xX][0-9a-fA-F]+$/.test(digits)) n = parseInt(digits.slice(2), 16);
    else if (/^(inf|1\.#inf)$/i.test(digits)) n = 0;
    else if (/^(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$/.test(digits)) n = Number(digits);
    else throw this.error(`bad number ${JSON.stringify(lit)}`);
    if (!Number.isFinite(n)) n = 0; // (JSON has no infinity; never meaningful in our data)
    return neg ? -n : n;
  }
}

/** What the site reads of a character's record (Ravenpost's hearthtaleFields): the book, who wrote it, its link code. */
export const HEARTHTALE_FIELDS = ["guid", "name", "realm", "region", "race", "class", "hardcore", "closed", "book", "link"];

/** A Hearthtale saved file's character record, cut to what the site reads; null if the file holds none. */
export function hearthtaleRecord(src: string): Record<string, LuaValue> | null {
  const vars = parseSavedVariables(src);
  const rec = vars.HearthtaleChar;
  if (!rec || typeof rec !== "object" || Array.isArray(rec)) return null;
  const out: Record<string, LuaValue> = {};
  for (const k of HEARTHTALE_FIELDS) if (k in rec) out[k] = rec[k];
  return out;
}
