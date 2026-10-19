#!/usr/bin/env python3
"""Inspect restore metadata in a locally obtained IPSW without extracting firmware."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import plistlib
import zipfile


def read_plist(archive: zipfile.ZipFile, name: str) -> dict:
    try:
        return plistlib.loads(archive.read(name))
    except KeyError as exc:
        raise RuntimeError(f"IPSW is missing {name}") from exc


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipsw", type=Path, help="Path to an Apple iPhone restore IPSW")
    parser.add_argument("--device", default="iPhone12,1", help="Expected product type (default: iPhone12,1)")
    args = parser.parse_args()
    if not args.ipsw.is_file():
        parser.error(f"IPSW does not exist: {args.ipsw}")

    try:
        with zipfile.ZipFile(args.ipsw) as archive:
            build = read_plist(archive, "BuildManifest.plist")
            info = read_plist(archive, "Info.plist")
    except zipfile.BadZipFile as exc:
        raise SystemExit(f"ERROR: IPSW is not a valid ZIP archive: {exc}") from exc

    product_type = info.get("ProductType") or build.get("ProductType")
    if product_type != args.device:
        raise SystemExit(f"ERROR: wrong device: expected {args.device}, found {product_type!r}")

    identities = []
    for identity in build.get("BuildIdentities", []):
        details = identity.get("Info", {})
        if details.get("DeviceClass") not in {"n104ap", "n104"}:
            continue
        components = {}
        for name, entry in identity.get("Manifest", {}).items():
            if name in {
                "KernelCache", "RestoreRamDisk", "DeviceTree", "SEP", "SEPFirmware",
                "RestoreTrustCache", "OS", "SystemVolume", "iBSS", "iBEC", "LLB",
            }:
                item = {"path": entry.get("Info", {}).get("Path")}
                if "IsPersonalized" in entry.get("Info", {}):
                    item["personalized"] = bool(entry["Info"]["IsPersonalized"])
                components[name] = item
        identities.append({
            "device_class": details.get("DeviceClass"),
            "variant": details.get("Variant"),
            "restore_behavior": details.get("RestoreBehavior"),
            "components": components,
        })

    if not identities:
        raise SystemExit(f"ERROR: no iPhone 11 (n104) build identities found for {args.device}")

    result = {
        "ipsw": str(args.ipsw.resolve()),
        "product_type": product_type,
        "product_version": info.get("ProductVersion"),
        "build_version": info.get("ProductBuildVersion"),
        "identity_count": len(identities),
        "identities": identities,
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
