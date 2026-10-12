import { describe, expect, test } from "bun:test";
import { hearthtaleRecord, LuaError, parseSavedVariables } from "@/lib/luasv";

// Ravenpost's luasv_test.go, the same cases.
describe("saved variables", () => {
  test("the client's layout", () => {
    const vars = parseSavedVariables(`
HearthtaleChar = {
["name"] = "Brannok",
["book"] = {
["chapters"] = {
{
["number"] = 1,
["diary"] = "I set out.\\n\\nThen I rested.",
},
},
["at"] = 1790965309,
},
["hardcore"] = true,
}
`);
    const c = vars.HearthtaleChar as { name: string; book: { at: number; chapters: { diary: string }[] } };
    expect(c.name).toBe("Brannok");
    expect(c.book.chapters[0].diary).toBe("I set out.\n\nThen I rested.");
    expect(c.book.at).toBe(1790965309);
  });
  test("the details of Lua", () => {
    const vars = parseSavedVariables(`-- a comment
A = {
	"positional", -- [1]
	nil,
	[3] = true,
	[2] = false,
}
B = { [23] = 90000, [24] = 95000 } -- level → played: not an array
C = "quote \\" backslash \\\\ newline \\n tab \\t byte \\65 escaped\\
line"
D = [[
long string]]
E = { x = 1, ["y z"] = -2.5e3, 0x1F }
F = {}
--[==[ block
comment ]==]
G = -0.5;
H = "caf\\195\\169"
`);
    expect(vars.A).toEqual(["positional", false, true]);
    expect(vars.B).toEqual({ "23": 90000, "24": 95000 });
    expect(vars.C).toBe('quote " backslash \\ newline \n tab \t byte A escaped\nline');
    expect(vars.D).toBe("long string");
    expect(vars.E).toEqual({ x: 1, "y z": -2500, "1": 31 });
    expect(vars.F).toEqual([]);
    expect(vars.G).toBe(-0.5);
    expect(vars.H).toBe("café");
  });
  test("never code", () => {
    for (const src of ['A = os.execute("rm -rf /")', "A = { [print] = 1 }", 'A = { "unterminated }', `A = ${"{".repeat(70)}`, "A = 1 B"]) {
      expect(() => parseSavedVariables(src)).toThrow(LuaError);
    }
  });
  test("a character's record, cut to what the site reads", () => {
    const rec = hearthtaleRecord('HearthtaleChar = { ["name"] = "Pippa", ["guid"] = "Player-1-0A", ["moments"] = { 1, 2 }, ["closed"] = true }');
    expect(rec).toEqual({ name: "Pippa", guid: "Player-1-0A", closed: true });
    expect(hearthtaleRecord("HearthtaleHall = {}")).toBeNull();
  });
});
