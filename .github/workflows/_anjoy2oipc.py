#!/usr/bin/env python3
"""
Split raw dump into ANJOY888 package.

Partition sizes are max size from target env. Input data is sliced sequentially

Usage:
    python3 _anjoy2oipc.py dump.bin out.bin \
        --uboot-size 0x30000 --kernel-size 0x200000 --rootfs-size 0xcd0000 \
        --kernel-version MSTAR_I6C_LINUX_378DE \
        --rootfs-version MCJ86_V0-A-H5_V3.2.5.6
"""

import argparse
import struct
import sys
import zlib

HEADER_FORMAT = '<8sIIIIII256sII256sIIIIIIIIII964x'
HEADER_SIZE = struct.calcsize(HEADER_FORMAT)
MAGIC = b"ANJOY888"


class AnjoyFirmware:
    def __init__(self, header_str, header_crc, file_size, ftype,
                 kernel_start, kernel_size, kernel_crc, kernel_version_info,
                 fs_start, fs_size, fs_version_info, fs_crc,
                 uboot_start, uboot_size, uboot_crc,
                 tgz_start, tgz_size, tgz_crc,
                 oem_start, oem_size, oem_crc):
        self.header_str = header_str
        self.header_crc = header_crc
        self.file_size = file_size
        self.ftype = ftype
        self.kernel_start = kernel_start
        self.kernel_size = kernel_size
        self.kernel_crc = kernel_crc
        self.kernel_version_info = kernel_version_info
        self.fs_start = fs_start
        self.fs_size = fs_size
        self.fs_version_info = fs_version_info
        self.fs_crc = fs_crc
        self.uboot_start = uboot_start
        self.uboot_size = uboot_size
        self.uboot_crc = uboot_crc
        self.tgz_start = tgz_start
        self.tgz_size = tgz_size
        self.tgz_crc = tgz_crc
        self.oem_start = oem_start
        self.oem_size = oem_size
        self.oem_crc = oem_crc

    def make_header(self):
        return struct.pack(HEADER_FORMAT,
                           self.header_str, self.header_crc, self.file_size, self.ftype,
                           self.kernel_start, self.kernel_size, self.kernel_crc, self.kernel_version_info,
                           self.fs_start, self.fs_size, self.fs_version_info, self.fs_crc,
                           self.uboot_start, self.uboot_size, self.uboot_crc,
                           self.tgz_start, self.tgz_size, self.tgz_crc,
                           self.oem_start, self.oem_size, self.oem_crc)

    def print_header(self):
        kv = self.kernel_version_info.rstrip(b'\x00').decode('ascii', errors='replace')
        rv = self.fs_version_info.rstrip(b'\x00').decode('ascii', errors='replace')
        print(f"Header CRC:      0x{self.header_crc:08x}")
        print(f"File Size:       0x{self.file_size:x} ({self.file_size})")
        print(f"Type:            0x{self.ftype:x}")
        print(f"Kernel Start:    0x{self.kernel_start:x}  Size: 0x{self.kernel_size:x}  CRC: 0x{self.kernel_crc:08x}")
        print(f"Kernel Version:  {kv}")
        print(f"Rootfs Start:    0x{self.fs_start:x}  Size: 0x{self.fs_size:x}  CRC: 0x{self.fs_crc:08x}")
        print(f"Rootfs Version:  {rv}")
        print(f"Uboot Start:     0x{self.uboot_start:x}  Size: 0x{self.uboot_size:x}  CRC: 0x{self.uboot_crc:08x}")
        print("----------------------------------------")


def pad_field(s, size=256):
    if isinstance(s, str):
        s = s.encode('ascii', errors='replace')
    return s[:size].ljust(size, b'\x00')


def main():
    ap = argparse.ArgumentParser(description="Split raw MCJ86 dump into ANJOY888 package")
    ap.add_argument("input", help="Raw firmware dump")
    ap.add_argument("output", nargs="?", default=None, help="Output package file (optional)")
    ap.add_argument("--uboot-size", type=lambda x: int(x, 0), default=0, help="Uboot max partition size")
    ap.add_argument("--kernel-size", type=lambda x: int(x, 0), default=0, help="Kernel max partition size")
    ap.add_argument("--rootfs-size", type=lambda x: int(x, 0), default=0, help="Rootfs max partition size")
    ap.add_argument("--kernel-version", default="", help="Kernel version string (256 byte field)")
    ap.add_argument("--rootfs-version", default="", help="Rootfs version string (256 byte field)")
    args = ap.parse_args()

    if args.output is None:
        if not args.rootfs_version:
            print("[!] Output not specified and --rootfs-version is empty", file=sys.stderr)
            sys.exit(1)
        safe_name = args.rootfs_version.replace("/", "_").replace("\\", "_")
        args.output = f"{safe_name}-openipc.bin"
        print(f"[i] Output not specified, using: {args.output}")

    with open(args.input, "rb") as f:
        data = f.read()

    # Sequential slice: uboot -> kernel -> rootfs
    parts = []
    offset = 0
    for name, max_sz in [("uboot", args.uboot_size), ("kernel", args.kernel_size), ("rootfs", args.rootfs_size)]:
        if max_sz == 0:
            continue
        available = len(data) - offset
        take = min(available, max_sz)
        chunk = data[offset:offset + take]
        if take < max_sz:
            chunk += b'\x00' * (max_sz - take)
            print(f"[+] {name}: 0x{offset:x} .. 0x{offset + take:x} ({take} B data + {max_sz - take} B padding)")
        else:
            print(f"[+] {name}: 0x{offset:x} .. 0x{offset + take:x} ({take} bytes)")
        parts.append((name, chunk))
        offset += take

    if not parts:
        print("[!] No components specified", file=sys.stderr)
        sys.exit(1)

    # Build header
    hdr = AnjoyFirmware(
        MAGIC, 0, 0, 0,
        0, 0, 0, pad_field(args.kernel_version),
        0, 0, pad_field(args.rootfs_version), 0,
        0, 0, 0,
        0, 0, 0,
        0, 0, 0,
    )

    cursor = HEADER_SIZE
    ftype = 0
    ft_map = {"kernel": 1, "rootfs": 2, "uboot": 4}

    for name, payload in parts:
        ftype |= ft_map[name]
        crc = zlib.crc32(payload) & 0xFFFFFFFF
        if name == "uboot":
            hdr.uboot_start, hdr.uboot_size, hdr.uboot_crc = cursor, len(payload), crc
        elif name == "kernel":
            hdr.kernel_start, hdr.kernel_size, hdr.kernel_crc = cursor, len(payload), crc
        elif name == "rootfs":
            hdr.fs_start, hdr.fs_size, hdr.fs_crc = cursor, len(payload), crc
        cursor += len(payload)

    hdr.ftype = ftype
    hdr.file_size = cursor

    # Compute header CRC (field zeroed)
    hdr_data = hdr.make_header()
    hdr.header_crc = zlib.crc32(hdr_data) & 0xFFFFFFFF
    hdr_data = hdr.make_header()

    with open(args.output, "wb") as f:
        f.write(hdr_data)
        for _, payload in parts:
            f.write(payload)

    hdr.print_header()
    print(f"[+] Wrote: {args.output}")


if __name__ == "__main__":
    main()
