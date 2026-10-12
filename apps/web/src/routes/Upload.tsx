import { Link } from "@tanstack/react-router";
import { BookOpen, FileUp, Upload as UploadIcon } from "lucide-react";
import { useRef, useState } from "react";
import { Crest } from "@/components/Crest";
import { Loading } from "@/components/PageState";
import { SignIn } from "@/components/SignIn";
import { useMe, useUpload } from "@/lib/api";
import { useT } from "@/lib/i18n";
import { hearthtaleRecord, type LuaValue } from "@/lib/luasv";
import { useTitle } from "@/lib/title";

const MAX_FILE = 4 * 1024 * 1024;
type Found = { record: Record<string, LuaValue>; name: string; cls: string; entries: number };

/**
 * A character's book brought by hand, for a player without Ravenpost: the
 * saved file (WTF/…/SavedVariables/Hearthtale.lua) read here, in the browser
 * (lib/luasv.ts: data, never run), only what the site reads of it sent, the
 * same proofs of ownership as the companion's.
 */
export function Upload() {
  const t = useT();
  const u = t.upload;
  useTitle(u.title);
  const me = useMe();
  const upload = useUpload();
  const input = useRef<HTMLInputElement>(null);
  const [over, setOver] = useState(false);
  const [found, setFound] = useState<Found | null>(null);
  const [problem, setProblem] = useState<string | null>(null);

  async function read(file: File | undefined) {
    upload.reset();
    setFound(null);
    setProblem(null);
    if (!file) return;
    if (file.size > MAX_FILE) return setProblem(u.tooBig);
    try {
      const record = hearthtaleRecord(await file.text());
      if (!record) return setProblem(u.notLua);
      const book = record.book as { chapters?: unknown[] } | undefined;
      const entries = Array.isArray(book?.chapters) ? book.chapters.length : 0;
      if (!book) return setProblem(u.noBook);
      setFound({ record, name: String(record.name ?? "?"), cls: String(record.class ?? ""), entries });
    } catch {
      setProblem(u.notLua);
    }
  }

  if (me.isPending) return <Loading />;
  if (!me.data)
    return (
      <section className="mx-auto mt-4 max-w-md text-center">
        <h1 className="title-gilded text-4xl">{u.title}</h1>
        <SignIn />
      </section>
    );
  const result = upload.data?.characters[0];
  return (
    <section className="mx-auto mt-4 max-w-2xl">
      <h1 className="title-gilded text-4xl">{u.title}</h1>
      <p className="mt-2 text-lg text-parchment/80">{u.intro}</p>
      <div className="panel mt-4 p-4">
        <p className="ui text-sm tracking-wide text-parchment/65 uppercase">{u.where}</p>
        <ul className="mt-2 space-y-1">
          {u.paths.map((p) => (
            <li key={p} className="font-mono text-xs break-all text-parchment/80">
              {p}
            </li>
          ))}
        </ul>
      </div>
      <label
        onDragOver={(e) => {
          e.preventDefault();
          setOver(true);
        }}
        onDragLeave={() => setOver(false)}
        onDrop={(e) => {
          e.preventDefault();
          setOver(false);
          void read(e.dataTransfer.files[0]);
        }}
        className={`mt-4 flex cursor-pointer flex-col items-center gap-3 rounded-lg border-2 border-dashed px-6 py-10 text-center transition-colors ${
          over ? "border-gold bg-gold/10" : "border-gold/40 hover:border-gold"
        }`}
      >
        <FileUp className="size-10 text-gold-bright" aria-hidden />
        <span className="title text-xl">{u.drop}</span>
        <span className="btn">{u.choose}</span>
        <input ref={input} type="file" accept=".lua,text/plain" className="sr-only" onChange={(e) => void read(e.target.files?.[0])} />
      </label>
      {problem && <p className="mt-4 text-blood">{problem}</p>}
      {found && (
        <div className="panel mt-4 flex flex-wrap items-center justify-between gap-3 p-4">
          <span className="flex items-center gap-3">
            <Crest token={found.cls} size={40} />
            <span className="text-lg">{u.found(found.name, found.entries)}</span>
          </span>
          {!result && (
            <button onClick={() => upload.mutate(found.record)} disabled={upload.isPending} className="btn btn-primary">
              <UploadIcon className="size-4" aria-hidden />
              {upload.isPending ? u.sending : u.send}
            </button>
          )}
        </div>
      )}
      {upload.isError && <p className="mt-3 text-blood">{u.failed}</p>}
      {result && (
        <div className="mt-3">
          {result.status === "saved" ? (
            <p className="flex flex-wrap items-center gap-3 text-lg">
              {u.saved}
              {result.characterId && (
                <Link to="/book/$id" params={{ id: String(result.characterId) }} className="btn btn-primary">
                  <BookOpen className="size-4" aria-hidden />
                  {u.open}
                </Link>
              )}
            </p>
          ) : (
            <p className="text-lg text-parchment/85">{result.status === "unlinked" ? u.unlinked : result.status === "removed" ? u.removed : u.invalid}</p>
          )}
        </div>
      )}
    </section>
  );
}
