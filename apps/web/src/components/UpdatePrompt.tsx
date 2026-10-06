import { RefreshCw, X } from "lucide-react";
import { useRef } from "react";
import { useRegisterSW } from "virtual:pwa-register/react";
import { useT } from "@/lib/i18n";
import { applyUpdate } from "@/lib/swUpdate";

// vite-plugin-pwa only checks for a new SW at cold start; an installed PWA that
// is never fully closed would never see an update without this poll.
const UPDATE_CHECK_INTERVAL = 30 * 60 * 1000;

/** "New version available" banner (registerType: "prompt"). */
export function UpdatePrompt() {
  const t = useT();
  const registrationRef = useRef<ServiceWorkerRegistration | null>(null);
  const {
    needRefresh: [needRefresh, setNeedRefresh],
  } = useRegisterSW({
    onRegisteredSW(_swUrl, registration) {
      if (!registration) return;
      registrationRef.current = registration;
      const recheck = () => void registration.update().catch(() => {});
      setInterval(recheck, UPDATE_CHECK_INTERVAL);
      const onForeground = () => {
        if (document.visibilityState === "visible") recheck();
      };
      document.addEventListener("visibilitychange", onForeground);
      window.addEventListener("online", onForeground);
    },
  });

  if (!needRefresh) return null;

  return (
    <div className="page fixed inset-x-3 bottom-20 z-50 md:bottom-6 mx-auto flex max-w-md items-center gap-2 rounded-md px-3 py-2">
      <span className="flex-1 text-base">{t.update.available}</span>
      <button onClick={() => applyUpdate(registrationRef.current, { reload: () => window.location.reload() })} className="btn">
        <RefreshCw className="size-4" />
        {t.update.reload}
      </button>
      <button onClick={() => setNeedRefresh(false)} aria-label={t.update.close} className="p-2 text-ink">
        <X className="size-4" />
      </button>
    </div>
  );
}
