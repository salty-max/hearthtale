import { Navigate, useParams } from "@tanstack/react-router";
import { LoadError, Loading } from "@/components/PageState";
import { SignIn } from "@/components/SignIn";
import { NotFound, NotSignedIn, useCharacterBook } from "@/lib/api";
import { current, parts } from "@/lib/book";
import { useT } from "@/lib/i18n";
import { resumeAt } from "@/lib/seen";

/**
 * Opening a book: at the first entry this device hasn't read, else where it
 * was left, else the chapter being written (or the last part).
 */
export function Book() {
  const t = useT();
  const { id } = useParams({ from: "/book/$id" });
  const { data, error, refetch } = useCharacterBook(Number(id));
  if (error) {
    if (error instanceof NotSignedIn) return <SignIn />;
    return <LoadError message={error instanceof NotFound ? t.book.notFound : undefined} retry={error instanceof NotFound ? undefined : () => void refetch()} />;
  }
  if (!data) return <Loading />;
  const keys = parts(data.book).map((p) => p.key);
  const resume = resumeAt(data.character.id, data.character.chapters);
  const part = resume && keys.includes(resume) ? resume : current(data.book);
  if (!part) return <LoadError message={t.book.nothingYet} />;
  return <Navigate to="/book/$id/$part" params={{ id, part }} replace />;
}
