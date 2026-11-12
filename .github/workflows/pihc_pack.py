#!/usr/bin/env python3
"""
PIHC firmware container packer (camhi / Hi3516CV610 family).

Builds the "PIHC" `.pkg` container that the vendor's `upgrade.cgi` admin
endpoint accepts as a firmware update. The format was reverse-engineered from
the vendor `ipc_server` binary (functions `sub_37EA4` / `sub_36A70` /
`sub_36D64`) on a CamHi-app Hi3516CV610 reference device.

WHAT IS VERIFIED vs ASSUMED
---------------------------
Verified by reading the vendor binary and the live device:
  * the 512-byte header layout (magic, type, lengths, MD5+"IPCAM" strings),
  * the per-component MD5+"IPCAM" integrity check (`sub_1CA00`),
  * the empty-zip / no-cipher code path (see below),
  * the component->partition mapping (boot/bootarg/kernel/rootfs/ipc).
NOT verified — no end-to-end flash has been performed:
  * that a packed `.pkg` actually flashes and boots OpenIPC on hardware.

THE "ZIP" COMPONENT CIPHER
--------------------------
The final "zip" component is wrapped in a CUSTOM Hichip block cipher
(`sub_5A2C0` / `sub_59F18`). It is NOT AES — the binary contains no AES
S-box / inverse S-box / Rcon tables (checked). The cipher has not been
reversed.

It does not need to be: the decoder (`sub_37EA4` lines 47049-47132) only
invokes the cipher on chunks at index 1, 17, 33, ... (every 16th 1024-byte
chunk, starting at index 1). Chunk 0 is never decrypted. For a "zip" blob
<= 1024 bytes the cipher is never touched — only a PK-signature mangle is
applied. The OpenIPC conversion keeps the zip slot to a 22-byte empty ZIP,
so the packer never needs the cipher. `hichip_encrypt_chunk` is therefore a
stub that raises NotImplementedError; reversing the cipher (to support
larger payloads) is a separate task.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import struct
import sys
from dataclasses import dataclass
from pathlib import Path

# ---------------------------------------------------------------------------
# Constants extracted from `ipc_server` (Hi3516CV610 vendor firmware).

PIHC_MAGIC = 0x43484950  # bytes "PIHC" little-endian
TYPE_RESTORE = 4097  # restore.cgi mode — final blob = config_restore.bin
TYPE_UPGRADE = 4098  # upgrade.cgi mode — final blob = upgrade.zip

# 512-byte header field offsets (validator: sub_36A70, ipc_server.c:45587).
OFF_MAGIC = 0
OFF_TYPE = 4
OFF_LEN_BOOT = 8
OFF_LEN_BOOTARG = 12
OFF_LEN_KERNEL = 16
OFF_LEN_ROOTFS = 20
OFF_LEN_IPC = 24
OFF_LEN_ZIP = 28
OFF_FILENAME = 32  # also used by the vendor in log messages
OFF_MD5_BOOT = 72  # 40-byte lowercase-hex MD5 strings, NUL-padded
OFF_MD5_BOOTARG = 112
OFF_MD5_KERNEL = 152
OFF_MD5_ROOTFS = 192
OFF_MD5_IPC = 232
OFF_MD5_ZIP = 272
HEADER_SIZE = 512

# Hichip cipher constants (sub_37EA4:47049-47132). Kept for documentation and
# for a future cipher implementation; not used on the empty-zip path.
HICHIP_KEY_A = b"@Hichip+1208/pkg"
HICHIP_KEY_B = b"$Hichip-1208%aes"
HICHIP_KEY_C = b"#Hichip*1208=key"
HICHIP_CHUNK = 1024
HICHIP_KEY_PERIOD = 16  # one key change every N chunks

# MD5 trailer for the integrity check (sub_1CA00 final update).
MD5_TRAILER = b"IPCAM"

# A pre-built empty ZIP: just an end-of-central-directory record (22 bytes).
EMPTY_ZIP = b"PK\x05\x06" + b"\x00" * 18
assert len(EMPTY_ZIP) == 22


# ---------------------------------------------------------------------------
# Per-component checksum (sub_1CA00 == MD5(data || "IPCAM")).


def md5_ipcam_digest(data: bytes) -> str:
    h = hashlib.md5()
    h.update(data)
    h.update(MD5_TRAILER)
    return h.hexdigest()


# ---------------------------------------------------------------------------
# ZIP-signature mangle (sub_37EA4:47093-47126).
#
# On disk the .pkg holds PK signatures with the 4th byte +3; the vendor reader
# rewrites them back to canonical. So the packer must emit the +3 variants:
#   PK\x03\x04 -> PK\x03\x07   (local file header)
#   PK\x01\x02 -> PK\x01\x08   (central directory header)
#   PK\x05\x06 -> PK\x05\x09   (end-of-central-directory)


def apply_pk_mangle(data: bytes) -> bytes:
    buf = bytearray(data)
    n = len(buf)
    i = 0
    while i + 3 < n:
        if buf[i] == 0x50 and buf[i + 1] == 0x4B:  # 'P', 'K'
            b2, b3 = buf[i + 2], buf[i + 3]
            if b2 == 3 and b3 == 4:
                buf[i + 3] = 7
            elif b2 == 1 and b3 == 2:
                buf[i + 3] = 8
            elif b2 == 5 and b3 == 6:
                buf[i + 3] = 9
        i += 1
    return bytes(buf)


def hichip_encrypt_chunk(chunk: bytes, key: bytes) -> bytes:
    """Stub — see module docstring. The empty-zip path never calls this."""
    raise NotImplementedError(
        "Hichip cipher (sub_5A2C0) is unreversed and not implemented. "
        f"Keep the zip component <= {HICHIP_CHUNK} bytes to avoid it."
    )


def pack_zip_component(zip_bytes: bytes) -> bytes:
    if len(zip_bytes) > HICHIP_CHUNK:
        raise NotImplementedError(
            f"zip component must be <= {HICHIP_CHUNK} bytes (no-cipher path); "
            f"got {len(zip_bytes)}. Implement hichip_encrypt_chunk for larger."
        )
    return apply_pk_mangle(zip_bytes)


# ---------------------------------------------------------------------------
# .pkg builder.


@dataclass
class Components:
    """A `.pkg` component bundle. `None` entries become zero-length (skipped)."""

    boot: bytes | None = None
    bootarg: bytes | None = None
    kernel: bytes | None = None
    rootfs: bytes | None = None
    ipc: bytes | None = None
    zip: bytes | None = None


def build_header(
    *,
    type_: int,
    filename: str,
    boot: bytes | None,
    bootarg: bytes | None,
    kernel: bytes | None,
    rootfs: bytes | None,
    ipc: bytes | None,
    zip_packed: bytes | None,
) -> bytes:
    if len(filename.encode()) >= 40:
        raise ValueError("filename must be < 40 bytes")

    hdr = bytearray(HEADER_SIZE)
    struct.pack_into("<I", hdr, OFF_MAGIC, PIHC_MAGIC)
    struct.pack_into("<I", hdr, OFF_TYPE, type_)

    def put(off_len: int, off_md5: int, data: bytes | None) -> None:
        if not data:
            return
        struct.pack_into("<I", hdr, off_len, len(data))
        digest = md5_ipcam_digest(data).encode()
        hdr[off_md5 : off_md5 + len(digest)] = digest

    put(OFF_LEN_BOOT, OFF_MD5_BOOT, boot)
    put(OFF_LEN_BOOTARG, OFF_MD5_BOOTARG, bootarg)
    put(OFF_LEN_KERNEL, OFF_MD5_KERNEL, kernel)
    put(OFF_LEN_ROOTFS, OFF_MD5_ROOTFS, rootfs)
    put(OFF_LEN_IPC, OFF_MD5_IPC, ipc)
    put(OFF_LEN_ZIP, OFF_MD5_ZIP, zip_packed)

    name = filename.encode()
    hdr[OFF_FILENAME : OFF_FILENAME + len(name)] = name
    return bytes(hdr)


def build_pkg(components: Components, *, filename: str = "openipc.pkg") -> bytes:
    zip_in = components.zip if components.zip is not None else EMPTY_ZIP
    zip_packed = pack_zip_component(zip_in)
    header = build_header(
        type_=TYPE_UPGRADE,
        filename=filename,
        boot=components.boot,
        bootarg=components.bootarg,
        kernel=components.kernel,
        rootfs=components.rootfs,
        ipc=components.ipc,
        zip_packed=zip_packed,
    )
    body = io.BytesIO()
    body.write(header)
    for blob in (
        components.boot,
        components.bootarg,
        components.kernel,
        components.rootfs,
        components.ipc,
        zip_packed,
    ):
        if blob:
            body.write(blob)
    return body.getvalue()


# ---------------------------------------------------------------------------
# multipart/form-data wrapper for `upgrade.cgi`.
#
# `sub_36D64` reads the first 32 bytes of the form body (right after the
# multipart \r\n\r\n separator) as a `_DWORD v74[8]` length table, using
# v74[2..7] as component lengths. The PIHC header's first 32 bytes line up
# with that exactly (magic->v74[0], type->v74[1], six lengths->v74[2..7]), so
# the form body is simply the raw .pkg — no extra prefix. A plain
# `curl -F upload=@file.pkg` works just as well as this helper.


def build_multipart_body(
    pkg_bytes: bytes,
    *,
    filename: str = "openipc.pkg",
    boundary: str = "----coupler-camhi-boundary",
) -> tuple[bytes, str]:
    out = io.BytesIO()
    out.write(f"--{boundary}\r\n".encode())
    out.write(
        f'Content-Disposition: form-data; name="upload"; filename="{filename}"\r\n'.encode()
    )
    out.write(b"Content-Type: application/octet-stream\r\n\r\n")
    out.write(pkg_bytes)
    out.write(f"\r\n--{boundary}--\r\n".encode())
    return out.getvalue(), f"multipart/form-data; boundary={boundary}"


# ---------------------------------------------------------------------------
# CLI.


def _read_optional(path: str | None) -> bytes | None:
    return Path(path).read_bytes() if path else None


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    p.add_argument("--boot", help="boot.img (mtd0 / u-boot) — usually omitted")
    p.add_argument("--bootarg", help="bootarg.img (mtd1 / u-boot env)")
    p.add_argument("--kernel", help="kernel.img (mtd2)")
    p.add_argument("--rootfs", help="rootfs.img (mtd3 / squashfs)")
    p.add_argument("--ipc", help="ipc.img (mtd4) — usually omitted")
    p.add_argument("--zip", help="zip payload (<= 1024 bytes; default empty)")
    p.add_argument("-o", "--output", required=True)
    p.add_argument("--filename", default="openipc.pkg")
    args = p.parse_args(argv)

    components = Components(
        boot=_read_optional(args.boot),
        bootarg=_read_optional(args.bootarg),
        kernel=_read_optional(args.kernel),
        rootfs=_read_optional(args.rootfs),
        ipc=_read_optional(args.ipc),
        zip=_read_optional(args.zip),
    )
    pkg = build_pkg(components, filename=args.filename)
    Path(args.output).write_bytes(pkg)
    print(
        f"wrote {args.output} ({len(pkg)} bytes, type=4098): "
        f"boot={len(components.boot or b'')} "
        f"bootarg={len(components.bootarg or b'')} "
        f"kernel={len(components.kernel or b'')} "
        f"rootfs={len(components.rootfs or b'')} "
        f"ipc={len(components.ipc or b'')} "
        f"zip={len(components.zip or EMPTY_ZIP)}",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
