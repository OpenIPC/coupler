#!/usr/bin/env python3
"""
dump.bin -> Huishi/HiSilicon HUFH update ROM.

Usage:
    python3 _huishi2oipc.py dump.bin
    python3 _huishi2oipc.py dump.bin P21H-openipc.rom
    python3 _huishi2oipc.py dump.bin --soc hi3516cv610 \
        --uboot-size 0x30000 --kernel-size 0x280000 --appfs-size 0x4e0000

The input is sliced sequentially as uboot, kernel, appfs.  Short
partitions are padded with 0xff.  Versions are maxed out so the vendor
updater accepts the package.
"""

import argparse
import struct
import zlib

HEADER_SIZE = 0x220
MAGIC = b"HUFH"
DEVICE_TYPE = 0xA0000001
MAX_VERSION = 0xFFFFFFFF
KEY = bytes.fromhex("A8 FD 6A 31 12 A9 E5 19 D5 B6 94 1A 10 8A E9 F1")
DEFAULT_PRODUCT = "P21H"
PART3 = "appfs"


def main():
    ap = argparse.ArgumentParser(description="dump.bin -> Huishi HUFH ROM")
    ap.add_argument("input", help="raw dump / OpenIPC image")
    ap.add_argument("output", nargs="?", default=None,
                    help="output ROM (default: <product>-openipc.rom)")
    ap.add_argument("--soc", default="hi3516cv610",
                    help="SoC name / header CPU string (default hi3516cv610)")
    ap.add_argument("--product", default=DEFAULT_PRODUCT,
                    help="product name (default P21H)")
    ap.add_argument("--uboot-size", type=lambda x: int(x, 0), default=0x030000,
                    help="uboot size (default 0x30000)")
    ap.add_argument("--kernel-size", type=lambda x: int(x, 0), default=0x280000,
                    help="kernel size (default 0x280000)")
    ap.add_argument("--appfs-size", type=lambda x: int(x, 0), default=0x4E0000,
                    help="third partition size (default 0x4e0000)")
    args = ap.parse_args()

    data = open(args.input, "rb").read()
    parts = [
        ("uboot", args.uboot_size),
        ("kernel", args.kernel_size),
        (PART3, args.appfs_size),
    ]

    payload = bytearray()
    pos = 0
    for name, size in parts:
        chunk = data[pos:pos + size]
        if len(chunk) < size:
            print("[!] %s: 0x%x of 0x%x bytes, padding with 0xff"
                  % (name, len(chunk), size))
            chunk += b"\xff" * (size - len(chunk))
        payload += chunk
        pos += size

    stream = (KEY * (len(payload) // len(KEY) + 1))[:len(payload)]
    enc = bytes(a ^ b for a, b in zip(payload, stream))

    h = bytearray(HEADER_SIZE)
    h[0:4] = MAGIC
    struct.pack_into("<I", h, 0x08, DEVICE_TYPE)
    h[0x0C:0x1C] = args.soc.encode()[:16].ljust(16, b"\x00")
    struct.pack_into("<I", h, 0x1C, MAX_VERSION)
    struct.pack_into("<I", h, 0x20, 1)
    h[0x24:0x34] = args.product.encode()[:16].ljust(16, b"\x00")
    h[0x34:0x3C] = b"flash".ljust(8, b"\x00")
    struct.pack_into("<I", h, 0x3C, len(payload))
    struct.pack_into("<I", h, 0x40, zlib.crc32(enc) & 0xFFFFFFFF)

    off = 0
    for i, (name, size) in enumerate(parts):
        o = 0x44 + i * 0x38
        h[o:o + 8] = name.encode()[:8].ljust(8, b"\x00")
        h[o + 8:o + 0x18] = ("/dev/mtdblock%d" % i).encode().ljust(16, b"\x00")
        struct.pack_into("<IIII", h, o + 0x28, off, size, MAX_VERSION, 1)
        off += size

    struct.pack_into("<H", h, 0x204, 0)      # ODM
    struct.pack_into("<H", h, 0x206, 0x0004) # skip ODM check
    struct.pack_into("<I", h, 4, zlib.crc32(h[8:] + enc) & 0xFFFFFFFF)

    output = args.output or ("%s-openipc.rom" % args.product)
    with open(output, "wb") as f:
        f.write(h + enc)

    print("[+] %s -> %s (0x%x payload)" % (args.input, output, len(payload)))


if __name__ == "__main__":
    main()
