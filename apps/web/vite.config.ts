import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import { VitePWA } from "vite-plugin-pwa";
import { readFileSync } from "node:fs";
import path from "node:path";

// Served on every response in production (scripts/vercel-build.sh) and by
// `vite preview`, so the policy can be tried locally before it ships.
const securityHeaders = JSON.parse(readFileSync(new URL("./security-headers.json", import.meta.url), "utf8")) as Record<string, string>;

// The version people know is the addon's (its TOCs, bumped by scripts/release.sh);
// the deployed commit tells which build of the site it is (Vercel sets it).
const toc = readFileSync(new URL("../../addon/Hearthtale/Hearthtale_Vanilla.toc", import.meta.url), "utf8");
const addonVersion = /^## Version:\s*(\S+)/m.exec(toc)?.[1] ?? "dev";
const commit = process.env.VERCEL_GIT_COMMIT_SHA?.slice(0, 7) ?? "dev";

export default defineConfig(() => ({
  define: {
    __APP_VERSION__: JSON.stringify(addonVersion),
    __APP_COMMIT__: JSON.stringify(commit),
    __BUILD_DATE__: JSON.stringify(new Date().toISOString().slice(0, 10)),
  },
  plugins: [
    react(),
    tailwindcss(),
    VitePWA({
      // A new deploy's SW waits and UpdatePrompt offers the reload: an installed
      // PWA can't be hard-refreshed, so "prompt" is what keeps it from going stale.
      registerType: "prompt",
      includeAssets: ["favicon-32.png", "apple-touch-icon.png"],
      manifest: {
        id: "/",
        name: "Hearthtale",
        short_name: "Hearthtale",
        description: "Your WoW character's own journal, written as you play.",
        lang: "en",
        theme_color: "#120d09",
        background_color: "#120d09",
        display: "standalone",
        start_url: "/",
        categories: ["games", "books"],
        icons: [
          { src: "pwa-192.png", sizes: "192x192", type: "image/png" },
          { src: "pwa-512.png", sizes: "512x512", type: "image/png" },
        ],
      },
      workbox: {
        navigateFallback: "/index.html",
        navigateFallbackDenylist: [/^\/api\//],
        // Take control of open pages as soon as a SW activates (else the first
        // session after install has no update banner: see lib/swUpdate.ts).
        clientsClaim: true,
        globPatterns: ["**/*.{js,css,html,svg,png,woff2,ico}"],
        // Latin font subsets only; the others load on demand via unicode-range.
        globIgnores: ["**/*-{cyrillic,cyrillic-ext,greek,greek-ext,vietnamese}-*.woff2"],
        runtimeCaching: [
          {
            // Network first, so a book is fresh online; the cached copy only
            // answers offline, so the books you opened stay readable on a plane.
            urlPattern: ({ url, request }) => url.pathname.startsWith("/api/") && request.method === "GET",
            handler: "NetworkFirst",
            options: { cacheName: "api", networkTimeoutSeconds: 5, expiration: { maxEntries: 200, maxAgeSeconds: 30 * 86400 } },
          },
        ],
      },
      devOptions: { enabled: true, type: "module", suppressWarnings: true },
    }),
  ],
  resolve: {
    alias: { "@": path.resolve(import.meta.dirname, "./src") },
  },
  server: {
    host: true,
    port: 5175,
    strictPort: true,
    proxy: { "/api": "http://localhost:3002" },
  },
  preview: {
    port: 4175,
    headers: securityHeaders,
    proxy: { "/api": "http://localhost:3002" },
  },
  build: { outDir: "dist" },
}));
