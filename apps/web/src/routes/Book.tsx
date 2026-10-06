import { Navigate, useParams } from "@tanstack/react-router";
import { LoadError, Loading } from "@/components/PageState";
import { NotFound, NotSignedIn, useCharacterBook } from "@/lib/api";
import { SignIn } from "@/components/SignIn";
import { current } from "@/lib/book";
import { useT } from "@/lib/i18n";

/** Opening a book: straight to the part to read (the chapter being written, else the last). */
export function Book() {
  const t = useT();
  const { id } = useParams({ from: "/book/$id" });
  const { data, error, refetch } = useCharacterBook(Number(id));
  if (error) {
    if (error instanceof NotSignedIn) return <SignIn />;
    return <LoadError message={error instanceof NotFound ? t.book.notFound : undefined} retry={error instanceof NotFound ? undefined : () => void refetch()} />;
  }
  if (!data) return <Loading />;
  const part = current(data.book);
  if (!part) return <LoadError message={t.book.nothingYet} />;
  return <Navigate to="/book/$id/$part" params={{ id, part }} replace />;
}
