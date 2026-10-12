import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useState } from "react";

/**
 * This device told of new entries, or not: the browser's push subscription,
 * kept by the site for the signed-in account (api: /api/push). Turned on from
 * the settings; the service worker shows them (public/push-sw.js).
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

async function registration(): Promise<ServiceWorkerRegistration | undefined> {
  return navigator.serviceWorker.getRegistration().then((r) => r ?? navigator.serviceWorker.ready);
}

export function usePush(signedIn: boolean) {
  const qc = useQueryClient();
  const key = useQuery({
    queryKey: ["push-key"],
    queryFn: async () => {
      const res = await fetch("/api/push/key");
      return res.ok ? ((await res.json()) as { key: string }).key : null;
    },
    enabled: signedIn && supported(),
    staleTime: Infinity,
  });
  const [subscribed, setSubscribed] = useState<boolean | null>(null);
  const [busy, setBusy] = useState(false);
  const [failed, setFailed] = useState(false);
  useEffect(() => {
    if (!supported()) return;
    void registration().then(async (r) => setSubscribed(!!(await r?.pushManager.getSubscription())));
  }, []);

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
      const res = await fetch("/api/push/subscriptions", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(sub.toJSON()) });
      if (!res.ok) throw new Error(String(res.status));
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
