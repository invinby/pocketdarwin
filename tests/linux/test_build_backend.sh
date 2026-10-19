#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$ROOT/scripts/linux/build-inferno.sh"
LOCK="$ROOT/config/backend.lock.json"

grep -q '"commit": "6541861f4d033a0de327b5ccc5180ebac20bf461"' "$LOCK"
grep -q '"repository": "https://github.com/ChefKissInc/Inferno.git"' "$LOCK"
grep -q '"submodules": \[\]' "$LOCK"
bash "$SCRIPT" --lock "$LOCK" --prefix /tmp/pocketdarwin-test --validate-lock

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
printf '{"repository":"bad","commit":"short"}\n' > "$tmp/bad.json"
if output=$(bash "$SCRIPT" --lock "$tmp/bad.json" --prefix "$tmp/out" --validate-lock 2>&1); then
  echo "malformed lock unexpectedly accepted" >&2
  exit 1
fi
grep -q 'ERROR: BACKEND_LOCK_INVALID' <<< "$output"

mkdir -p "$tmp/bin"
ln -s "$(command -v python3)" "$tmp/bin/python3"
if output=$(PATH="$tmp/bin" /bin/bash "$SCRIPT" --lock "$LOCK" --prefix "$tmp/out" 2>&1); then
  echo "missing build tools unexpectedly accepted" >&2
  exit 1
fi
grep -q 'ERROR: TOOL_MISSING: curl' <<< "$output"

echo "build backend tests passed"
