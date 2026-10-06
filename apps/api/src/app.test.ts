import { describe, expect, test } from "bun:test";
import { app } from "@/app";

describe("api", () => {
  test("health answers", async () => {
    const res = await app.request("/api/health");
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ ok: true, version: "dev" });
  });
  test("an unknown api route is a 404", async () => {
    expect((await app.request("/api/nope")).status).toBe(404);
  });
  test("the unguarded characters are never served in production", async () => {
    process.env.VERCEL_ENV = "production";
    try {
      expect((await app.request("/api/characters")).status).toBe(404);
      expect((await app.request("/api/characters/1")).status).toBe(404);
    } finally {
      delete process.env.VERCEL_ENV;
    }
  });
});
