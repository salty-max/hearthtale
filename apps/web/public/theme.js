// The site's light or dark, set before the first paint (no flash): the
// device's own unless chosen in the settings (lib/theme.ts keeps it after).
(function () {
  var site = "system";
  try {
    var saved = JSON.parse(localStorage.getItem("hearthtale.settings") || "null");
    if (saved && (saved.site === "light" || saved.site === "dark")) site = saved.site;
  } catch {
    // (no storage: the device's own)
  }
  var dark = site === "dark" || (site === "system" && !(window.matchMedia && matchMedia("(prefers-color-scheme: light)").matches));
  document.documentElement.dataset.theme = dark ? "dark" : "light";
})();
