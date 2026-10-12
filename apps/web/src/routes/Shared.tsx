import type { PublicCharacter, SharedBook } from "@hearthtale/shared";
import { Link, useParams, useSearch } from "@tanstack/react-router";
import { ChevronLeft } from "lucide-react";
import { LoadError, Loading } from "@/components/PageState";
import { Reader } from "@/components/Reader";
import { NotFound, useHallBook, useShared } from "@/lib/api";
import { current } from "@/lib/book";
import { useT } from "@/lib/i18n";

/** A word for a visitor who came by a link: whose journal, what writes it, and how to keep their own. */
function Visitor({ character }: { character: PublicCharacter }) {
  const t = useT();
  return (
    <div className="panel mb-3 flex shrink-0 items-center gap-3 px-4 py-2.5">
      <p className="flex min-w-0 flex-1 items-center gap-2 text-sm leading-snug text-parchment/85 sm:text-base">
        <img src="/logo-48.png" alt="" width={28} height={28} className="size-7 shrink-0" />
        <span>{t.share.visitor(character.name)}</span>
      </p>
      <Link to="/" className="btn btn-primary shrink-0 px-3 py-1">
        {t.share.keepYours}
      </Link>
    </div>
  );
}

/** A book, or a part of one, someone shared: read as their own, without an account. */
function SharedReader({
  data,
  error,
  refetch,
  base,
  part,
  hall,
}: {
  data?: SharedBook;
  error: unknown;
  refetch: () => void;
  base: string;
  part?: string;
  hall?: boolean;
}) {
  const t = useT();
  if (error) return <LoadError message={error instanceof NotFound ? t.share.gone : undefined} retry={error instanceof NotFound ? undefined : refetch} />;
  if (!data) return <Loading />;
  // A link to one part shows that part; a whole book opens on its last (or the part asked for).
  const shown = data.part ?? part ?? current(data.book) ?? "";
  return (
    <Reader
      character={data.character}
      book={data.book}
      part={shown}
      hrefFor={(p) => `${base}?part=${encodeURIComponent(p)}`}
      banner={<Visitor character={data.character} />}
      lead={
        hall ? (
          <Link to="/hall" className="ui flex items-center gap-1 rounded-md px-1.5 py-1.5 text-gold-bright hover:bg-gold/10" aria-label={t.hall.title}>
            <ChevronLeft className="size-5" aria-hidden />
            <span className="hidden md:inline">{t.nav.hall}</span>
          </Link>
        ) : undefined
      }
    />
  );
}

export function Shared() {
  const { token } = useParams({ from: "/s/$token" });
  const { part } = useSearch({ from: "/s/$token" });
  const q = useShared(token);
  return <SharedReader data={q.data} error={q.error} refetch={() => void q.refetch()} base={`/s/${token}`} part={part} />;
}

export function HallBook() {
  const { id } = useParams({ from: "/hall/$id" });
  const { part } = useSearch({ from: "/hall/$id" });
  const q = useHallBook(Number(id));
  return <SharedReader data={q.data} error={q.error} refetch={() => void q.refetch()} base={`/hall/${id}`} part={part} hall />;
}
