import { afterEach, describe, expect, it } from "bun:test";
import { encryptPayload, isPushEndpoint, sendPush } from "./webpush";

const enc = new TextEncoder();
const te = (s: string): Uint8Array<ArrayBuffer> => new Uint8Array(enc.encode(s));
const b64url = (u: Uint8Array): string => Buffer.from(u).toString("base64url");
function concat(...a: Uint8Array[]): Uint8Array<ArrayBuffer> {
  const o = new Uint8Array(a.reduce((n, x) => n + x.length, 0));
  let p = 0;
  for (const x of a) {
    o.set(x, p);
    p += x.length;
  }
  return o;
}

// Independent receiver-side decrypt per RFC 8291/8188 — what a browser does.
async function decrypt(
  uaPriv: CryptoKey,
  body: Uint8Array<ArrayBuffer>,
  uaPub: Uint8Array<ArrayBuffer>,
  auth: Uint8Array<ArrayBuffer>,
): Promise<string> {
  const salt = body.slice(0, 16);
  const idlen = body[20];
  const asPub = body.slice(21, 21 + idlen);
  const ciphertext = body.slice(21 + idlen);

  const asKey = await crypto.subtle.importKey("raw", asPub, { name: "ECDH", namedCurve: "P-256" }, false, []);
  const ecdh = new Uint8Array(await crypto.subtle.deriveBits({ name: "ECDH", public: asKey }, uaPriv, 256));
  const ecdhKey = await crypto.subtle.importKey("raw", ecdh, "HKDF", false, ["deriveBits"]);
  const ikm = new Uint8Array(
    await crypto.subtle.deriveBits(
      {
        name: "HKDF",
        hash: "SHA-256",
        salt: auth,
        info: concat(te("WebPush: info"), Uint8Array.of(0), uaPub, asPub),
      },
      ecdhKey,
      256,
    ),
  );
  const ikmKey = await crypto.subtle.importKey("raw", ikm, "HKDF", false, ["deriveBits"]);
  const cekBits = await crypto.subtle.deriveBits(
    { name: "HKDF", hash: "SHA-256", salt, info: concat(te("Content-Encoding: aes128gcm"), Uint8Array.of(0)) },
    ikmKey,
    128,
  );
  const nonce = new Uint8Array(
    await crypto.subtle.deriveBits(
      { name: "HKDF", hash: "SHA-256", salt, info: concat(te("Content-Encoding: nonce"), Uint8Array.of(0)) },
      ikmKey,
      96,
    ),
  );
  const cek = await crypto.subtle.importKey("raw", cekBits, { name: "AES-GCM" }, false, ["decrypt"]);
  const dec = new Uint8Array(await crypto.subtle.decrypt({ name: "AES-GCM", iv: nonce }, cek, ciphertext));
  return new TextDecoder().decode(dec.slice(0, dec.length - 1)); // strip the 0x02 delimiter
}

describe("webpush aes128gcm", () => {
  it("encrypts a payload the receiver can decrypt (RFC 8291 round-trip)", async () => {
    const client = await crypto.subtle.generateKey({ name: "ECDH", namedCurve: "P-256" }, true, [
      "deriveBits",
    ]);
    const uaPub = new Uint8Array(await crypto.subtle.exportKey("raw", client.publicKey));
    const auth = crypto.getRandomValues(new Uint8Array(16));
    const sub = { endpoint: "https://push.example/x", keys: { p256dh: b64url(uaPub), auth: b64url(auth) } };

    const msg = JSON.stringify({ title: "⚽ BUT — France 1-0 Angleterre", body: "Mbappé 23'", matchId: 399 });
    const body = await encryptPayload(sub, te(msg));

    expect(await decrypt(client.privateKey, body, uaPub, auth)).toBe(msg);
  });
});

describe("webpush endpoints", () => {
  it("only the browsers' push services", () => {
    for (const ok of [
      "https://fcm.googleapis.com/fcm/send/abc",
      "https://web.push.apple.com/QAbc",
      "https://updates.push.services.mozilla.com/wpush/v2/abc",
      "https://wns2-par02p.notify.windows.com/w/?token=abc",
    ])
      expect(isPushEndpoint(ok)).toBe(true);
    for (const bad of [
      "http://fcm.googleapis.com/fcm/send/abc",
      "https://169.254.169.254/latest/meta-data",
      "https://127.0.0.1/x",
      "https://[::1]/x",
      "https://localhost/x",
      "https://fcm.googleapis.com.evil.example/x",
      "https://evilfcm.googleapis.com/x",
      "https://user:pw@fcm.googleapis.com/x",
      "https://fcm.googleapis.com:8443/x",
      "https://push.example/x",
      "https://fcm.googleapis.com./x",
      "https://evil.example\\@fcm.googleapis.com/x",
      "not a url",
    ])
      expect(isPushEndpoint(bad)).toBe(false);
  });

  const realFetch = globalThis.fetch;
  afterEach(() => {
    globalThis.fetch = realFetch;
  });
  const keys = async () => {
    const client = await crypto.subtle.generateKey({ name: "ECDH", namedCurve: "P-256" }, true, ["deriveBits"]);
    const uaPub = new Uint8Array(await crypto.subtle.exportKey("raw", client.publicKey));
    return { p256dh: b64url(uaPub), auth: b64url(crypto.getRandomValues(new Uint8Array(16))) };
  };
  const vapid = async () => {
    const k = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign"]);
    const jwk = await crypto.subtle.exportKey("jwk", k.privateKey);
    const pub = new Uint8Array(await crypto.subtle.exportKey("raw", k.publicKey));
    return { publicKey: b64url(pub), privateKey: jwk.d!, subject: "mailto:test@example.com" };
  };

  it("a stored endpoint elsewhere is never fetched, and is dropped", async () => {
    let fetched = false;
    globalThis.fetch = (async () => {
      fetched = true;
      return new Response(null, { status: 201 });
    }) as unknown as typeof fetch;
    const res = await sendPush({ endpoint: "https://169.254.169.254/x", keys: await keys() }, {}, await vapid());
    expect(fetched).toBe(false);
    expect(res).toEqual({ ok: false, status: 0, gone: true });
  });

  it("a push service that hangs is given up on, and no redirect is followed", async () => {
    let init: RequestInit | undefined;
    globalThis.fetch = ((_url: string, i: RequestInit) => {
      init = i;
      return new Promise((_, reject) => i.signal!.addEventListener("abort", () => reject(i.signal!.reason)));
    }) as unknown as typeof fetch;
    const started = Date.now();
    const sent = sendPush({ endpoint: "https://fcm.googleapis.com/fcm/send/abc", keys: await keys() }, {}, await vapid(), { timeoutMs: 50 });
    await expect(sent).rejects.toThrow();
    expect(Date.now() - started).toBeLessThan(2000);
    expect(init?.redirect).toBe("manual");
  });
});
