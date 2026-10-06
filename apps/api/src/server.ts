import { serveStatic } from "hono/bun";
import { app } from "@/app";
import { initDb } from "@/db/local";
import { setLogFormat, setLogLevel } from "@/lib/log";

// Bun entry (local dev). Bun auto-loads .env/.env.local.

initDb();
setLogLevel(process.env.LOG_LEVEL);
setLogFormat(process.env.LOG_FORMAT ?? "pretty");

app.use("/*", serveStatic({ root: "../web/dist" }));
app.get("*", serveStatic({ path: "../web/dist/index.html" }));

const port = Number(process.env.PORT ?? 3000);
console.log(`Hearthtale API → http://localhost:${port}`);

export default { port, fetch: app.fetch };
