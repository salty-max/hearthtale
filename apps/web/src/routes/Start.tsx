import { Link } from "@tanstack/react-router";
import { Download } from "lucide-react";
import { ADDON_RELEASES, FILES, RAVENPOST_RELEASES } from "@/lib/downloads";
import { useT } from "@/lib/i18n";

/** Get started: the addon, Ravenpost, and linking them to the library. */
export function Start() {
  const t = useT();
  const s = t.start;
  const file = (href: string, label: string, detail: string) => (
    <li>
      <a href={href} className="btn">
        <Download className="size-4" aria-hidden />
        {label}
      </a>
      <span className="mt-1 block text-ink-faded sm:ml-3 sm:mt-0 sm:inline">{detail}</span>
    </li>
  );
  return (
    <article className="page mx-auto mt-4 max-w-2xl rounded-md px-6 py-8 sm:px-10">
      <h1 className="title text-3xl text-[#7a5410]">{s.title}</h1>
      <p className="mt-3 text-lg leading-relaxed">{s.intro}</p>

      <h2 className="title mt-8 text-xl text-[#7a5410]">{s.addonTitle}</h2>
      <p className="mt-2 text-lg">{s.addon}</p>
      <ul className="mt-3 space-y-3">
        {file(FILES.addon, s.download, s.downloadDetail)}
      </ul>

      <h2 className="title mt-8 text-xl text-[#7a5410]">{s.ravenpostTitle}</h2>
      <p className="mt-2 text-lg">{s.ravenpost}</p>
      <ul className="mt-3 space-y-3">
        {file(FILES.windows, s.windows, s.windowsDetail)}
        {file(FILES.macos, s.macos, s.macosDetail)}
      </ul>
      <p className="mt-2 text-sm text-ink-faded">
        <a href={FILES.windowsArm} className="underline">
          {s.windowsArm}
        </a>{" "}
        · {s.unsigned}
      </p>

      <h2 className="title mt-8 text-xl text-[#7a5410]">{s.stepsTitle}</h2>
      <ol className="mt-3 list-decimal space-y-2 pl-6 text-lg leading-relaxed">
        {s.steps.map((step, i) => (
          <li key={i}>{step}</li>
        ))}
      </ol>
      <p className="mt-4 text-lg">{s.foreverLink}</p>

      <p className="mt-8 flex flex-wrap gap-4">
        <Link to="/library" className="btn">
          {t.nav.library}
        </Link>
        <a href={ADDON_RELEASES} className="self-center text-ink-faded underline">
          {s.addonSource}
        </a>
        <a href={RAVENPOST_RELEASES} className="self-center text-ink-faded underline">
          {s.ravenpostSource}
        </a>
      </p>
    </article>
  );
}
