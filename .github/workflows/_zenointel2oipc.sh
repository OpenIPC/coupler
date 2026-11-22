#!/bin/bash

#####
## Creates a Zenointel / GK7205 "hunter" (Dahua-derived) upgrade package that
## flashes OpenIPC over the vendor's own firmware-update path (DHIP :5000 web
## upgrader.cgi / RPC upgrader.*), WITHOUT touching u-boot — mirroring the
## XiongMai `_xm2oipc.sh` approach (stock bootloader kept => always recoverable).
##
## Container = a Dahua "zzip": a normal DEFLATE ZIP whose first local-file-header
## signature is mangled PK\x03\x04 -> ZL\x03\x04, holding uImage-wrapped
## partition images + an `Install` JSON descriptor. Integrity is CRC-32 only
## (no signature); the camera gates on Cpu + Vendor + the Devices allow-list.
## Reference package: the vendor's `…OIPC_UBOOT.bin`; verify with the zenointel
## project's tools/zzip.py.
##
## Dependencies: u-boot-tools (mkimage), zip, dd, python3 (json only).
##
## STATUS: VALIDATED on hardware. This script's output was flashed over DHIP with
## python-dhip onto a GK7205V510 SD-2N-4G and booted OpenIPC keeping stock u-boot
## (see the zenointel project's docs/openipc-transition.md). Uses the OpenIPC
## **gk7205v500-family NAND (ultimate)** build (gk7205v510 is SoC FAMILY gk7205v500 —
## same kernel config + osdrv, so the family rootfs.ubi/uImage run on v510).
## Confirmed on the bench: (1) the stock XMedia `bootk` u-boot boots the OpenIPC
## kernel+rootfs written to the vendor `kernel`/`root` partitions (no u-boot swap
## needed); (2) the on-NAND rootfs is UBIFS in a UBI volume `rootfs` (OpenIPC
## rootfs.ubi) — matches the stock cmdLine. The only remaining gap is upstream CI:
## the gk7205v500-family NAND-ultimate artifact is not published yet (CI ships only
## gk7205v500_lite NOR), so build it locally with `make BOARD=gk7205v500_ultimate`.
#####

set -e

# ---- target identity (the DEVID analogue is Cpu + Vendor + model/hw-version) ---
SOC="${SOC:-gk7205v510}"
FAMILY="${FAMILY:-gk7205v500}"       # OpenIPC SoC FAMILY — gk7205v510 is family gk7205v500,
                                     #   so the NAND artifact is the shared family build.
CPU="${CPU:-GK7205V510}"                 # Install "Cpu" gate (SoC string)
VENDOR="${VENDOR:-Rostelecom}"           # Install "Vendor" gate — MUST match the
                                         #   unit's OEM (e.g. Rostelecom); there is
                                         #   no XiongMai-style "SkipCheck" here.
MODEL="${MODEL:-NC-IPTC2200_DL_4G-4}"    # Install "Devices" model
HWVER="${HWVER:-2.00}"                    # Install "Devices" hardware version
# RELEASE = the OpenIPC build flavour (lite/ultimate/fpv); unset => "ultimate" for
# the input tarball and "OpenIPC" in the output name (same convention as _xm2oipc.sh).

# ---- NAND partition map (from the stock mtdparts / the reference package's
#      uImage load/entry fields): kernel @0x240000..0x600000, root @0x600000..0x3000000
KERNEL_A="${KERNEL_A:-0x240000}"; KERNEL_E="${KERNEL_E:-0x600000}"
ROOTFS_A="${ROOTFS_A:-0x600000}"; ROOTFS_E="${ROOTFS_E:-0x3000000}"

WORKDIR="workdir"
OUTPUTDIR="${OUTPUTDIR:-..}"
mkdir -p "${WORKDIR}" "${OUTPUTDIR}"
# Absolutise: the ZIP is created from inside WORKDIR (subshell cd) but dd mangles
# it from the original cwd — a relative OUTPUTDIR (e.g. the default "..") would
# resolve to two different files and the build would fail.
OUTPUTDIR="$(cd "${OUTPUTDIR}" && pwd)"

# ---- OpenIPC payload (NAND build) --------------------------------------------
# Two artifact generations are supported:
#   * OLD (<= 2026-09, validated on hardware): openipc.<family>-nand-<release>.tgz
#     containing a ready-made legacy uImage.<soc> + rootfs.ubi.
#   * NEW (>= 2026-11 nightlies, OpenIPC/builder first-class devices): the tgz is
#     named per model (e.g. gk7205v510_ultimate_zenointel-sd-2n-4g-nand.tgz, pass
#     ARTIFACT=<file>) and ships fitImage.<family> (FDT, d00dfeed) instead of the
#     legacy uImage. The stock XMedia `bootk` REJECTS FIT at bootm (validated on
#     the QEMU twin: "Bad FIT kernel image format!" -> U-Boot prompt, i.e. a
#     fleet brick), and hunter's `burn` requires every member to be a legacy
#     uImage whose load/entry equal the target partition bounds -- so the kernel
#     member is rebuilt here: zImage + fdt are extracted from the fitImage,
#     concatenated (gk7205v500 kernels are CONFIG_ARM_APPENDED_DTB=y: the zImage
#     decompressor finds the appended dtb) and wrapped via mkimage.
#     Twin-validated end-to-end 2026-11-22: this burn + boot chain reaches
#     "Welcome to OpenIPC".
# Both generations also burn rootfs.ubi (UBIFS-in-UBI; NOT rootfs.ubifs).
ARTIFACT="${ARTIFACT:-openipc.${FAMILY}-nand-${RELEASE:-ultimate}.tgz}"
tar -xvz -f "${ARTIFACT}" -C "${WORKDIR}/" --exclude "*.md5sum" || {
  echo "Error: ${ARTIFACT} not found -- upstream NAND artifact missing (see header)"; exit 1; }

