import { describe, expect, test } from "bun:test";
import { join } from "node:path";

// The db scripts, run for real with the environment under the test's control:
// no .env.local (--no-env-file), no PG* variables, and only two kinds of url,
// both safe. A name under .invalid never resolves, and the guard exits before
// any connection anyway; 127.0.0.1:1 is a closed port, so a script the guard
// lets through fails to connect and touches nothing.

const apiDir = join(import.meta.dir, "../..");
const rootDir = join(apiDir, "../..");
const OFF = "postgres://tester:s3cretpw@db.example.invalid:5432/x";
const LOCAL = "postgres://tester:s3cretpw@127.0.0.1:1/x";
const GUID = "Player-6113-0B4A2201";

type Urls = { DATABASE_URL: string; DATABASE_URL_UNPOOLED: string; MIGRATE_URL: string };
const all = (url: string): Urls => ({ DATABASE_URL: url, DATABASE_URL_UNPOOLED: url, MIGRATE_URL: url });

async function run(script: "migrate" | "seed" | "release", args: string[], urls: Urls) {
  const proc = Bun.spawn([process.execPath, "--no-env-file", "run", `src/db/${script}.ts`, ...args], {
    cwd: apiDir,
    env: { PATH: process.env.PATH ?? "", HOME: process.env.HOME ?? "", ...urls },
    stdout: "pipe",
    stderr: "pipe",
  });
  const [stdout, stderr, code] = await Promise.all([new Response(proc.stdout).text(), new Response(proc.stderr).text(), proc.exited]);
  return { stdout, stderr, code, out: stdout + stderr };
}

const scripts = [
  ["migrate", []],
  ["seed", []],
  ["release", [GUID]],
] as const;

describe("the db scripts refuse a database off this machine", () => {
  for (const [script, args] of scripts) {
    test(`${script}: refused before it connects, naming the host and not the password`, async () => {
      const r = await run(script, [...args], all(OFF));
      expect(r.code).toBe(1);
      expect(r.stderr).toContain("refusing");
      expect(r.stderr).toContain("db.example.invalid:5432");
      expect(r.stdout).toBe("");
      expect(r.out).not.toContain("s3cretpw");
    }, 20_000);
  }

  test("seed has no --prod: refused with it too", async () => {
    const r = await run("seed", ["--prod"], all(OFF));
    expect(r.code).toBe(1);
    expect(r.stderr).toContain("local only");
  }, 20_000);

  test("release --yes without --prod is refused as well (the destructive form)", async () => {
    const r = await run("release", [GUID, "--yes"], all(OFF));
    expect(r.code).toBe(1);
    expect(r.stderr).toContain("refusing");
  }, 20_000);

  test("migrate follows the url it would really use: a direct Neon url beats a local DATABASE_URL", async () => {
    const r = await run("migrate", [], { DATABASE_URL: LOCAL, DATABASE_URL_UNPOOLED: OFF, MIGRATE_URL: "" });
    expect(r.code).toBe(1);
    expect(r.stderr).toContain("db.example.invalid:5432");
  }, 20_000);
});

describe("the db scripts run as before on this machine", () => {
  for (const [script, args] of scripts) {
    test(`${script}: past the guard, saying where it goes`, async () => {
      const r = await run(script, [...args], all(LOCAL));
      expect(r.stdout).toContain("database: 127.0.0.1:1\n");
      expect(r.out).not.toContain("refusing");
      expect(r.out).not.toContain("not on this machine");
    }, 20_000);
  }

  test("release: --prod is no part of the guid, wherever it stands", async () => {
    const r = await run("release", ["--prod", GUID], all(LOCAL));
    expect(r.stdout).toContain("database: 127.0.0.1:1\n");
    expect(r.out).not.toContain("usage:");
  }, 20_000);

  test("migrate: MIGRATE_URL on this machine wins over a direct Neon url", async () => {
    const r = await run("migrate", [], { DATABASE_URL: OFF, DATABASE_URL_UNPOOLED: OFF, MIGRATE_URL: LOCAL });
    expect(r.stdout).toContain("database: 127.0.0.1:1\n");
    expect(r.out).not.toContain("refusing");
  }, 20_000);
});

describe("nothing skips the guard", () => {
  test("every db:* script of the api that runs a file in src/db calls requireDatabase before its first await", async () => {
    const pkg = (await Bun.file(join(apiDir, "package.json")).json()) as { scripts: Record<string, string> };
    const files = Object.entries(pkg.scripts)
      .filter(([name]) => name.startsWith("db:"))
      .map(([name, cmd]) => [name, cmd.match(/src\/db\/(\w+)\.ts/)?.[1]] as const)
      .filter((x): x is readonly [string, string] => !!x[1]);
    expect(files.map(([, f]) => f).sort()).toEqual(["migrate", "release", "seed"]);
    for (const [name, file] of files) {
      const source = await Bun.file(join(apiDir, "src/db", `${file}.ts`)).text();
      const call = source.indexOf("requireDatabase(");
      expect(call, `${name} (src/db/${file}.ts) calls requireDatabase`).toBeGreaterThan(-1);
      // Every query in these scripts is behind an await: the guard comes first.
      const firstAwait = source.indexOf("await ");
      expect(firstAwait, `${name} awaits something`).toBeGreaterThan(-1);
      expect(call, `${name} guards before its first await`).toBeLessThan(firstAwait);
    }
  });

  test("the production deploy's migration asks for production with --prod, and is the only migration the build runs", async () => {
    const build = await Bun.file(join(rootDir, "scripts/vercel-build.sh")).text();
    const lines = build.split("\n").filter((l) => /migrate/.test(l) && !l.trim().startsWith("#"));
    expect(lines).toHaveLength(1);
    expect(lines[0]).toContain("--prod");
  });
});
