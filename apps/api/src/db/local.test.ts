import { describe, expect, test } from "bun:test";
import postgres from "postgres";
import { checkDatabase, databaseUrl, isLocal, migrationUrl, pooled, PRODUCTION_FLAG, whereIs } from "@/db/local";

describe("db", () => {
  test("a transaction pooler is recognised (no prepared statements through it)", () => {
    expect(pooled("postgresql://u:p@ep-cool-name-123456-pooler.eu-central-1.aws.neon.tech/neondb?sslmode=require")).toBe(true);
    expect(pooled("postgresql://u:p@ep-cool-name-123456.eu-central-1.aws.neon.tech/neondb?sslmode=require")).toBe(false);
    expect(pooled("postgres://u:p@aws-0-eu-west-1.pooler.supabase.com:6543/postgres")).toBe(true);
    expect(pooled("postgres://hearthtale:hearthtale@localhost:5435/hearthtale")).toBe(false);
  });

  test("the urls the scripts use: the local container by default, migrate's own precedence", () => {
    expect(databaseUrl({})).toBe("postgres://hearthtale:hearthtale@localhost:5435/hearthtale");
    expect(databaseUrl({ DATABASE_URL: "postgres://a@h/d" })).toBe("postgres://a@h/d");
    expect(migrationUrl({})).toBe(databaseUrl({}));
    expect(migrationUrl({ DATABASE_URL: "postgres://pooled@h/d" })).toBe("postgres://pooled@h/d");
    expect(migrationUrl({ DATABASE_URL: "postgres://pooled@h/d", DATABASE_URL_UNPOOLED: "postgres://direct@h/d" })).toBe("postgres://direct@h/d");
    expect(migrationUrl({ DATABASE_URL_UNPOOLED: "postgres://direct@h/d", MIGRATE_URL: "postgres://migrate@h/d" })).toBe("postgres://migrate@h/d");
    expect(migrationUrl({ MIGRATE_URL: "" })).toBe(databaseUrl({}));
  });
});

// What the guard judges is the client postgres.js builds from the url (its
// options.host, a list), not a parse of the url here: the two disagree (an
// encoded comma, a host list, PGHOST), and a driver update that reads more of
// the url stays covered.
function client(url: string, pghost?: string) {
  const had = process.env.PGHOST;
  if (pghost === undefined) delete process.env.PGHOST;
  else process.env.PGHOST = pghost;
  try {
    return postgres(url, { max: 1 }); // lazy: nothing connects until a query
  } finally {
    if (had === undefined) delete process.env.PGHOST;
    else process.env.PGHOST = had;
  }
}

describe("the guard: which databases are on this machine", () => {
  const local = [
    "postgres://hearthtale:hearthtale@localhost:5435/hearthtale",
    "postgres://u:p@127.0.0.1/db",
    "postgres://u:p@127.0.0.1:5436/db",
    "postgres://u:p@localhost:5435,127.0.0.1:5436/db",
    "postgres:///db", // no host, no PGHOST: the driver's own localhost
  ];
  for (const url of local) {
    test(`local: ${url}`, () => {
      expect(isLocal(client(url).options)).toBe(true);
    });
  }

  const elsewhere: [string, string, string?][] = [
    ["Neon pooled", "postgresql://u:p@ep-cool-name-123456-pooler.eu-central-1.aws.neon.tech/neondb?sslmode=require"],
    ["Neon direct", "postgresql://u:p@ep-cool-name-123456.eu-central-1.aws.neon.tech/neondb?sslmode=require"],
    ["localhost as a label of another domain", "postgres://u:p@localhost.neon.tech/db"],
    ["127.0.0.1 as a label of another domain", "postgres://u:p@127.0.0.1.evil.example/db"],
    ["a name that only looks like loopback", "postgres://u:p@127.0.0.1.nip.io/db"],
    ["*.localhost is not trusted either", "postgres://u:p@a.localhost/db"],
    ["an encoded comma: the driver dials the first host", "postgres://u:p@evil.example%2Ca.localhost/db"],
    ["a local host listed first, another after it", "postgres://u:p@localhost:5435,evil.example:5432/db"],
    ["the other way round", "postgres://u:p@evil.example,localhost/db"],
    ["no host in the url: PGHOST fills it in", "postgres:///db", "evil.example"],
  ];
  for (const [name, url, pghost] of elsewhere) {
    test(`not local: ${name}`, () => {
      expect(isLocal(client(url, pghost).options)).toBe(false);
    });
  }

  test("a url the driver cannot read stops the script before any connection", () => {
    expect(() => client("this is not a url")).toThrow();
  });

  test("a unix socket is local, whatever host it carries", () => {
    expect(isLocal({ host: ["/var/run/postgresql"], port: [5432], path: "/var/run/postgresql/.s.PGSQL.5432" })).toBe(true);
    expect(whereIs({ host: ["/var/run/postgresql"], port: [5432], path: "/var/run/postgresql/.s.PGSQL.5432" })).toBe("socket /var/run/postgresql/.s.PGSQL.5432");
  });

  test("where a client goes, as the scripts print it", () => {
    expect(whereIs(client("postgres://u:p@localhost:5435/db").options)).toBe("localhost:5435");
    expect(whereIs(client("postgres://u:p@ep-x.eu.aws.neon.tech/db").options)).toBe("ep-x.eu.aws.neon.tech:5432");
    expect(whereIs(client("postgres://u:p@a:1,b:2/db").options)).toBe("a:1,b:2");
  });
});

describe("the guard: the verdict", () => {
  const neon = client("postgresql://neonuser:s3cretpw@ep-cool-name-123456.eu-central-1.aws.neon.tech/neondb?sslmode=require").options;
  const here = client("postgres://hearthtale:hearthtale@localhost:5435/hearthtale").options;

  test("a local database runs with no flag, and says where", () => {
    expect(checkDatabase(here, [])).toEqual({ ok: true, where: "localhost:5435", production: false });
    expect(checkDatabase(here, [PRODUCTION_FLAG])).toMatchObject({ ok: true, production: false });
  });

  test("a database off this machine is refused without the flag, naming the host and never the credentials", () => {
    const v = checkDatabase(neon, ["Player-6113-0B4A2201", "--yes"]);
    expect(v.ok).toBe(false);
    if (v.ok) return;
    expect(v.message).toContain("ep-cool-name-123456.eu-central-1.aws.neon.tech:5432");
    expect(v.message).toContain("refusing");
    expect(v.message).toContain(PRODUCTION_FLAG);
    expect(v.message).not.toContain("s3cretpw");
    expect(v.message).not.toContain("neonuser");
  });

  test("--prod lets it through, marked as not local", () => {
    const v = checkDatabase(neon, ["--yes", PRODUCTION_FLAG]);
    expect(v).toMatchObject({ ok: true, production: true });
  });

  test("a caller can say how to ask where --prod does not apply (the dev server)", () => {
    const v = checkDatabase(neon, [], true, "Run the api alone with --prod.");
    expect(v.ok).toBe(false);
    if (v.ok) return;
    expect(v.message).toContain("Run the api alone with --prod.");
    expect(v.message).not.toContain("add --prod to the command");
  });

  test("a script that takes no --prod (the seed) refuses even with it, and does not offer it", () => {
    const v = checkDatabase(neon, [PRODUCTION_FLAG], false);
    expect(v.ok).toBe(false);
    if (v.ok) return;
    expect(v.message).toContain("local only");
    expect(v.message).not.toContain("add --prod");
  });
});
