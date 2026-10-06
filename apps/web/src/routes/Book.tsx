import { Navigate, useParams } from "@tanstack/react-router";
import { LoadError, Loading } from "@/components/PageState";
import { NotFound, useCharacterBook } from "@/lib/api";
import { current } from "@/lib/book";
import { useT } from "@/lib/i18n";

/** Opening a book: straight to the part to read (the chapter being written, else the last). */
export function Book() {
  const t = useT();
  const { id } = useParams({ from: "/book/$id" });
  const { data, isPending, error, refetch } = useCharacterBook(Number(id));
  if (isPending) return <Loading />;
  if (error) return <LoadError message={error instanceof NotFound ? t.book.notFound : undefined} retry={error instanceof NotFound ? undefined : () => void refetch()} />;
  const part = current(data.book);
  if (!part) return <LoadError message={t.book.nothingYet} />;
  return <Navigate to="/book/$id/$part" params={{ id, part }} replace />;
}
