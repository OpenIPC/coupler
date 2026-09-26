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
# Members inside openipc.<soc>-nand-<release>.tgz: uImage.<soc> (the OpenIPC
# kernel uImage) and rootfs.ubi (UBIFS-in-UBI). Both were flashed and booted on a
# GK7205V510; the globs below match them.
tar -xvz -f "openipc.${FAMILY}-nand-${RELEASE:-ultimate}.tgz" -C "${WORKDIR}/" --exclude "*.md5sum" || {
  echo "Error: openipc.${FAMILY}-nand-*.tgz not found — upstream NAND artifact missing (see header)"; exit 1; }

# ---- wrap kernel + rootfs as vendor-style uImages (load/entry = partition bounds)
mkimage -A arm -O linux -T kernel -n "kernel" -a "${KERNEL_A}" -e "${KERNEL_E}" \
        -d "${WORKDIR}"/uImage* "${WORKDIR}/kernel.img"
ROOTFS_SRC=$(ls "${WORKDIR}"/rootfs* 2>/dev/null | head -1)
[ -n "${ROOTFS_SRC}" ] || { echo "Error: no rootfs* in the OpenIPC tarball"; exit 1; }
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
