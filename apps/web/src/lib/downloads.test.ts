import { describe, expect, test } from "bun:test";
import { linkIn, osOf, type Release } from "./downloads";

const url = (name: string) => `https://github.com/x/releases/download/v1/${name}`;
const release = (...names: string[]): Release => ({ tag: "v1", assets: names.map((name) => ({ name, url: url(name) })) });

describe("a download's link", () => {
  test("its file, its version in its name", () => {
    const r = release("Hearthtale-v0.7.5.zip", "release.json");
    expect(linkIn("addon", r)).toBe(url("Hearthtale-v0.7.5.zip"));
  });
  test("its file, an older release's fixed name", () => {
    expect(linkIn("addon", release("Hearthtale.zip"))).toBe(url("Hearthtale.zip"));
  });
  test("Ravenpost's, each platform its own", () => {
    const r = release("ravenpost-v0.2.5-macos.zip", "ravenpost-v0.2.5-windows-x64.exe", "ravenpost-v0.2.5-windows-arm64.exe");
    expect(linkIn("macos", r)).toBe(url("ravenpost-v0.2.5-macos.zip"));
    expect(linkIn("windows", r)).toBe(url("ravenpost-v0.2.5-windows-x64.exe"));
    expect(linkIn("windowsArm", r)).toBe(url("ravenpost-v0.2.5-windows-arm64.exe"));
  });
  test("the release page, until GitHub answers or when the file isn't there", () => {
    expect(linkIn("addon", undefined)).toBe("https://github.com/salty-max/hearthtale/releases/latest");
    expect(linkIn("macos", release("other.zip"))).toBe("https://github.com/salty-max/ravenpost/releases/latest");
  });
});

describe("the visitor's computer", () => {
  test("from the browser's own words", () => {
    expect(osOf("Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) AppleWebKit/605.1.15")).toBe("macos");
    expect(osOf("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")).toBe("windows");
    expect(osOf("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)")).toBeUndefined();
    expect(osOf("Mozilla/5.0 (X11; Linux x86_64)")).toBeUndefined();
  });
});
