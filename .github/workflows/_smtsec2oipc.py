#!/usr/bin/env python3
# OpenIPC full NOR image -> SMTSEC / "hiface" /fwUpgrade package.
#
# Format + CRC recovered by static RE of the stock updater /usr/hiface/update
# (updateProc.c: FUN_000162fe parse, FUN_00015a72 raw-mtd write,
# FUN_00013af2/13a84 crc) on a K662C6S dump. The package is consumed by the
# stock firmware's own network upgrade path.
#
# Raw-MTD mode (header type 0x42): one entry per partition, written to its
# /dev/mtdN at offset 0. Give the board's stock partition sizes in order with
# --mtd0-size .. --mtdN-size; they must sum to the image, and slicing the
# OpenIPC image at those boundaries reconstructs the whole chip. A new board is
# one line in smtsec.yml: its partition sizes, its device code
# (--dev-type/--sdk-type/--platform-type, from the camera's updatetype.ini,
# which the updater checks), the image, and the output name.
#
# Verified in qemu-hisilicon for the K662C6S: the applied chip is
# sha256-identical to the OpenIPC image and boots to login.
import argparse, struct

MAGIC1, MAGIC2 = 0xABCABCCB, 0xCBCBACBA
HDR, ENT, TRL = 0x34, 0xA4, 0x1C
MAX_MTD = 16

_TAB = []
for _i in range(256):
    _c = _i
    for _ in range(8):
        _c = (_c >> 1) ^ 0xBDB083E0 if (_c & 1) else (_c >> 1)
    _TAB.append(_c & 0xFFFFFFFF)

def crc(data, init=0xCB):                 # vendor CRC, not crc32: no final xor
    c = init & 0xFFFFFFFF
    for b in data:
        c = ((c >> 8) ^ _TAB[(c ^ b) & 0xFF]) & 0xFFFFFFFF
    return c

def parse_size(tok):
    tok = tok.strip().lower()
    mul = {"k": 1024, "m": 1024 * 1024, "g": 1024 * 1024 * 1024}.get(tok[-1:], 1)
    return int(tok[:-1] if mul != 1 else tok, 0) * mul

def _entry(name, length, data_off, c):
    e = bytearray(ENT)
    e[0:len(name.encode())] = name.encode()      # 0x00 name[0x80], NUL-terminated
    struct.pack_into("<I", e, 0x80, length)       # 0x80 length
    struct.pack_into("<I", e, 0x84, data_off)     # 0x84 data offset from file start
    struct.pack_into("<I", e, 0x90, c)            # 0x90 crc
    return bytes(e)

def build(img, sizes, dev, sdk, plat, reboot=1):
    if sum(sizes) != len(img):
        raise SystemExit("partition sizes sum 0x%x != image 0x%x"
                         % (sum(sizes), len(img)))
    off, base = HDR + ENT * len(sizes), 0
    ents, blobs = [], []
    for i, size in enumerate(sizes):           # /dev/mtd0..N, natural order
        blob = img[base:base + size]
        ents.append(("/dev/mtd%d" % i, len(blob), off, crc(blob)))
        blobs.append(blob); off += len(blob); base += size
    total = off + TRL
    h = bytearray(HDR)
    struct.pack_into("<I", h, 0x00, MAGIC1)
    struct.pack_into("<I", h, 0x04, 0x42)      # raw-mtd
    struct.pack_into("<I", h, 0x08, dev)
    struct.pack_into("<I", h, 0x0C, sdk)
    struct.pack_into("<I", h, 0x10, plat)
    struct.pack_into("<I", h, 0x14, len(sizes))
    struct.pack_into("<I", h, 0x18, total)
    h[0x1C] = reboot & 0xFF                      # nonzero: reboot after write
    h[0x1E] = 0                                  # phy-mode check off
    struct.pack_into("<I", h, 0x30, MAGIC2)
    t = bytearray(TRL)
    struct.pack_into("<I", t, 0x00, MAGIC1)
    struct.pack_into("<I", t, 0x18, MAGIC2)
    out = bytes(h) + b"".join(_entry(*e) for e in ents) + b"".join(blobs) + bytes(t)
    assert len(out) == total
    return out

def main():
    ap = argparse.ArgumentParser(description="OpenIPC image -> SMTSEC /fwUpgrade package")
    ap.add_argument("input"); ap.add_argument("output", nargs="?")
    ap.add_argument("--dev-type",      type=int, required=True, help="DEV_TYPE from updatetype.ini")
    ap.add_argument("--sdk-type",      type=int, required=True, help="SDK_TYPE from updatetype.ini")
    ap.add_argument("--platform-type", type=int, required=True, help="PLATFORM_TYPE from updatetype.ini")
    for i in range(MAX_MTD):
        ap.add_argument("--mtd%d-size" % i, help="size of /dev/mtd%d (e.g. 3m, 512k)" % i)
    a = ap.parse_args()
    sizes = []
    for i in range(MAX_MTD):
        v = getattr(a, "mtd%d_size" % i)
        if v is None:
            break
        sizes.append(parse_size(v))
    # every partition up to the last must be given: offsets accumulate
    for i in range(len(sizes), MAX_MTD):
        if getattr(a, "mtd%d_size" % i) is not None:
            raise SystemExit("--mtd%d-size set but an earlier --mtdN-size is missing" % i)
    if not sizes:
        raise SystemExit("give at least --mtd0-size")
    img = open(a.input, "rb").read()
    pkg = build(img, sizes, a.dev_type, a.sdk_type, a.platform_type)
    out = a.output or (a.input.rsplit(".", 1)[0] + "-openipc.bin")
    open(out, "wb").write(pkg)
    print("[+] %s -> %s (%d bytes, %d partitions, version 0x%08X)"
          % (a.input, out, len(pkg), len(sizes),
             (a.dev_type << 24) | (a.sdk_type << 16) | (a.platform_type & 0xFFFF)))

if __name__ == "__main__":
    main()
