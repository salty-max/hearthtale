#!/bin/bash
# Commands at once (the tests of both games side by side), each one's output
# kept apart and printed in the order given; fails if any of them failed.
#   bash scripts/parallel.sh "luajit addon/test/writer.lua" "FOREVER=1 luajit addon/test/writer.lua"
set -u
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
cmds=("$@")
pids=()
for cmd in "${cmds[@]}"; do
  bash -c "$cmd" > "$dir/${#pids[@]}.out" 2>&1 &
  pids+=($!)
done
status=0
for i in "${!pids[@]}"; do
  if ! wait "${pids[$i]}"; then
    status=1
    echo "✗ failed: ${cmds[$i]}" >&2
  fi
  cat "$dir/$i.out"
done
exit $status
