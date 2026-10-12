import { Link } from "@tanstack/react-router";
import { useT } from "@/lib/i18n";
import { useTitle } from "@/lib/title";

export function NotFound() {
  const t = useT();
  useTitle(t.notFound.title);
  return (
    <article className="page mx-auto mt-10 max-w-md rounded-md px-6 py-10 text-center">
      <h1 className="title text-2xl">{t.notFound.title}</h1>
      <p className="mt-3 text-lg">{t.notFound.body}</p>
      <Link to="/" className="btn mt-6">
        {t.notFound.back}
      </Link>
    </article>
  );
}
