#!/usr/bin/env python3
"""Download an Apple-hosted IPSW using resumable parallel byte ranges."""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
from pathlib import Path
import re
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import Request, urlopen


API_TEMPLATE = "https://api.ipsw.me/v4/device/{device}?type=ipsw"
CHUNK_SIZE = 64 * 1024 * 1024
WORKERS = 12
MAX_ATTEMPTS = 5


def get_firmware(device: str, version: str) -> dict:
    request = Request(API_TEMPLATE.format(device=device), headers={"User-Agent": "PocketDarwin/0.1"})
    with urlopen(request, timeout=30) as response:
        catalog = json.load(response)
    firmware = next((item for item in catalog.get("firmwares", []) if item.get("version") == version), None)
    if firmware is None:
        raise RuntimeError(f"No IPSW listed for {device} iOS {version}")
    parsed = urlparse(firmware.get("url", ""))
    if parsed.scheme != "https" or parsed.hostname != "updates.cdn-apple.com":
        raise RuntimeError("Refusing firmware URL outside Apple's update CDN")
    return firmware


def content_length(url: str) -> int:
    request = Request(url, method="HEAD", headers={"User-Agent": "PocketDarwin/0.1"})
    with urlopen(request, timeout=30) as response:
        length = response.headers.get("Content-Length")
    if not length or not length.isdigit():
        raise RuntimeError("Apple CDN did not provide a valid Content-Length")
    return int(length)


def download_chunk(url: str, fd: int, start: int, end: int, total: int) -> None:
    expected = end - start + 1
    for attempt in range(1, MAX_ATTEMPTS + 1):
        request = Request(
            url,
            headers={
                "User-Agent": "PocketDarwin/0.1",
                "Range": f"bytes={start}-{end}",
            },
        )
        try:
            with urlopen(request, timeout=120) as response:
                content_range = response.headers.get("Content-Range", "")
                if response.status != 206 or content_range != f"bytes {start}-{end}/{total}":
                    raise RuntimeError(f"Unexpected range response for bytes {start}-{end}: {content_range!r}")
                remaining = expected
                offset = start
                while remaining:
                    data = response.read(min(1024 * 1024, remaining))
                    if not data:
                        raise RuntimeError(f"Short response for bytes {start}-{end}")
                    os.pwrite(fd, data, offset)
                    offset += len(data)
                    remaining -= len(data)
            return
        except (HTTPError, URLError, TimeoutError, OSError, RuntimeError) as exc:
            if attempt == MAX_ATTEMPTS:
                raise RuntimeError(f"Failed range {start}-{end}: {exc}") from exc
            time.sleep(min(attempt * 2, 10))


def sha256(path: Path) -> str:
    import hashlib

    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", default="iPhone12,1", help="Apple device identifier (default: iPhone12,1)")
    parser.add_argument("--version", default="26.6.2", help="iOS version to fetch (default: 26.6.2)")
    parser.add_argument("--output", required=True, type=Path, help="Private destination path for the IPSW")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9,._-]+", args.device) or not re.fullmatch(r"[0-9.]+", args.version):
        parser.error("device or version contains unsupported characters")

    firmware = get_firmware(args.device, args.version)
    url = firmware["url"]
    total = content_length(url)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    partial = args.output.with_suffix(args.output.suffix + ".partial")
    state_path = partial.with_suffix(partial.suffix + ".json")

    # A prior single-stream partial is reused for already downloaded initial bytes.
    existing_output = args.output if args.output.exists() else None
    if existing_output:
        os.replace(existing_output, partial)
    fd = os.open(partial, os.O_CREAT | os.O_RDWR, 0o600)
    try:
        prior_size = os.fstat(fd).st_size
        if prior_size > total:
            os.ftruncate(fd, 0)
            prior_size = 0
        state = {"size": total, "completed": []}
        if state_path.exists():
            try:
                candidate = json.loads(state_path.read_text(encoding="utf-8"))
                if candidate.get("size") == total and isinstance(candidate.get("completed"), list):
                    state["completed"] = [
                        index for index in candidate["completed"]
                        if isinstance(index, int) and 0 <= index < (total + CHUNK_SIZE - 1) // CHUNK_SIZE
                    ]
            except (OSError, json.JSONDecodeError):
                pass
        elif prior_size:
            # Reuse only fully downloaded chunks from an earlier sequential curl run.
            state["completed"] = list(range(prior_size // CHUNK_SIZE))
        os.ftruncate(fd, total)
        ranges = []
        completed_indices = set(state["completed"])
        for index, start in enumerate(range(0, total, CHUNK_SIZE)):
            end = min(start + CHUNK_SIZE, total) - 1
            if index in completed_indices:
                continue
            ranges.append((index, start, end))

        print(f"iOS {firmware['version']} ({firmware['buildid']}) for {args.device}; {total:,} bytes")
        print(f"Apple signing status in catalog: {'signed' if firmware.get('signed') else 'unsigned'}")
        print(f"Catalog SHA-256 (ipsw.me): {firmware.get('sha256sum', 'not listed')}")
        print(f"Downloading {len(ranges)} ranges with {WORKERS} workers to {args.output}", flush=True)
        completed = 0
        with concurrent.futures.ThreadPoolExecutor(max_workers=WORKERS) as pool:
            futures = {
                pool.submit(download_chunk, url, fd, start, end, total): index
                for index, start, end in ranges
            }
            for future in concurrent.futures.as_completed(futures):
                future.result()
                completed_indices.add(futures[future])
                state["completed"] = sorted(completed_indices)
                temporary_state = state_path.with_suffix(state_path.suffix + ".tmp")
                temporary_state.write_text(json.dumps(state), encoding="utf-8")
                os.replace(temporary_state, state_path)
                completed += 1
                if completed % 8 == 0 or completed == len(ranges):
                    print(f"Downloaded ranges this run: {completed}/{len(ranges)}", flush=True)
        os.fsync(fd)
    finally:
        os.close(fd)

    actual_sha256 = sha256(partial)
    if firmware.get("sha256sum") and actual_sha256.lower() != firmware["sha256sum"].lower():
        partial.unlink(missing_ok=True)
        state_path.unlink(missing_ok=True)
        raise RuntimeError(f"SHA-256 mismatch: expected {firmware['sha256sum']}, got {actual_sha256}")
    os.replace(partial, args.output)
    state_path.unlink(missing_ok=True)
    print(f"SHA-256 verified: {actual_sha256}")
    print(f"Saved: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
