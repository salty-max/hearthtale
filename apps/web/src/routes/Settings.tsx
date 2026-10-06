import { Link } from "@tanstack/react-router";
import { LogIn, LogOut } from "lucide-react";
import type { ReactNode } from "react";
import { useMe, useSignOut } from "@/lib/api";
import { CATALOGS, LANGS, useLang, useT } from "@/lib/i18n";
import { FONTS, readerClasses, setSettings, SIZES, SPACINGS, THEMES, useSettings, type Settings as S } from "@/lib/settings";

/** A row of choices, one selected (radio buttons that look like a segmented control). */
function Choice<K extends string>({ label, value, options, name, render }: { label: string; value: K; options: K[]; name: keyof S; render: (k: K) => ReactNode }) {
  return (
    <fieldset className="mt-4">
      <legend className="text-parchment/70">{label}</legend>
      <div className="mt-2 flex flex-wrap gap-2">
        {options.map((k) => (
          <button
            key={k}
            onClick={() => setSettings({ [name]: k } as Partial<S>)}
            aria-pressed={value === k}
            className={
              value === k
                ? "min-w-14 rounded-md border border-gold bg-gold/15 px-3 py-1.5 text-gold-bright"
                : "min-w-14 rounded-md border border-leather-edge px-3 py-1.5 text-parchment/80 hover:border-gold/60"
            }
          >
            {render(k)}
          </button>
        ))}
      </div>
    </fieldset>
  );
}

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="rounded-md border border-leather-edge bg-leather/50 p-4">
      <h2 className="title text-xl">{title}</h2>
      {children}
    </section>
  );
}

export function Settings() {
  const t = useT();
  const s = useSettings();
  const lang = useLang();
  const me = useMe();
  const signOut = useSignOut();
  const cls = readerClasses(s);
  return (
    <div className="mx-auto max-w-2xl space-y-5 pb-4">
      <h1 className="title text-3xl">{t.settings.title}</h1>

      <Section title={t.settings.reading}>
        <div className={`${cls.page} mt-3 rounded-md px-5 py-4`}>
          <p className={cls.text}>{t.settings.preview}</p>
        </div>
        <Choice label={t.settings.size} name="size" value={s.size} options={SIZES} render={(k) => <span className={{ s: "text-sm", m: "text-base", l: "text-lg", xl: "text-xl" }[k]}>A</span>} />
        <Choice label={t.settings.font} name="font" value={s.font} options={FONTS} render={(k) => <span className={k === "sans" ? "font-sans" : "font-book"}>{t.settings.fonts[k]}</span>} />
        <Choice label={t.settings.paper} name="theme" value={s.theme} options={THEMES} render={(k) => t.settings.themes[k]} />
        <Choice label={t.settings.spacing} name="spacing" value={s.spacing} options={SPACINGS} render={(k) => t.settings.spacings[k]} />
      </Section>

      {LANGS.length > 1 && (
        <Section title={t.settings.language}>
          <Choice label={t.settings.languageHint} name="lang" value={lang} options={LANGS} render={(k) => CATALOGS[k].name} />
        </Section>
      )}

      <Section title={t.settings.account}>
        {me.data ? (
          <div className="mt-3 flex flex-wrap items-center justify-between gap-3">
            <span>{t.settings.signedInAs(me.data.battletag ?? t.account.you)}</span>
            <button onClick={() => signOut.mutate()} className="btn">
              <LogOut className="size-4" aria-hidden />
              {t.account.signOut}
            </button>
          </div>
        ) : (
          <div className="mt-3">
            <Link to="/library" className="btn">
              <LogIn className="size-4" aria-hidden />
              {t.account.signInShort}
            </Link>
          </div>
        )}
      </Section>

      <Section title={t.settings.about}>
        <p className="mt-2 text-parchment/75">{t.settings.version(__APP_VERSION__, __APP_COMMIT__, __BUILD_DATE__)}</p>
        <p className="mt-1 text-parchment/75">
          <a href="https://github.com/salty-max/hearthtale" className="underline">
            {t.footer.source}
          </a>
          {" · "}
          {t.footer.notAffiliated}
        </p>
      </Section>
    </div>
  );
}
