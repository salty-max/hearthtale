/**
 * A ZIP archive, its files stored as they are (no compression: an EPUB's text
 * is small, and its first file must be stored anyway), with no dependency.
 */
const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c >>> 0;
  }
  return table;
})();

export function crc32(data: Uint8Array): number {
  let c = 0xffffffff;
  for (const b of data) c = CRC_TABLE[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

export type ZipEntry = { name: string; data: Uint8Array | string };

export function zip(entries: ZipEntry[]): Uint8Array {
  const enc = new TextEncoder();
  const files = entries.map((e) => {
    const name = enc.encode(e.name);
    const data = typeof e.data === "string" ? enc.encode(e.data) : e.data;
    return { name, data, crc: crc32(data) };
  });
  const local = files.reduce((n, f) => n + 30 + f.name.length + f.data.length, 0);
  const central = files.reduce((n, f) => n + 46 + f.name.length, 0);
  const out = new Uint8Array(local + central + 22);
  const view = new DataView(out.buffer);
  let at = 0;
  const offsets: number[] = [];
  // (the DOS date of 1 January 2026, midnight: the files' time is no secret)
  const time = 0,
    date = ((2026 - 1980) << 9) | (1 << 5) | 1;
  for (const f of files) {
    offsets.push(at);
    view.setUint32(at, 0x04034b50, true);
    view.setUint16(at + 4, 20, true);
    view.setUint16(at + 6, 0x0800, true); // UTF-8 names
    view.setUint16(at + 8, 0, true); // stored
    view.setUint16(at + 10, time, true);
    view.setUint16(at + 12, date, true);
    view.setUint32(at + 14, f.crc, true);
    view.setUint32(at + 18, f.data.length, true);
    view.setUint32(at + 22, f.data.length, true);
    view.setUint16(at + 26, f.name.length, true);
    view.setUint16(at + 28, 0, true);
    out.set(f.name, at + 30);
    out.set(f.data, at + 30 + f.name.length);
    at += 30 + f.name.length + f.data.length;
  }
  const centralAt = at;
  files.forEach((f, i) => {
    view.setUint32(at, 0x02014b50, true);
    view.setUint16(at + 4, 20, true);
    view.setUint16(at + 6, 20, true);
    view.setUint16(at + 8, 0x0800, true);
    view.setUint16(at + 10, 0, true);
    view.setUint16(at + 12, time, true);
    view.setUint16(at + 14, date, true);
    view.setUint32(at + 16, f.crc, true);
    view.setUint32(at + 20, f.data.length, true);
    view.setUint32(at + 24, f.data.length, true);
    view.setUint16(at + 28, f.name.length, true);
    view.setUint32(at + 42, offsets[i], true);
    out.set(f.name, at + 46);
    at += 46 + f.name.length;
  });
  view.setUint32(at, 0x06054b50, true);
  view.setUint16(at + 8, files.length, true);
  view.setUint16(at + 10, files.length, true);
  view.setUint32(at + 12, at - centralAt, true);
  view.setUint32(at + 16, centralAt, true);
  return out;
}
