import { describe, expect, test } from "bun:test";
import { createPrivateKey, sign } from "node:crypto";
import { readPassport } from "@/lib/ravenpost";

// Ravenpost's inbox's key for this computer only (its src/devkey.ts): a local
// Hearthtale trusts it, one on Vercel never does. Not a secret.
const DEV_PRIVATE_KEY = `-----BEGIN PRIVATE KEY-----
MC4CAQAwBQYDK2VwBCIEIJc2UrbgSbp2VWnn15lHLOc6mKdv8VIfYY25+kN1dS98
-----END PRIVATE KEY-----`;

const passport = (p: Record<string, unknown>, key = DEV_PRIVATE_KEY) => {
  const body = Buffer.from(JSON.stringify(p)).toString("base64url");
  return `${body}.${sign(null, Buffer.from(body), createPrivateKey(key)).toString("base64url")}`;
};
const now = () => Math.floor(Date.now() / 1000);
const fresh = { aud: "sites", bnetId: 4242, battletag: "Namzar#21586", owned: [{ region: "eu", ids: [11, 12] }], iat: now(), exp: now() + 600, jti: "abc" };

describe("ravenpost's passport", () => {
  test("one the inbox signed: the account and its characters", () => {
    expect(readPassport(passport(fresh))).toMatchObject({ bnetId: 4242, owned: [{ region: "eu", ids: [11, 12] }] });
  });
  test("refused: forged, changed, stale, for someone else, or a dev key on Vercel", () => {
    const [body, sig] = passport(fresh).split(".");
    const changed = Buffer.from(JSON.stringify({ ...fresh, bnetId: 1 })).toString("base64url");
    expect(readPassport(`${changed}.${sig}`)).toBeNull();
    expect(readPassport(body)).toBeNull();
    expect(readPassport("garbage")).toBeNull();
    expect(readPassport(42)).toBeNull();
    expect(readPassport(passport({ ...fresh, exp: now() - 1 }))).toBeNull();
    expect(readPassport(passport({ ...fresh, aud: "elsewhere" }))).toBeNull();
    process.env.VERCEL = "1";
    try {
      expect(readPassport(passport(fresh))).toBeNull();
    } finally {
      delete process.env.VERCEL;
    }
  });
});
