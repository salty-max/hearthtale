import { Link } from "@tanstack/react-router";
import { Download, ExternalLink, Upload } from "lucide-react";
import { Flourish } from "@/components/Flourish";
import { ADDON_RELEASES, CURSEFORGE, type Download as File, osOf, RAVENPOST_RELEASES, useDownload, WAGO } from "@/lib/downloads";
import { useT } from "@/lib/i18n";
import { useTitle } from "@/lib/title";

/** Get started: the addon (an addon manager, or the zip), Ravenpost (yours first), and linking them to the library. */
export function Start() {
  const t = useT();
  const s = t.start;
  useTitle(s.title);
  const links = {
    addon: useDownload("addon"),
    windows: useDownload("windows"),
    macos: useDownload("macos"),
    windowsArm: useDownload("windowsArm"),
  };
  const os = osOf();
  const file = (which: File, label: string, detail: string, primary = false) => (
    <li key={which} className="flex flex-col gap-1 sm:flex-row sm:items-center sm:gap-3">
      <a href={links[which].href} className={`btn ${primary ? "btn-primary" : ""} self-start`}>
        <Download className="size-4" aria-hidden />
        {label}
      </a>
      <span className="text-ink-faded">
        {detail}
        {links[which].version ? ` (${links[which].version})` : ""}
        {primary && <span className="tag ml-2 align-middle text-page-title">{s.yours}</span>}
      </span>
    </li>
  );
  const companions: [File, string, string][] = [
    ["windows", s.windows, s.windowsDetail],
    ["macos", s.macos, s.macosDetail],
  ];
  if (os === "macos") companions.reverse();
  return (
    <article className="page mx-auto mt-4 max-w-2xl rounded-md px-6 py-8 sm:px-10">
      <h1 className="title text-4xl">{s.title}</h1>
      <Flourish className="page-title mt-3 opacity-70" />
      <p className="mt-4 text-lg leading-relaxed">{s.intro}</p>

      <h2 className="title mt-8 text-2xl">{s.addonTitle}</h2>
      <p className="mt-2 text-lg">{s.addon}</p>
      <p className="ui mt-4 text-sm tracking-wide text-ink-faded uppercase">{s.managers}</p>
      <div className="mt-2 flex flex-wrap gap-2">
        <a href={CURSEFORGE} className="btn btn-primary">
          <ExternalLink className="size-4" aria-hidden />
          CurseForge
        </a>
        <a href={WAGO} className="btn btn-primary">
          <ExternalLink className="size-4" aria-hidden />
          Wago
        </a>
      </div>
      <p className="ui mt-4 text-sm tracking-wide text-ink-faded uppercase">{s.zip}</p>
      <ul className="mt-2 space-y-3">{file("addon", s.download, s.downloadDetail)}</ul>

      <h2 className="title mt-8 text-2xl">{s.ravenpostTitle}</h2>
      <p className="mt-2 text-lg">{s.ravenpost}</p>
      <ul className="mt-3 space-y-3">{companions.map(([which, label, detail]) => file(which, label, detail, which === os))}</ul>
      <p className="mt-2 text-sm text-ink-faded">
        <a href={links.windowsArm.href} className="underline">
          {s.windowsArm}
        </a>{" "}
        · {s.unsigned}
      </p>
      <p className="mt-3 flex items-start gap-2">
        <Upload className="mt-1 size-4 shrink-0 text-page-title" aria-hidden />
        <Link to="/upload" className="underline">
          {s.uploadInstead}
        </Link>
      </p>

      <h2 className="title mt-8 text-2xl">{s.stepsTitle}</h2>
      <ol className="mt-3 list-decimal space-y-2 pl-6 text-lg leading-relaxed">
        {s.steps.map((step, i) => (
          <li key={i}>{step}</li>
        ))}
      </ol>
      <p className="mt-4 text-lg">{s.foreverLink}</p>

      <p className="mt-8 flex flex-wrap gap-4">
        <Link to="/library" className="btn btn-primary">
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
