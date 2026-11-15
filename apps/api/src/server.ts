import { serveStatic } from "hono/bun";
import { app } from "@/app";
import { initDb, requireDatabase } from "@/db/local";
import { setLogFormat, setLogLevel } from "@/lib/log";

// Bun entry (local dev). Bun auto-loads .env/.env.local, and a `vercel env pull`
// inside apps/api would make it Neon's production: like the db scripts, it
// refuses a database off this machine unless asked (--prod, db/local.ts).
// `bun run dev` never passes it: serving one on purpose is this file alone.
// (Vercel's entry is vercel.ts, which is never guarded: it is the production.)
const DEV_SERVER_HINT =
  "`bun run dev` never takes --prod. To serve this database on purpose, run the api alone with it\n" +
  "(PORT=3002 bun run --env-file=.env.local --filter @hearthtale/api start --prod; docs/site.md, \"Database scripts\").";

requireDatabase(initDb(), process.argv.slice(2), true, DEV_SERVER_HINT);
setLogLevel(process.env.LOG_LEVEL);
setLogFormat(process.env.LOG_FORMAT ?? "pretty");

app.use("/*", serveStatic({ root: "../web/dist" }));
app.get("*", serveStatic({ path: "../web/dist/index.html" }));

const port = Number(process.env.PORT ?? 3000);
console.log(`Hearthtale API → http://localhost:${port}`);

export default { port, fetch: app.fetch };
