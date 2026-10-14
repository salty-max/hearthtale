import { describe, expect, test } from "bun:test";
import { app } from "@/app";
import { flatten } from "@/lib/observations";

describe("observations", () => {
  test("an addon's collect table, flattened into checked facts", () => {
    const facts = flatten({
      game: "forever",
      facts: {
        enUS: {
          quest: { "92551": { title: "Stolen Supplies", details: "Hey $N, the supplies.", giver: "npc:252172", map: 2442, x: 46.1, y: 25, b: "70374" } },
          npc: { "252172": { name: "Danarii Bellowveil", level: [10, 10], rank: "normal", type: "Humanoid", reaction: 5, map: 2442 } },
          say: { "448": { "$N! Fresh meat!": "yell" } },
          gossip: { "448": { "Grr.": true } },
          loot: { "npc:299": { looted: 3, items: { "750": 2 } } },
        },
      },
    });
    const has = (kind: string, entity: string, field: string, value: string) =>
      facts!.some((f) => f.kind === kind && f.entity === entity && f.field === field && f.value === value);
    expect(has("quest", "92551", "details", "Hey $N, the supplies.")).toBe(true);
    expect(has("quest", "92551", "giver", "npc:252172")).toBe(true);
    expect(has("quest", "92551", "where", "[2442,46.1,25]")).toBe(true);
    expect(facts!.find((f) => f.field === "details")!.build).toBe("70374");
    expect(has("npc", "252172", "level", "[10,10]")).toBe(true);
    expect(has("npc", "252172", "reaction", "5")).toBe(true);
    expect(has("say", "448", "yell", "$N! Fresh meat!")).toBe(true);
    expect(has("gossip", "448", "text", "Grr.")).toBe(true);
    expect(has("loot", "npc:299", "item", "750")).toBe(true);
  });
  test("anything else is left out", () => {
    expect(flatten(null)).toBeNull();
    expect(flatten({ game: "retail", facts: {} })).toBeNull();
    const facts = flatten({
      game: "classic",
      facts: {
        xxXX: { quest: { "1": { title: "lost" } } },
        enUS: {
          quest: { abc: { title: "no id" }, "2": { title: "x".repeat(5000), giver: "player:1" } },
          npc: { "3": { level: [5, 2], rank: "r".repeat(100), reaction: 99 } },
          say: { "4": { "a line": "shout" } },
          loot: { "item:5": { items: { "6": 1 } }, "npc:7": { items: { six: 1 } } },
        },
      },
    });
    expect(facts).toEqual([]);
  });
  test("the routes: a contributor needed, the export behind its token", async () => {
    const post = (headers: Record<string, string>, body: unknown) =>
      app.request("/api/observations", { method: "POST", headers, body: JSON.stringify(body) });
    expect((await post({}, { game: "classic", facts: {} })).status).toBe(400);
    expect((await post({ "x-contributor": "a1b2c3d4e5f6a7b8" }, { game: "nope" })).status).toBe(400);
    expect((await app.request("/api/observations/export?game=classic")).status).toBe(401);
    process.env.OBSERVATIONS_TOKEN = "t0ken";
    try {
      expect((await app.request("/api/observations/export?game=classic", { headers: { authorization: "Bearer nope" } })).status).toBe(401);
      expect((await app.request("/api/observations/export?game=mars", { headers: { authorization: "Bearer t0ken" } })).status).toBe(400);
    } finally {
      delete process.env.OBSERVATIONS_TOKEN;
    }
  });
});
