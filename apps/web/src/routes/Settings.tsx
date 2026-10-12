import { Link } from "@tanstack/react-router";
import { Bell, BellOff, LogIn, LogOut, Monitor, Moon, Sun } from "lucide-react";
import type { ReactNode } from "react";
import { useMe, useSignOut } from "@/lib/api";
import { CATALOGS, LANGS, useLang, useT } from "@/lib/i18n";
import { usePush } from "@/lib/push";
import { FONT_CLASS, FONTS, readerClasses, setSettings, SITE_THEMES, SIZES, SPACINGS, THEMES, useSettings, type Settings as S } from "@/lib/settings";
import { useTitle } from "@/lib/title";

/** A row of choices, one selected (radio buttons that look like a segmented control). */
function Choice<K extends string>({ label, value, options, name, render }: { label: string; value: K; options: K[]; name: keyof S; render: (k: K) => ReactNode }) {
  return (
    <fieldset className="mt-4">
      <legend className="ui text-sm tracking-wide text-parchment/70 uppercase">{label}</legend>
      <div className="mt-2 flex flex-wrap gap-2">
        {options.map((k) => (
          <button
            key={k}
            onClick={() => setSettings({ [name]: k } as Partial<S>)}
            aria-pressed={value === k}
            className={
              value === k
                ? "ui flex min-w-14 items-center justify-center gap-2 rounded-md border border-gold bg-gold/15 px-3 py-1.5 text-gold-bright shadow-[0_0_10px_rgb(232_199_90/0.2)]"
                : "ui flex min-w-14 items-center justify-center gap-2 rounded-md border border-leather-edge px-3 py-1.5 text-parchment/80 hover:border-gold/60"
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
    <section className="panel p-5">
      <h2 className="title text-2xl">{title}</h2>
      {children}
    </section>
  );
}

const SITE_ICONS = { system: Monitor, light: Sun, dark: Moon };

function Notifications({ signedIn }: { signedIn: boolean }) {
  const t = useT();
  const push = usePush(signedIn);
  if (!signedIn)
    return (
      <p className="mt-2 text-parchment/75">
        {t.push.signIn}{" "}
        <Link to="/library" className="text-gold-bright underline">
          {t.account.signInShort}
        </Link>
      </p>
    );
  const note =
    push.state === "unsupported" || push.state === "unavailable"
      ? t.push.unsupported
      : push.state === "ios"
        ? t.push.ios
        : push.state === "denied"
          ? t.push.denied
          : undefined;
  return (
    <>
      <p className="mt-2 text-parchment/75">{t.push.why}</p>
      {note ? (
        <p className="mt-3 text-parchment/70 italic">{note}</p>
      ) : (
        <label className="mt-3 flex cursor-pointer items-center gap-3">
          <input
            type="checkbox"
            checked={push.state === "on"}
            disabled={push.busy}
            onChange={(e) => void (e.target.checked ? push.turnOn() : push.turnOff())}
            className="size-4 accent-[#c9a227]"
          />
          {push.state === "on" ? <Bell className="size-4 text-gold-bright" aria-hidden /> : <BellOff className="size-4 text-parchment/60" aria-hidden />}
          {t.push.on}
        </label>
      )}
      {push.failed && <p className="mt-2 text-blood">{t.push.failed}</p>}
    </>
  );
}

export function Settings() {
  const t = useT();
  useTitle(t.settings.title);
  const s = useSettings();
  const lang = useLang();
  const me = useMe();
  const signOut = useSignOut();
  const cls = readerClasses(s);
  return (
    <div className="mx-auto max-w-2xl space-y-5 pb-4">
      <h1 className="title-gilded text-4xl">{t.settings.title}</h1>

      <Section title={t.settings.appearance}>
        <Choice
          label={t.settings.site}
          name="site"
          value={s.site}
          options={SITE_THEMES}
          render={(k) => {
            const Icon = SITE_ICONS[k];
            return (
              <>
                <Icon className="size-4" aria-hidden />
                {t.settings.sites[k]}
              </>
            );
          }}
        />
      </Section>

      <Section title={t.settings.reading}>
        <div className={`${cls.page} mt-3 rounded-md px-5 py-4`}>
          <p className={`${cls.text} drop-cap`}>{t.settings.preview}</p>
        </div>
        <Choice label={t.settings.size} name="size" value={s.size} options={SIZES} render={(k) => <span className={{ s: "text-sm", m: "text-base", l: "text-lg", xl: "text-xl" }[k]}>A</span>} />
        <Choice
          label={t.settings.font}
          name="font"
          value={s.font}
          options={FONTS}
          render={(k) => <span className={FONT_CLASS[k]}>{t.settings.fonts[k]}</span>}
        />
        <Choice label={t.settings.paper} name="theme" value={s.theme} options={THEMES} render={(k) => t.settings.themes[k]} />
        <Choice label={t.settings.spacing} name="spacing" value={s.spacing} options={SPACINGS} render={(k) => t.settings.spacings[k]} />
      </Section>

      <Section title={t.push.title}>
        <Notifications signedIn={!!me.data} />
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
            <Link to="/library" className="btn btn-primary">
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
          <Link to="/privacy" className="underline">
            {t.footer.privacy}
          </Link>
          {" · "}
          {t.footer.notAffiliated}
        </p>
      </Section>
    </div>
  );
}
