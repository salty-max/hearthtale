import { describe, expect, test } from "bun:test";
import { app } from "@/app";

// Routes that answer before touching the database (no session cookie).
describe("api", () => {
  test("health answers", async () => {
    const res = await app.request("/api/health");
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ ok: true, version: "dev" });
  });
  test("an unknown api route is a 404", async () => {
    expect((await app.request("/api/nope")).status).toBe(404);
  });
  test("nobody signed in: no account, no library, no book, no link code", async () => {
    expect(await (await app.request("/api/me")).json()).toBeNull();
    expect((await app.request("/api/library")).status).toBe(401);
    expect((await app.request("/api/characters/1")).status).toBe(401);
    expect((await app.request("/api/link-codes", { method: "POST" })).status).toBe(401);
  });
  test("signing in needs a region", async () => {
    expect((await app.request("/api/auth/login?region=mars")).status).toBe(400);
  });
  test("a cancelled sign-in goes back to the library", async () => {
    const res = await app.request("/api/auth/callback?error=access_denied");
    expect(res.status).toBe(302);
    expect(res.headers.get("location")).toBe("/library?signin=cancelled");
  });
  test("the test account is local only", async () => {
    process.env.VERCEL = "1";
    try {
      expect((await app.request("/api/auth/test", { method: "POST" })).status).toBe(404);
    } finally {
      delete process.env.VERCEL;
    }
  });
  test("a companion: pairing codes are checked, an unknown token uploads nothing", async () => {
    expect(await (await app.request("/api/companion/pair/not-a-code")).json()).toEqual({ pending: false });
    const poll = await app.request("/api/companion/pair/poll", { method: "POST", body: JSON.stringify({ code: "nope" }) });
    expect(await poll.json()).toEqual({ status: "expired" });
    expect((await app.request("/api/companion/pair/confirm", { method: "POST", body: "{}" })).status).toBe(401);
    expect((await app.request("/api/companion/upload", { method: "POST", body: "{}" })).status).toBe(401);
  });
  test("sharing: only an owner makes or revokes links, public pages check their keys", async () => {
    expect((await app.request("/api/characters/1/shares", { method: "POST", body: "{}" })).status).toBe(401);
    expect((await app.request("/api/shares/abc", { method: "DELETE" })).status).toBe(401);
    expect((await app.request("/api/characters/1/hall", { method: "PUT", body: "{}" })).status).toBe(401);
    expect((await app.request("/api/shared/not%20a%20token")).status).toBe(404);
    expect((await app.request("/api/hall/abc")).status).toBe(404);
  });
  test("a write from another site is refused", async () => {
    const res = await app.request("/api/auth/logout", { method: "POST", headers: { origin: "https://evil.example" } });
    expect(res.status).toBe(403);
  });
});
