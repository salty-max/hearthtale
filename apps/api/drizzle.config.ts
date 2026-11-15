import { defineConfig } from "drizzle-kit";

// Postgres. `db:generate` emits migrations from the schema and never connects;
// apply them with `db:migrate` (MIGRATE_URL or DATABASE_URL, guarded: db/local.ts).
// The credentials are the local container's, fixed: drizzle-kit's own push,
// migrate and studio would otherwise follow a DATABASE_URL (a .env.local from
// `vercel env pull`) to the real database with no guard in the way.
export default defineConfig({
  schema: "./src/db/schema.ts",
  out: "./drizzle",
  dialect: "postgresql",
  dbCredentials: {
    url: "postgres://hearthtale:hearthtale@localhost:5435/hearthtale",
  },
  verbose: true,
  strict: true,
});
