#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/.."
exec docker compose --env-file .env -f compose.yaml "$@"