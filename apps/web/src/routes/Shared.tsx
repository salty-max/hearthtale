import { useParams, useSearch } from "@tanstack/react-router";
import { LoadError, Loading } from "@/components/PageState";
import { Reader } from "@/components/Reader";
import { NotFound, useHallBook, useShared } from "@/lib/api";
import { current } from "@/lib/book";
import { useT } from "@/lib/i18n";
import type { SharedBook } from "@hearthtale/shared";

/** A book, or a part of one, someone shared: read as their own, without an account. */
function SharedReader({ data, error, refetch, base, part }: { data?: SharedBook; error: unknown; refetch: () => void; base: string; part?: string }) {
  const t = useT();
  if (error) return <LoadError message={error instanceof NotFound ? t.share.gone : undefined} retry={error instanceof NotFound ? undefined : refetch} />;
  if (!data) return <Loading />;
  // A link to one part shows that part; a whole book opens on its last (or the part asked for).
  const shown = data.part ?? part ?? current(data.book) ?? "";
  return <Reader character={data.character} book={data.book} part={shown} hrefFor={(p) => `${base}?part=${encodeURIComponent(p)}`} />;
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
  return <SharedReader data={q.data} error={q.error} refetch={() => void q.refetch()} base={`/hall/${id}`} part={part} />;
}
