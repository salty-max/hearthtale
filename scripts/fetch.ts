// A download that tries again when the server stumbles (a 5xx, wago.tools'
// Cloudflare 520, a dropped connection): three more times, 10, 30 and 60
// seconds apart. A 4xx is an answer, given back as it is.
const WAITS = [10, 30, 60];

export async function fetchRetry(url: string, init?: RequestInit): Promise<Response> {
  for (let attempt = 0; ; attempt++) {
    try {
      const res = await fetch(url, init);
      if (res.status < 500 || attempt >= WAITS.length) return res;
      console.warn(`${url}: ${res.status}, again in ${WAITS[attempt]} s`);
    } catch (e) {
      if (attempt >= WAITS.length) throw e;
      console.warn(`${url}: ${(e as Error).message}, again in ${WAITS[attempt]} s`);
    }
    await new Promise((r) => setTimeout(r, WAITS[attempt] * 1000));
  }
}
