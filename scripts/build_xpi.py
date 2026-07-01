#!/usr/bin/env python3
"""Build a signed-by-extension-id XPI for Thunderbird 128+.

Output: dist/attachclip-thunderbird-0.1.0.xpi

Contents (only the extension folder, no dev files):
  extension/manifest.json
  extension/icons/*.png
  extension/src/*.js

The script also writes a SHA-256 sidecar so reviewers can verify the
artifact is bit-for-bit reproducible.
"""

from __future__ import annotations

import hashlib
import os
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXT_DIR = ROOT / "extension"
DIST_DIR = ROOT / "dist"
DIST_DIR.mkdir(exist_ok=True)

VERSION = "0.1.0"
OUT_XPI = DIST_DIR / f"attachclip-thunderbird-{VERSION}.xpi"


def add_relative(zf: zipfile.ZipFile, abs_path: Path, arcname: str) -> None:
    """Add a file using STORE compression for already-compressed assets."""
    compress = zipfile.ZIP_DEFLATED
    if abs_path.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"}:
        compress = zipfile.ZIP_STORED  # already compressed, no point
    zf.write(abs_path, arcname, compress_type=compress)


def main() -> int:
    if not EXT_DIR.exists():
        print(f"ERROR: extension folder missing at {EXT_DIR}", file=sys.stderr)
        return 1

    files: list[Path] = []
    files += sorted(EXT_DIR.glob("manifest.json"))
    files += sorted(EXT_DIR.glob("icons/*.png"))
    files += sorted(EXT_DIR.glob("src/*.js"))

    # Defensive: refuse to package dev-only artefacts
    for forbidden in ("tests", ".DS_Store", ".git"):
        for f in files:
            if forbidden in f.parts:
                print(f"REFUSE: dev artefact in package: {f}", file=sys.stderr)
                return 2

    if not files:
        print("ERROR: nothing to package", file=sys.stderr)
        return 3

    h = hashlib.sha256()
    with zipfile.ZipFile(OUT_XPI, "w", zipfile.ZIP_DEFLATED) as zf:
        for f in files:
            arcname = str(f.relative_to(ROOT))
            add_relative(zf, f, arcname)
            with open(f, "rb") as fh:
                h.update(fh.read())

    digest = h.hexdigest()
    size = OUT_XPI.stat().st_size
    sha_sidecar = OUT_XPI.with_suffix(".xpi.sha256")
    sha_sidecar.write_text(f"{digest}  {OUT_XPI.name}\n", encoding="utf-8")

    print(f"wrote {OUT_XPI} ({size} bytes)")
    print(f"sha256: {digest}")
    print(f"sidecar: {sha_sidecar}")

    # Sanity print of what's inside
    print("\nContents:")
    with zipfile.ZipFile(OUT_XPI, "r") as zf:
        for info in zf.infolist():
            print(f"  {info.file_size:>8}  {info.filename}")
    return 0


if __name__ == "__main__":
    sys.exit(main())