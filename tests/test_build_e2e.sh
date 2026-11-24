#!/bin/bash
#
# End-to-end smoke test for the camhi build pipeline. Synthesises a fake
# OpenIPC release tarball, runs _camhi2oipc.sh against it, and validates the
# produced .pkg (magic, type, component layout, MD5+"IPCAM" checksums, and the
# critical u-boot env changes). Uses the pure-Python uboot_env.py fallback, so
# it needs no u-boot-tools. Exits non-zero on any failure.
#
# Run: bash tests/test_build_e2e.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="${REPO_ROOT}/.github/workflows/_camhi2oipc.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

# --- synthesise a fake OpenIPC hi3516cv6xx release tarball -----------------
mkdir -p "${TMP}/staging"
{ printf 'FAKE-UIMAGE'; dd if=/dev/zero bs=1024 count=8 2>/dev/null; } > "${TMP}/staging/uImage.hi3516cv6xx"
{ printf 'FAKE-ROOTFS'; dd if=/dev/zero bs=1024 count=12 2>/dev/null; } > "${TMP}/staging/rootfs.squashfs.hi3516cv6xx"
tar -czf "${TMP}/openipc.hi3516cv6xx-nor-ultimate.tgz" -C "${TMP}/staging" .

# --- run the build ---------------------------------------------------------
OUTPUTDIR="${TMP}/out" \
WORKDIR="${TMP}/work" \
TARBALL="${TMP}/openipc.hi3516cv6xx-nor-ultimate.tgz" \
SOC=hi3516cv6xx RELEASE=ultimate HARDWARE=CAMHI_CV610 \
  bash "${BUILD}"

PKG="${TMP}/out/openipc.hi3516cv6xx.CAMHI_CV610.pkg"
[ -f "${PKG}" ] || { echo "FAIL: .pkg not produced"; exit 1; }

# --- validate the produced .pkg --------------------------------------------
python3 - "${PKG}" <<'PY'
import struct, hashlib, sys
d = open(sys.argv[1], "rb").read()

assert d[:4] == b"PIHC", f"bad magic {d[:4]!r}"
typ = struct.unpack("<I", d[4:8])[0]
assert typ == 4098, f"bad type {typ}"

lens = struct.unpack("<6I", d[8:32])  # boot,bootarg,kernel,rootfs,ipc,zip
assert lens[0] == 0, "boot.img should be omitted (preserve vendor u-boot)"
assert lens[4] == 0, "ipc.img should be omitted"
assert lens[1] == 65536, f"bootarg should be 64K env, got {lens[1]}"
assert lens[2] == 2162688, f"kernel should pad to 2112K, got {lens[2]}"
assert lens[3] == 3538944, f"rootfs should pad to 3456K, got {lens[3]}"
assert lens[5] == 22, f"zip should be the 22-byte empty zip, got {lens[5]}"
assert 512 + sum(lens) == len(d), "header+components != file size"

cursor = 512
md5_off = {"bootarg": 112, "kernel": 152, "rootfs": 192, "zip": 272}
for label, blen in zip(
    ["boot", "bootarg", "kernel", "rootfs", "ipc", "zip"], lens
):
    if blen == 0:
        continue
    payload = d[cursor : cursor + blen]
    cursor += blen
    off = md5_off[label]
    want = d[off : off + 40].rstrip(b"\x00").decode()
    got = hashlib.md5(payload + b"IPCAM").hexdigest()
    assert want == got, f"{label}: header md5 {want} != computed {got}"

# bootarg env must switch init and relabel the overlay partition
ba = d[512 : 512 + lens[1]]
body = ba[4:].rstrip(b"\xff").rstrip(b"\x00")
entries = [e.decode(errors="replace") for e in body.split(b"\x00") if e]
bootargs = next(e for e in entries if e.startswith("bootargs="))
assert "init=/init" in bootargs, "bootargs must set init=/init"
assert "init=/bin/sh" not in bootargs, "vendor init=/bin/sh must be gone"
assert "rootfs_data" in bootargs, "overlay partition must be relabelled rootfs_data"

print("e2e: PIHC .pkg structurally valid, checksums match, env corrected")
PY

echo "test_build_e2e: PASS"
