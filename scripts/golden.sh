#!/bin/bash
# Everything the writer writes, for a refactor that must not change a word:
#   bash scripts/golden.sh save [journal...]    before (into .cache/golden/before)
#   bash scripts/golden.sh check [journal...]   after: the same, byte for byte, or the differences
# The playthroughs' books (after `bun run audit`), the samples, the seed, the
# voices, the writer tests on both games, and the saved journals given (a
# character's SavedVariables/Hearthtale.lua), read by addon/test/read.lua.
set -e
cd "$(dirname "$0")/.."
mode=${1:-check}
shift || true
out=.cache/golden/$([ "$mode" = save ] && echo before || echo after)
rm -rf "$out"; mkdir -p "$out"
if [ -f .cache/audit/game.lua ]; then
  rm -rf .cache/audit/books
  luajit addon/test/playthrough.lua > "$out/playthrough.txt" 2>&1 || true
  cp -r .cache/audit/books "$out/books"
else
  echo "no playthroughs: run bun run audit first" >&2
fi
luajit addon/test/sample.lua > "$out/sample.md"
luajit addon/test/sample.lua deadmines > "$out/sample-deadmines.md"
luajit addon/test/seed.lua > "$out/seed.json"
FOREVER=1 luajit addon/test/voices.lua compare > "$out/compare.md"
FOREVER=1 luajit addon/test/voices.lua moments > "$out/moments.md"
luajit addon/test/writer.lua > "$out/writer.txt" 2>&1 || true
FOREVER=1 luajit addon/test/writer.lua > "$out/writer-forever.txt" 2>&1 || true
n=0
for j in "$@"; do
  n=$((n + 1))
  luajit addon/test/read.lua "$j" > "$out/journal-$n.md"
done
[ "$mode" = save ] && { echo "saved: $out"; exit 0; }
[ -d .cache/golden/before ] || { echo "nothing saved: run with save first" >&2; exit 1; }
if diff -r .cache/golden/before "$out" > .cache/golden/diff.txt; then
  echo "identical"
else
  echo "differs: .cache/golden/diff.txt ($(grep -c '^[<>]' .cache/golden/diff.txt) lines)"
  exit 1
fi
