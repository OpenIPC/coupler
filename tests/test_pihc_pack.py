"""
Self-tests for `pihc_pack.py`. Mirror the validation logic the vendor
`ipc_server` applies in `sub_36A70` (header verifier).

Run standalone (no third-party deps):

    python3 tests/test_pihc_pack.py
"""

import hashlib
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / ".github" / "workflows"))

import pihc_pack as p


# --- md5_ipcam_digest (sub_1CA00) ------------------------------------------


def test_md5_ipcam_empty_input():
    assert p.md5_ipcam_digest(b"") == hashlib.md5(b"IPCAM").hexdigest()


def test_md5_ipcam_known_input():
    assert p.md5_ipcam_digest(b"hello") == hashlib.md5(b"helloIPCAM").hexdigest()


# --- PK signature mangle (sub_37EA4) ---------------------------------------


def test_pk_mangle_local_file_header():
    assert p.apply_pk_mangle(b"PK\x03\x04abc") == b"PK\x03\x07abc"


def test_pk_mangle_central_directory():
    assert p.apply_pk_mangle(b"PK\x01\x02xy") == b"PK\x01\x08xy"


def test_pk_mangle_eocd():
    assert p.apply_pk_mangle(b"PK\x05\x06zz") == b"PK\x05\x09zz"


def test_pk_mangle_leaves_unrelated_bytes_alone():
    assert p.apply_pk_mangle(b"hello world") == b"hello world"


def test_pk_mangle_partial_match_untouched():
    assert p.apply_pk_mangle(b"PK\x03\x99") == b"PK\x03\x99"


def test_pk_mangle_overlapping_occurrences():
    assert p.apply_pk_mangle(b"PK\x03\x04PK\x01\x02") == b"PK\x03\x07PK\x01\x08"


def test_empty_zip_after_mangle_is_eocd_plus_three():
    packed = p.pack_zip_component(p.EMPTY_ZIP)
    assert packed[:4] == b"PK\x05\x09"
    assert packed[4:] == b"\x00" * 18


# --- header construction (sub_36A70) ---------------------------------------


def _parse_header(header: bytes) -> dict:
    assert len(header) == p.HEADER_SIZE

    def cstr(off: int, n: int) -> str:
        end = header.find(b"\x00", off, off + n)
        end = off + n if end < 0 else end
        return header[off:end].decode("ascii")

    return {
        "magic": struct.unpack_from("<I", header, p.OFF_MAGIC)[0],
        "type": struct.unpack_from("<I", header, p.OFF_TYPE)[0],
        "len_boot": struct.unpack_from("<I", header, p.OFF_LEN_BOOT)[0],
        "len_bootarg": struct.unpack_from("<I", header, p.OFF_LEN_BOOTARG)[0],
        "len_kernel": struct.unpack_from("<I", header, p.OFF_LEN_KERNEL)[0],
        "len_rootfs": struct.unpack_from("<I", header, p.OFF_LEN_ROOTFS)[0],
        "len_ipc": struct.unpack_from("<I", header, p.OFF_LEN_IPC)[0],
        "len_zip": struct.unpack_from("<I", header, p.OFF_LEN_ZIP)[0],
        "filename": cstr(p.OFF_FILENAME, 40),
        "md5_bootarg": cstr(p.OFF_MD5_BOOTARG, 40),
        "md5_kernel": cstr(p.OFF_MD5_KERNEL, 40),
        "md5_rootfs": cstr(p.OFF_MD5_ROOTFS, 40),
        "md5_zip": cstr(p.OFF_MD5_ZIP, 40),
    }


def test_header_magic_is_pihc_le():
    pkg = p.build_pkg(p.Components(), filename="x.pkg")
    parsed = _parse_header(pkg[: p.HEADER_SIZE])
    assert parsed["magic"] == p.PIHC_MAGIC
    assert pkg[0:4] == b"PIHC"


def test_header_type_is_4098():
    parsed = _parse_header(p.build_pkg(p.Components())[: p.HEADER_SIZE])
    assert parsed["type"] == 4098


def test_header_records_lengths_and_zero_for_missing():
    pkg = p.build_pkg(p.Components(kernel=b"\xab" * 100, rootfs=b"\xcd" * 200))
    parsed = _parse_header(pkg[: p.HEADER_SIZE])
    assert parsed["len_boot"] == 0
    assert parsed["len_bootarg"] == 0
    assert parsed["len_kernel"] == 100
    assert parsed["len_rootfs"] == 200
    assert parsed["len_ipc"] == 0
    assert parsed["len_zip"] == len(p.EMPTY_ZIP)


