import type { Health } from "@hearthtale/shared";
import { Hono } from "hono";
import { log } from "@/lib/log";

export const app = new Hono();

app.onError((err, c) => {
  log.error("http.error", { path: c.req.path, err: String(err) });
  return c.json({ error: "internal error" }, 500);
});

app.get("/api/health", (c) => c.json({ ok: true, version: process.env.VERCEL_GIT_COMMIT_SHA?.slice(0, 7) ?? "dev" } satisfies Health));

app.all("/api/*", (c) => c.json({ error: "not found" }, 404));
