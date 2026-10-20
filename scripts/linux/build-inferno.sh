#!/usr/bin/env bash
set -euo pipefail

usage() { echo "Usage: bash build-inferno.sh --lock <path> --prefix <path> [--validate-lock]"; }
LOCK=""
PREFIX=""
VALIDATE_ONLY=false
while (($#)); do
  case "$1" in
    --lock) LOCK="${2:?missing lock path}"; shift 2 ;;
    --prefix) PREFIX="${2:?missing install prefix}"; shift 2 ;;
    --validate-lock) VALIDATE_ONLY=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done
[[ -n "$LOCK" && -n "$PREFIX" ]] || { usage >&2; exit 2; }
[[ -f "$LOCK" ]] || { echo "ERROR: BACKEND_LOCK_NOT_FOUND" >&2; exit 2; }
command -v python3 >/dev/null || { echo "ERROR: TOOL_MISSING: python3" >&2; exit 3; }

FIELDS_OUTPUT=$(python3 - "$LOCK" <<'PY'
import json, re, sys
try:
    data = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception as exc:
    print(f"ERROR: BACKEND_LOCK_INVALID: {exc}", file=sys.stderr)
    raise SystemExit(2)
required = ("repository", "commit", "source_url", "project_license", "inferno_code_license")
if any(not isinstance(data.get(k), str) or not data[k] for k in required):
    print("ERROR: BACKEND_LOCK_INVALID: required string field missing", file=sys.stderr)
    raise SystemExit(2)
if not re.fullmatch(r"[0-9a-f]{40}", data["commit"]):
    print("ERROR: BACKEND_LOCK_INVALID: commit must be a full 40-character SHA", file=sys.stderr)
    raise SystemExit(2)
if data["repository"] != "https://github.com/ChefKissInc/Inferno.git":
    print("ERROR: BACKEND_LOCK_INVALID: unexpected backend repository", file=sys.stderr)
    raise SystemExit(2)
if not isinstance(data.get("submodules"), list):
    print("ERROR: BACKEND_LOCK_INVALID: submodules must be a list", file=sys.stderr)
    raise SystemExit(2)
seen = set()
for module in data["submodules"]:
    if not isinstance(module, dict):
        print("ERROR: BACKEND_LOCK_INVALID: submodule entry must be an object", file=sys.stderr)
        raise SystemExit(2)
    path, repo, sha, archive = (module.get(k) for k in ("path", "repository", "commit", "archive_url"))
    if not all(isinstance(value, str) and value for value in (path, repo, sha, archive)):
        print("ERROR: BACKEND_LOCK_INVALID: submodule fields missing", file=sys.stderr)
        raise SystemExit(2)
    if path.startswith("/") or ".." in path.split("/") or not re.fullmatch(r"[A-Za-z0-9._/-]+", path):
        print("ERROR: BACKEND_LOCK_INVALID: unsafe submodule path", file=sys.stderr)
        raise SystemExit(2)
    if path in seen or not re.fullmatch(r"[0-9a-f]{40}", sha) or not archive.startswith("https://"):
        print("ERROR: BACKEND_LOCK_INVALID: invalid submodule pin", file=sys.stderr)
        raise SystemExit(2)
    seen.add(path)
print(data["commit"])
print(data["source_url"])
for module in data["submodules"]:
    print("\t".join((module["path"], module["repository"], module["commit"], module["archive_url"])))
PY
)
mapfile -t FIELDS <<< "$FIELDS_OUTPUT"
COMMIT="${FIELDS[0]}"
SOURCE_URL="${FIELDS[1]}"
echo "Backend lock valid: ChefKissInc/Inferno @ $COMMIT"
[[ "$VALIDATE_ONLY" == true ]] && exit 0

for tool in curl tar make gcc g++ ninja pkg-config meson; do
  command -v "$tool" >/dev/null || { echo "ERROR: TOOL_MISSING: $tool" >&2; exit 3; }
