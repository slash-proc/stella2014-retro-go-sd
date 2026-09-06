#!/usr/bin/env python3
"""Append stella2014_defprops.bin after a packed CORE .bin.

Layout (little-endian):

    [existing CORE container from pack_core.py]
    [defprops.bin bytes]
    [footer 16 bytes]
        magic    u32  'STDP' (0x50445453)
        version  u32  1
        off      u32  absolute file offset of defprops payload
        size     u32

The firmware loader only copies declared CORE segments, so the trailer is
ignored at load time. DefPropsBin.c opens the core .bin and seeks using
the footer (see defprops_init).
"""

from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path

MAGIC = 0x50445453  # 'S','T','D','P'
VERSION = 1
FOOTER_SIZE = 16


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--core", type=Path, required=True, help="packed CORE .bin (updated in place)")
    ap.add_argument("--defprops", type=Path, required=True, help="stella2014_defprops.bin")
    args = ap.parse_args()

    if not args.core.is_file():
        sys.exit(f"error: core not found: {args.core}")
    if not args.defprops.is_file():
        sys.exit(f"error: defprops not found: {args.defprops}")

    core = args.core.read_bytes()
    # Idempotent: strip a previous STDP footer + blob if re-packing.
    if len(core) >= FOOTER_SIZE:
        magic, ver, off, size = struct.unpack_from("<IIII", core, len(core) - FOOTER_SIZE)
        if magic == MAGIC and ver == VERSION:
            if 0 < off < len(core) and off + size <= len(core) - FOOTER_SIZE:
                core = core[:off]

    props = args.defprops.read_bytes()
    if not props:
        sys.exit("error: defprops file is empty")

    off = len(core)
    footer = struct.pack("<IIII", MAGIC, VERSION, off, len(props))
    out = core + props + footer
    args.core.write_bytes(out)

    print(
        f"append_stella_defprops: {args.core} "
        f"({len(out)} bytes; core={off}, defprops@{off}+{len(props)})"
    )


if __name__ == "__main__":
    main()
