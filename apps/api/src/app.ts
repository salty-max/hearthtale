import type { Health } from "@hearthtale/shared";
import { Hono, type MiddlewareHandler } from "hono";
import { getCharacterBook, listCharacters } from "@/lib/characters";
import { log } from "@/lib/log";

export const app = new Hono();

app.onError((err, c) => {
  log.error("http.error", { path: c.req.path, err: String(err) });
  return c.json({ error: "internal error" }, 500);
});

app.get("/api/health", (c) => c.json({ ok: true, version: process.env.VERCEL_GIT_COMMIT_SHA?.slice(0, 7) ?? "dev" } satisfies Health));

// Every character, unguarded: test data only until accounts make books private
// (PLAN.md, step 4). Never answered on a production deployment meanwhile.
const notInProduction: MiddlewareHandler = async (c, next) => {
  if (process.env.VERCEL_ENV === "production") return c.json({ error: "not found" }, 404);
  await next();
};

app.get("/api/characters", notInProduction, async (c) => c.json(await listCharacters()));

app.get("/api/characters/:id", notInProduction, async (c) => {
  const id = Number(c.req.param("id"));
  if (!Number.isInteger(id) || id <= 0) return c.json({ error: "not found" }, 404);
  const found = await getCharacterBook(id);
  return found ? c.json(found) : c.json({ error: "not found" }, 404);
});

app.all("/api/*", (c) => c.json({ error: "not found" }, 404));
