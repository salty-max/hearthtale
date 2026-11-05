/**
 * Hearthtale's tests in the strict test game, all at once (the kit's battery, addon-kit/docs/battery.md):
 *
 *   strict_test.lua  the strict game refuses what the client refuses (a bad call must fail here)
 *   matrix.lua       characters, levels, Hardcore and death, every tab and window, hovered and clicked, per game
 *   matrix.lua secrets  Forever: the calls Blizzard flags as secret answer with secret values, a life is played
 *
 * The sim (addon/test/sim.lua) runs in `addon:ci` beside them, on the same strict game.
 *   bun scripts/battery.ts              all of them
 *   bun scripts/battery.ts matrix       the ones whose name has "matrix" in it
 */
import { type Job, runBattery } from "./battery-lib";

const jobs: Job[] = [];
for (const forever of [false, true]) {
  jobs.push({ name: "strict", forever, args: ["addon/test/strict_test.lua"] });
  jobs.push({ name: "matrix", forever, args: ["addon/test/matrix.lua"] });
}
jobs.push({ name: "matrix secrets", forever: true, args: ["addon/test/matrix.lua", "secrets"] });

await runBattery(jobs);
