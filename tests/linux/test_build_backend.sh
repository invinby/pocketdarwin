#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$ROOT/scripts/linux/build-inferno.sh"
LOCK="$ROOT/config/backend.lock.json"

grep -q '"commit": "cc4302a99167abec69b714cfd00c38caece7e7de"' "$LOCK"
grep -q '"repository": "https://github.com/ChefKissInc/Inferno.git"' "$LOCK"
grep -q '"path":"util/mlib"' "$LOCK"
grep -q '"commit":"d0fd65a8695218ffabf2aa543ce51ca3af69536f"' "$LOCK"
bash "$SCRIPT" --lock "$LOCK" --prefix /tmp/pocketdarwin-test --validate-lock

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
printf '{"repository":"bad","commit":"short"}\n' > "$tmp/bad.json"
if output=$(bash "$SCRIPT" --lock "$tmp/bad.json" --prefix "$tmp/out" --validate-lock 2>&1); then
  echo "malformed lock unexpectedly accepted" >&2
  exit 1
fi
grep -q 'ERROR: BACKEND_LOCK_INVALID' <<< "$output"

echo "build backend tests passed"
