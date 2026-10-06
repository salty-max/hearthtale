import { describe, expect, test } from "bun:test";
import { pooled } from "@/db/local";

describe("db", () => {
  test("a transaction pooler is recognised (no prepared statements through it)", () => {
    expect(pooled("postgresql://u:p@ep-cool-name-123456-pooler.eu-central-1.aws.neon.tech/neondb?sslmode=require")).toBe(true);
    expect(pooled("postgresql://u:p@ep-cool-name-123456.eu-central-1.aws.neon.tech/neondb?sslmode=require")).toBe(false);
    expect(pooled("postgres://u:p@aws-0-eu-west-1.pooler.supabase.com:6543/postgres")).toBe(true);
    expect(pooled("postgres://hearthtale:hearthtale@localhost:5435/hearthtale")).toBe(false);
  });
});