done
NINJA_JOBS=${NINJA_JOBS:-4}

PREFIX=$(mkdir -p "$PREFIX" && cd "$PREFIX" && pwd)
SRC_DIR="$PREFIX/source/inferno-$COMMIT"
BUILD_DIR="$PREFIX/build/inferno-$COMMIT"
mkdir -p "$PREFIX/source" "$PREFIX/cache" "$BUILD_DIR"
if [[ ! -d "$SRC_DIR" ]]; then
  archive="$PREFIX/cache/inferno-$COMMIT.tar.gz"
  curl --fail --location --retry 3 "$SOURCE_URL" --output "$archive"
  mkdir -p "$SRC_DIR"
  tar -xzf "$archive" --strip-components=1 -C "$SRC_DIR"
fi
for row in "${FIELDS[@]:2}"; do
  IFS=$'\t' read -r module_path module_repository module_commit module_archive_url <<< "$row"
  module_dir="$SRC_DIR/$module_path"
  marker="$module_dir/.pocketdarwin-commit"
  if [[ -f "$marker" ]] && [[ "$(cat "$marker")" == "$module_commit" ]]; then continue; fi
  mkdir -p "$module_dir"
  archive="$PREFIX/cache/submodule-$module_commit.tar.gz"
  curl --fail --location --retry 3 "$module_archive_url" --output "$archive"
  tar -xzf "$archive" --strip-components=1 -C "$module_dir"
  printf '%s\n' "$module_commit" > "$marker"
done

SCRIPT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
PATCH_FILE="$SCRIPT_ROOT/patches/inferno/0001-link-hogweed-for-t8030.patch"
if [[ -f "$SRC_DIR/hw/arm/apple-silicon/meson.build" ]] && ! grep -q "if_true: hogweed" "$SRC_DIR/hw/arm/apple-silicon/meson.build"; then
  git -C "$SRC_DIR" apply "$PATCH_FILE"
fi
PATCH_FILE="$SCRIPT_ROOT/patches/inferno/0002-a13-system-register-bank.patch"
if [[ -f "$SRC_DIR/hw/arm/apple-silicon/a13.c" ]] && ! grep -q "A13_CPREG_DEF(S3_2_C15_C2_0" "$SRC_DIR/hw/arm/apple-silicon/a13.c"; then
  git -C "$SRC_DIR" apply "$PATCH_FILE"
fi

if [[ -x "$SRC_DIR/configure" ]]; then
  cd "$BUILD_DIR"
  "$SRC_DIR/configure" --prefix="$PREFIX/install" --target-list=aarch64-softmmu --enable-sdl --enable-slirp --enable-virtfs --enable-nettle --disable-werror
  ninja -C "$BUILD_DIR" -j "$NINJA_JOBS"
  ninja -C "$BUILD_DIR" -j "$NINJA_JOBS" install
else
  meson setup "$BUILD_DIR" "$SRC_DIR" -Dprefix="$PREFIX/install" -Dsdl=enabled -Dslirp=enabled -Dwerror=false
  meson compile -C "$BUILD_DIR" -j "$NINJA_JOBS"
  meson install -C "$BUILD_DIR"
fi
binary="$PREFIX/install/bin/qemu-system-aarch64"
[[ -x "$binary" ]] || { echo "ERROR: BUILD_OUTPUT_MISSING: $binary" >&2; exit 4; }
"$binary" -machine help > "$PREFIX/machine-list.txt"
"$binary" --version > "$PREFIX/version.txt"
python3 - "$PREFIX" "$COMMIT" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
manifest = {"repository": "https://github.com/ChefKissInc/Inferno.git", "commit": sys.argv[2],
            "version": (root / "version.txt").read_text().strip(),
            "machines": (root / "machine-list.txt").read_text().splitlines(),
            "binary": "install/bin/qemu-system-aarch64"}
(root / "build-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
PY
echo "Backend installed: $binary"