# ---- kernel member: legacy uImage (the outer wrap below only re-headers it) ---
if ls "${WORKDIR}"/uImage* >/dev/null 2>&1; then
  KERN_SRC=$(ls "${WORKDIR}"/uImage* | head -1)
elif ls "${WORKDIR}"/fitImage* >/dev/null 2>&1; then
  FIT=$(ls "${WORKDIR}"/fitImage* | head -1)
  python3 - "$FIT" "${WORKDIR}/zImage" "${WORKDIR}/board.dtb" <<'PY'
import struct, sys
fit, zpath, dpath = sys.argv[1:4]
f = open(fit, "rb").read()
magic, total, off_struct, off_strings = struct.unpack(">IIII", f[:16])
assert magic == 0xD00DFEED, "not a FIT"
def u32(o): return struct.unpack(">I", f[o:o+4])[0]
def cstr(o):
    e = f.index(b"\x00", o); return f[o:e].decode()
def node(o):
    props, kids = {}, {}
    while True:
        t = u32(o)
        if t == 4: o += 4; continue                     # NOP
        if t == 1:                                      # BEGIN_NODE
            n = cstr(o+4); o = (o+4+len(n)+1+3) & ~3
            k, o = node(o); kids[n] = k
        elif t == 3:                                    # PROP (v16: no trailing pad)
            ln, no = u32(o+4), u32(o+8)
            props[cstr(off_strings+no)] = f[o+12:o+12+ln]; o = (o+12+ln+3) & ~3
        else:                                           # END_NODE / END
            return (props, kids), o+4
    assert False
assert u32(off_struct) == 1
rn = cstr(off_struct+4); o = (off_struct+4+len(rn)+1+3) & ~3
tree, _ = node(o)
img = tree[1]["images"][1]        # -> {"kernel": (props,kids), "fdt": (props,kids)}
open(zpath, "wb").write(img["kernel"][0]["data"])
open(dpath, "wb").write(img["fdt"][0]["data"])
PY
  cat "${WORKDIR}/zImage" "${WORKDIR}/board.dtb" > "${WORKDIR}/inner-kernel.bin"
  mkimage -A arm -O linux -T kernel -C none -n "OpenIPC ${SOC}" \
          -a 0x40008000 -e 0x40008000 -d "${WORKDIR}/inner-kernel.bin" \
          "${WORKDIR}/uImage.${SOC}"
  KERN_SRC="${WORKDIR}/uImage.${SOC}"
else
  echo "Error: neither uImage* nor fitImage* in ${ARTIFACT}"; exit 1
fi

# ---- rootfs member: rootfs.ubi (UBI image), never the bare *.ubifs blob -------
# NB: a plain `rootfs*` glob also matches rootfs.ubifs, and under en_* locale
# collation `rootfs.ubi*` can even list it FIRST (dots ignored: "ubifs" sorts
# before "ubi.g") -- burning the bare UBIFS blob yields an unbootable root.
ROOTFS_SRC=$(ls -1 "${WORKDIR}"/rootfs.ubi "${WORKDIR}"/rootfs.ubi.* 2>/dev/null | head -1)
[ -n "${ROOTFS_SRC}" ] || { echo "Error: no rootfs.ubi in ${ARTIFACT}"; exit 1; }

# ---- wrap kernel + rootfs as vendor-style uImages (load/entry = partition bounds)
mkimage -A arm -O linux -T kernel -n "kernel" -a "${KERNEL_A}" -e "${KERNEL_E}" \
        -d "${KERN_SRC}" "${WORKDIR}/kernel.img"
mkimage -A arm -O linux -T filesystem -n "rootfs" -a "${ROOTFS_A}" -e "${ROOTFS_E}" \
        -d "${ROOTFS_SRC}" "${WORKDIR}/rootfs.img"

# ---- Install descriptor: OpenIPC kernel + rootfs ONLY (u-boot kept) ----------
python3 - "$CPU" "$VENDOR" "$MODEL" "$HWVER" > "${WORKDIR}/Install" <<'PY'
import json, sys
cpu, vendor, model, hwver = sys.argv[1:5]
print(json.dumps({
    "Cpu": cpu,
    "Commands": ["burn kernel.img kernel", "burn rootfs.img rootfs"],
    "Vendor": vendor,
    "Devices": [[model, hwver]],
}, separators=(",", ":")))
PY

# ---- pack: zip, then mangle the first local header PK -> ZL (the "zzip" marker)
OUT="${OUTPUTDIR}/${MODEL}_${RELEASE:-OpenIPC}_${SOC}.bin"
rm -f "${OUT}"
( cd "${WORKDIR}" && zip -X -q "${OUT}" kernel.img rootfs.img Install )
printf '\x5a\x4c' | dd of="${OUT}" bs=1 count=2 conv=notrunc status=none   # PK->ZL @0
echo "wrote ${OUT}"

rm -rf "${WORKDIR}"
