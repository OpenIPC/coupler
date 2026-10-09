#!/usr/bin/env python3
"""
Minimal u-boot env image generator — equivalent to `mkenvimage -s SIZE` for
the non-redundant default layout: a 4-byte little-endian CRC32 of the env
body, followed by NUL-separated KEY=VALUE entries, double-NUL terminated, and
padded to SIZE with 0xFF.

Used by `_camhi2oipc.sh` when `mkenvimage` is not on PATH (e.g. local dev on
macOS) so the build does not require u-boot-tools to be installed.
"""

from __future__ import annotations

import argparse
import sys
import zlib
from pathlib import Path


def build_env(text: str, size: int) -> bytes:
    body = bytearray()
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            raise ValueError(f"env line missing '=': {line!r}")
        body.extend(line.encode())
        body.append(0)
    body.append(0)  # double-NUL terminator

    payload_max = size - 4  # 4 bytes reserved for the leading CRC
    if len(body) > payload_max:
        raise ValueError(
            f"env body ({len(body)} bytes) exceeds partition ({payload_max} bytes)"
        )
    body.extend(b"\xff" * (payload_max - len(body)))
    crc = zlib.crc32(bytes(body)) & 0xFFFFFFFF
    return crc.to_bytes(4, "little") + bytes(body)


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    p.add_argument("-s", "--size", required=True, help="env partition size (e.g. 0x10000)")
    p.add_argument("-o", "--output", required=True)
    p.add_argument("input", nargs="?", help="env source file (default: stdin)")
    args = p.parse_args(argv)

    size = int(args.size, 0)
    text = Path(args.input).read_text() if args.input else sys.stdin.read()
    out = build_env(text, size)
    Path(args.output).write_bytes(out)
    print(
        f"wrote {args.output} ({len(out)} bytes, body crc=0x{int.from_bytes(out[:4], 'little'):08x})",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
