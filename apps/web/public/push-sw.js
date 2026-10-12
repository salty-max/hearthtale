// Notifications (imported by the service worker, vite.config.ts): a new
// entry's word, and a tap on it opening the entry (in the open app if any).
self.addEventListener("push", (event) => {
  let m;
  try {
    m = event.data ? event.data.json() : {};
  } catch {
    m = { title: event.data ? event.data.text() : "Hearthtale" };
  }
  event.waitUntil(
    self.registration.showNotification(m.title || "Hearthtale", {
      body: m.body || "",
      icon: "/logo-192.png",
      badge: "/favicon-32.png",
      tag: m.tag,
      data: { url: m.url || "/library" },
    }),
  );
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const url = new URL((event.notification.data && event.notification.data.url) || "/library", self.location.origin).href;
  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((all) => {
      for (const c of all) {
        if (new URL(c.url).origin === self.location.origin && "focus" in c) {
          c.navigate(url);
          return c.focus();
        }
      }
      return self.clients.openWindow(url);
    }),
  );
});
