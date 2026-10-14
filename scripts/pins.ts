// The game's data each script reads, pinned in one place (pins.json): the
// clients' builds on wago.tools (Classic Era, Forever) and the community
// databases' commits. .github/workflows/client-tables.yml moves the builds
// when the game moves, in a pull request.
import pins from "./pins.json";

export type Build = { product: string; build: string };
export const CLASSIC: Build = pins.builds.classic;
export const FOREVER: Build = pins.builds.forever;
// a wago.tools table's query for a pinned build
export const wago = (b: Build) => `product=${b.product}&build=${b.build}`;
export const REPOS = pins.repos;
