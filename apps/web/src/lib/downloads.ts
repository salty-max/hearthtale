/**
 * The downloads: the addon from this repo's latest release (one package per
 * game), Ravenpost (the companion app, shared with WoWLocker) from its own repo.
 * `releases/latest/download/<file>` always points at the newest one.
 */
export const ADDON_RELEASES = "https://github.com/salty-max/hearthtale/releases";
export const RAVENPOST_RELEASES = "https://github.com/salty-max/ravenpost/releases";

export const FILES = {
  classic: `${ADDON_RELEASES}/latest/download/Hearthtale-classic.zip`,
  forever: `${ADDON_RELEASES}/latest/download/Hearthtale-forever.zip`,
  macos: `${RAVENPOST_RELEASES}/latest/download/ravenpost-macos.zip`,
  windows: `${RAVENPOST_RELEASES}/latest/download/ravenpost-windows-x64.exe`,
  windowsArm: `${RAVENPOST_RELEASES}/latest/download/ravenpost-windows-arm64.exe`,
} as const;
