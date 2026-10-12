import { Flourish } from "@/components/Flourish";
import { useT } from "@/lib/i18n";
import { useTitle } from "@/lib/title";

/** What the site keeps, what it never does, who reads the books, and how to leave. */
export function Privacy() {
  const t = useT();
  useTitle(t.privacy.title);
  return (
    <article className="page mx-auto mt-4 max-w-2xl rounded-md px-6 py-8 sm:px-10">
      <h1 className="title text-4xl">{t.privacy.title}</h1>
      <p className="page-faded mt-1 italic">{t.privacy.updated}</p>
      <Flourish className="page-title mt-3 opacity-70" />
      {t.privacy.sections.map((s) => (
        <section key={s.title} className="mt-6">
          <h2 className="title text-2xl">{s.title}</h2>
          <p className="mt-2 text-lg leading-relaxed">{s.text}</p>
        </section>
      ))}
    </article>
  );
}
