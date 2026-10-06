import { defineConfig } from "drizzle-kit";

// Postgres. `db:generate` emits migrations from the schema; apply them with
// `db:migrate` against MIGRATE_URL or DATABASE_URL.
export default defineConfig({
  schema: "./src/db/schema.ts",
  out: "./drizzle",
  dialect: "postgresql",
  dbCredentials: {
    url: process.env.DATABASE_URL ?? "postgres://hearthtale:hearthtale@localhost:5435/hearthtale",
  },
  verbose: true,
  strict: true,
});
