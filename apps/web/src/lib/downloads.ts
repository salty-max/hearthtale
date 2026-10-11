import { useQuery } from "@tanstack/react-query";

/**
 * The downloads: the addon from this repo's latest release (one package for
 * every game), Ravenpost (the companion app, shared with WoWLocker) from its
 * own repo. Their files carry their version in their name
 * (Hearthtale-v0.7.5.zip, ravenpost-v0.2.5-macos.zip; older releases' none),
 * so the newest release is asked of GitHub's API (the visitor's own quota, no
 * key: security-headers.json lets it through) and each button links its file;
 * until GitHub answers, or if it doesn't, the release page.
 */
export const ADDON_REPO = "salty-max/hearthtale";
export const RAVENPOST_REPO = "salty-max/ravenpost";
export const ADDON_RELEASES = `https://github.com/${ADDON_REPO}/releases`;
export const RAVENPOST_RELEASES = `https://github.com/${RAVENPOST_REPO}/releases`;

/** Each download: its repo, its file's name (with its version or without). */
export const FILES = {
  addon: { repo: ADDON_REPO, name: /^Hearthtale(-v[\d.]+)?\.zip$/ },
  macos: { repo: RAVENPOST_REPO, name: /^ravenpost(-v[\d.]+)?-macos\.zip$/ },
  windows: { repo: RAVENPOST_REPO, name: /^ravenpost(-v[\d.]+)?-windows-x64\.exe$/ },
  windowsArm: { repo: RAVENPOST_REPO, name: /^ravenpost(-v[\d.]+)?-windows-arm64\.exe$/ },
} as const;
export type Download = keyof typeof FILES;

export interface Release {
  tag: string;
  assets: { name: string; url: string }[];
}

/** A repo's newest release, by GitHub's API. */
export async function latestRelease(repo: string): Promise<Release> {
  const res = await fetch(`https://api.github.com/repos/${repo}/releases/latest`, {
    headers: { Accept: "application/vnd.github+json" },
  });
  if (!res.ok) throw new Error(`GitHub: ${res.status}`);
  const body = (await res.json()) as { tag_name: string; assets: { name: string; browser_download_url: string }[] };
  return { tag: body.tag_name, assets: body.assets.map((a) => ({ name: a.name, url: a.browser_download_url })) };
}

/** A download's link in a release: its file, else the release page. */
export function linkIn(which: Download, release: Release | undefined): string {
  const file = FILES[which];
  return release?.assets.find((a) => file.name.test(a.name))?.url ?? `https://github.com/${file.repo}/releases/latest`;
}

/** A download's link and its release's version (once GitHub has answered). */
export function useDownload(which: Download): { href: string; version?: string } {
  const repo = FILES[which].repo;
  const { data } = useQuery({
    queryKey: ["latest-release", repo],
    queryFn: () => latestRelease(repo),
    staleTime: 10 * 60_000,
    retry: 1,
  });
  return { href: linkIn(which, data), version: data?.tag };
}
