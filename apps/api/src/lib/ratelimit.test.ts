import { afterEach, describe, expect, test } from "bun:test";
import { Hono } from "hono";
import { callerOf, clientIp, limit, memoryCounter, setCounter, windowOf } from "@/lib/ratelimit";

const app = (max: number) => {
  const a = new Hono();
  a.get("/x", limit("x", max, 60_000), (c) => c.text("ok"));
  return a;
};
const from = (ip: string) => ({ headers: { "x-real-ip": ip } });

afterEach(() => setCounter(null));

describe("rate limit", () => {
  test("past its max in a window, a caller waits (429 and Retry-After)", async () => {
    setCounter(memoryCounter());
    const a = app(2);
    expect((await a.request("/x", from("1.2.3.4"))).status).toBe(200);
    expect((await a.request("/x", from("1.2.3.4"))).status).toBe(200);
    const res = await a.request("/x", from("1.2.3.4"));
    expect(res.status).toBe(429);
    expect(Number(res.headers.get("retry-after"))).toBeGreaterThan(0);
  });
  test("each caller counts apart", async () => {
    setCounter(memoryCounter());
    const a = app(1);
    expect((await a.request("/x", from("1.2.3.4"))).status).toBe(200);
    expect((await a.request("/x", from("5.6.7.8"))).status).toBe(200);
    expect((await a.request("/x", from("1.2.3.4"))).status).toBe(429);
  });
  test("a new window starts afresh", () => {
    expect(windowOf(60_000, 0)).toEqual({ index: 0, endsAt: 60_000 });
    expect(windowOf(60_000, 59_999).index).toBe(0);
    expect(windowOf(60_000, 60_000)).toEqual({ index: 1, endsAt: 120_000 });
  });
  test("a counter that fails lets the request through (never blocks a sign-in)", async () => {
    setCounter({ hit: async () => Promise.reject(new Error("db down")) });
    expect((await app(1).request("/x", from("1.2.3.4"))).status).toBe(200);
  });
  test("an IPv6 caller is its /64, an IPv4 one its address", () => {
    expect(callerOf("1.2.3.4")).toBe("1.2.3.4");
    expect(callerOf("2001:db8:aa:bb:1:2:3:4")).toBe("2001:db8:aa:bb::/64");
    expect(callerOf("2001:DB8:AA:BB::9")).toBe("2001:db8:aa:bb::/64");
    expect(callerOf("2001:db8::1")).toBe("2001:db8:0:0::/64");
    expect(callerOf("::1")).toBe("0:0:0:0::/64");
    expect(callerOf("fe80::1%en0")).toBe("fe80:0:0:0::/64");
  });
  test("one /64 counts as one caller", async () => {
    setCounter(memoryCounter());
    const a = app(1);
    expect((await a.request("/x", from("2001:db8:aa:bb::1"))).status).toBe(200);
    expect((await a.request("/x", from("2001:db8:aa:bb::2"))).status).toBe(429);
  });
  test("a route may answer a refusal its own way", async () => {
    setCounter(memoryCounter());
    const a = new Hono();
    a.get("/x", limit("x", 0, 60_000, (c) => c.redirect("/busy")), (c) => c.text("ok"));
    const res = await a.request("/x", from("1.2.3.4"));
    expect(res.status).toBe(302);
    expect(res.headers.get("location")).toBe("/busy");
  });
  test("the caller: Vercel's x-real-ip, else the first x-forwarded-for, else local", () => {
    const h = (o: Record<string, string>) => new Headers(o);
    expect(clientIp(h({ "x-real-ip": "1.2.3.4", "x-forwarded-for": "9.9.9.9" }))).toBe("1.2.3.4");
    expect(clientIp(h({ "x-forwarded-for": "5.6.7.8, 10.0.0.1" }))).toBe("5.6.7.8");
    expect(clientIp(h({}))).toBe("local");
  });
});