def test_header_md5_is_md5_of_bytes_plus_ipcam():
    kernel = b"some-kernel-bytes"
    parsed = _parse_header(p.build_pkg(p.Components(kernel=kernel))[: p.HEADER_SIZE])
    assert parsed["md5_kernel"] == hashlib.md5(kernel + b"IPCAM").hexdigest()


def test_header_md5_zip_is_over_mangled_bytes():
    parsed = _parse_header(p.build_pkg(p.Components())[: p.HEADER_SIZE])
    expected = hashlib.md5(p.apply_pk_mangle(p.EMPTY_ZIP) + b"IPCAM").hexdigest()
    assert parsed["md5_zip"] == expected


def test_header_filename_stamped():
    parsed = _parse_header(p.build_pkg(p.Components(), filename="openipc.pkg")[: p.HEADER_SIZE])
    assert parsed["filename"] == "openipc.pkg"


# --- body layout (sub_36D64 / sub_37EA4 streaming reader) ------------------


def test_body_starts_at_512_with_first_component():
    boot = b"BOOT" + b"\x11" * 60
    pkg = p.build_pkg(p.Components(boot=boot))
    assert pkg[p.HEADER_SIZE : p.HEADER_SIZE + len(boot)] == boot


def test_components_concatenated_in_declared_order():
    boot, bootarg, kernel, rootfs, ipc = (
        b"B" * 10,
        b"E" * 20,
        b"K" * 30,
        b"R" * 40,
        b"I" * 50,
    )
    pkg = p.build_pkg(
        p.Components(boot=boot, bootarg=bootarg, kernel=kernel, rootfs=rootfs, ipc=ipc)
    )
    cursor = p.HEADER_SIZE
    for expected in (boot, bootarg, kernel, rootfs, ipc):
        assert pkg[cursor : cursor + len(expected)] == expected
        cursor += len(expected)
    assert pkg[cursor : cursor + 22] == p.apply_pk_mangle(p.EMPTY_ZIP)


def test_zip_over_one_chunk_rejected_until_cipher_lands():
    try:
        p.build_pkg(p.Components(zip=b"\x00" * (p.HICHIP_CHUNK + 1)))
    except NotImplementedError as e:
        assert "cipher" in str(e) or "no-cipher" in str(e)
        return
    raise AssertionError("expected NotImplementedError for >1024-byte zip")


# --- multipart wrapper (sub_36D64 form parser) -----------------------------


def test_multipart_body_is_raw_pkg_with_header_as_v74():
    boot, kernel = b"B" * 7, b"K" * 13
    pkg = p.build_pkg(p.Components(boot=boot, kernel=kernel))
    body, ctype = p.build_multipart_body(pkg)
    assert ctype.startswith("multipart/form-data; boundary=")
    sep = body.find(b"\r\n\r\n")
    assert sep != -1
    after = body[sep + 4 : sep + 4 + 32]
    assert after == pkg[:32]  # PIHC header's first 32 bytes == receiver's v74[8]
    fields = struct.unpack("<8I", after)
    assert fields[0] == p.PIHC_MAGIC  # v74[0] unused by receiver
    assert fields[1] == p.TYPE_UPGRADE  # v74[1] unused by receiver
    assert fields[2] == 7  # boot
    assert fields[3] == 0  # bootarg
    assert fields[4] == 13  # kernel
    assert fields[5] == 0  # rootfs
    assert fields[6] == 0  # ipc
    assert fields[7] == len(p.apply_pk_mangle(p.EMPTY_ZIP))  # zip
    assert body[sep + 4 + len(pkg) :].startswith(b"\r\n--")


# --- runner ----------------------------------------------------------------


def _run() -> int:
    import traceback

    tests = [(n, g) for n, g in globals().items() if n.startswith("test_") and callable(g)]
    failed = 0
    for name, fn in sorted(tests):
        try:
            fn()
            print(f"PASS {name}")
        except Exception as e:  # noqa: BLE001
            print(f"FAIL {name}: {e}")
            traceback.print_exc()
            failed += 1
    print(f"\n{len(tests) - failed} passed, {failed} failed (of {len(tests)})")
    return failed


if __name__ == "__main__":
    sys.exit(_run())
