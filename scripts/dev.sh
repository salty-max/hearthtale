#!/usr/bin/env bash
#
# Dev entrypoint: runs the turbo dev servers (api :3002 + web :5175).
#
#   bun run dev

set -uo pipefail

exec turbo run dev
