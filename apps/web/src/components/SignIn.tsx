import { REGIONS, type Region } from "@hearthtale/shared";
import { LogIn } from "lucide-react";
import { useState } from "react";
import { useTestSignIn } from "@/lib/api";
import { useT } from "@/lib/i18n";

/** "Sign in with Battle.net", in a region (Battle.net lists the characters of one region at a time). */
export function SignIn({ problem, next }: { problem?: "failed" | "cancelled"; next?: string }) {
  const t = useT();
  const [region, setRegion] = useState<Region>("eu");
  const test = useTestSignIn();
  return (
    <div className="page mx-auto mt-6 max-w-md rounded-md px-6 py-8 text-center">
      <h2 className="title text-2xl text-[#7a5410]">{t.account.signInTitle}</h2>
      <p className="mt-3 text-lg">{t.account.signInWhy}</p>
      {problem && <p className="mt-3 text-fallen">{problem === "failed" ? t.account.failed : t.account.cancelled}</p>}
      <label className="mt-5 block text-ink-faded">
        {t.account.region}{" "}
        <select
          value={region}
          onChange={(e) => setRegion(e.target.value as Region)}
          className="ml-1 rounded border border-ink/30 bg-parchment px-2 py-1 text-ink"
        >
          {REGIONS.map((r) => (
            <option key={r} value={r}>
              {t.account.regions[r]}
            </option>
          ))}
        </select>
      </label>
      <a href={`/api/auth/login?region=${region}${next ? `&next=${encodeURIComponent(next)}` : ""}`} className="btn mt-5">
        <LogIn className="size-4" aria-hidden />
        {t.account.signIn}
      </a>
      <p className="mt-4 text-sm text-ink-faded">{t.account.forever}</p>
      {import.meta.env.DEV && (
        <button onClick={() => test.mutate()} className="mt-6 block w-full text-sm text-ink-faded underline">
          {t.account.testAccount}
        </button>
      )}
    </div>
  );
}
