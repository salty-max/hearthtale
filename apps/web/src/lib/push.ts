import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useState } from "react";
import { CATALOGS, useLang } from "@/lib/i18n";

/**
 * This device told of new entries, or not: the browser's push subscription,
 * kept by the site for the signed-in account (api: /api/push). Turned on from
 * the settings; the service worker shows them (public/push-sw.js). The site's
 * language goes with it, what the device's notifications are worded in, sent
 * again while it is on (a change of language, one turned on before it was kept).
 */
export type PushState = "unsupported" | "ios" | "unavailable" | "denied" | "off" | "on";

const supported = () => typeof window !== "undefined" && "serviceWorker" in navigator && "PushManager" in window && "Notification" in window;
// (iPhone and iPad: only an app added to the Home Screen may be told)
const iosBrowser = () =>
  typeof navigator !== "undefined" &&
  /iPhone|iPad|iPod/.test(navigator.userAgent) &&
  !(window.matchMedia?.("(display-mode: standalone)").matches || (navigator as Navigator & { standalone?: boolean }).standalone);

function keyBytes(b64url: string): Uint8Array<ArrayBuffer> {
  const s = atob(b64url.replace(/-/g, "+").replace(/_/g, "/") + "=".repeat((4 - (b64url.length % 4)) % 4));
  const out = new Uint8Array(s.length);
  for (let i = 0; i < s.length; i++) out[i] = s.charCodeAt(i);
  return out;
}

// What was last sent for this device's subscription: its account and language (a visit to the settings
// sends nothing new; another account signed in here, or another language, sends it again).
const SENT = "hearthtale.push.sent";
const sentKey = (sub: PushSubscription, account: string, language: string) => JSON.stringify([sub.endpoint, account, language]);
function forgetSent(): void {
  try {
    localStorage.removeItem(SENT);
  } catch {
    // (nothing kept)
  }
}
function wasSent(key: string): boolean {
  try {
    return localStorage.getItem(SENT) === key;
  } catch {
    return false;
  }
}

/** Hands the site this device's subscription, with the language its notifications are worded in. */
async function send(sub: PushSubscription, account: string, language: string): Promise<void> {
  const res = await fetch("/api/push/subscriptions", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ ...sub.toJSON(), language }) });
  if (!res.ok) throw new Error(String(res.status));
  try {
    localStorage.setItem(SENT, sentKey(sub, account, language));
  } catch {
    // (none kept: the next visit sends it again)
  }
}

async function registration(): Promise<ServiceWorkerRegistration | undefined> {
  return navigator.serviceWorker.getRegistration().then((r) => r ?? navigator.serviceWorker.ready);
}

// The site's public key for push (null: the site has none, VAPID_* unset: no notifications at all).
const pushKey = {
  queryKey: ["push-key"],
  queryFn: async () => {
    const res = await fetch("/api/push/key");
    return res.ok ? ((await res.json()) as { key: string }).key : null;
  },
  staleTime: Infinity,
};

/** Whether the site sends notifications at all (its key, or null). */
export function usePushKey() {
  return useQuery(pushKey);
}

/** `account`: who is signed in (their BattleTag, "" without one), null for nobody. */
export function usePush(account: string | null) {
  const signedIn = account !== null;
  const qc = useQueryClient();
  const key = useQuery({ ...pushKey, enabled: signedIn && supported() });
  const [subscribed, setSubscribed] = useState<boolean | null>(null);
  const [busy, setBusy] = useState(false);
  const [failed, setFailed] = useState(false);
  const language = CATALOGS[useLang()].language;
  useEffect(() => {
    if (!supported()) return;
    void registration().then(async (r) => setSubscribed(!!(await r?.pushManager.getSubscription())));
  }, []);
  // (on, the site keeps the language it's in: sent again at each change)
  useEffect(() => {
    if (!signedIn || !subscribed) return;
    void registration()
      .then(async (r) => {
        const sub = await r?.pushManager.getSubscription();
        if (sub && !wasSent(sentKey(sub, account ?? "", language))) await send(sub, account ?? "", language);
      })
      .catch(() => {});
  }, [signedIn, account, subscribed, language]);

  let state: PushState = "off";
  if (iosBrowser()) state = "ios";
  else if (!supported()) state = "unsupported";
  else if (key.data === null) state = "unavailable";
  else if (Notification.permission === "denied") state = "denied";
  else if (subscribed) state = "on";

  async function turnOn() {
    if (!key.data) return;
    setBusy(true);
    setFailed(false);
    try {
      if ((await Notification.requestPermission()) !== "granted") return;
      const r = await registration();
      if (!r) throw new Error("no service worker");
      const sub = (await r.pushManager.getSubscription()) ?? (await r.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: keyBytes(key.data) }));
      await send(sub, account ?? "", language);
      setSubscribed(true);
    } catch {
      setFailed(true);
    } finally {
      setBusy(false);
      void qc.invalidateQueries({ queryKey: ["push-key"] });
    }
  }

  async function turnOff() {
    setBusy(true);
    setFailed(false);
    forgetSent(); // (a half-done turn-off is sent again at the next visit)
    try {
      const sub = await (await registration())?.pushManager.getSubscription();
      if (sub) {
        await fetch("/api/push/subscriptions", { method: "DELETE", headers: { "content-type": "application/json" }, body: JSON.stringify({ endpoint: sub.endpoint }) });
        await sub.unsubscribe();
      }
      setSubscribed(false);
    } catch {
      setFailed(true);
    } finally {
      setBusy(false);
    }
  }

  return { state, busy, failed, turnOn, turnOff };
}
