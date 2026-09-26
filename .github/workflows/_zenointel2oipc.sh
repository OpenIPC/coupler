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
## STATUS: scaffold. Uses the OpenIPC **gk7205v500-family NAND (ultimate)** build
## (gk7205v510 is SoC FAMILY gk7205v500 — same kernel config + osdrv, so the family
## rootfs.ubi/uImage run on v510). Blocked end-to-end only on that NAND artifact
## being published upstream (CI currently ships gk7205v500_lite NOR). Two things must
## be pinned on the bench before this is trustworthy (see docs/openipc-transition.md):
##   1. whether the stock XMedia `bootk` u-boot boots an OpenIPC kernel+rootfs
##      written to the vendor `kernel`/`root` partitions (else a u-boot swap is
##      needed and this keep-u-boot strategy does not apply);
##   2. the exact on-NAND rootfs format `burn rootfs.img rootfs` expects
##      (raw UBI image vs ubifs vs squashfs-in-UBI).
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
# RELEASE = the OpenIPC build flavour (lite/ultimate/fpv); unset => "lite" for the
# input tarball and "OpenIPC" in the output name (same convention as _xm2oipc.sh).

# ---- NAND partition map (from the stock mtdparts / the reference package's
#      uImage load/entry fields): kernel @0x240000..0x600000, root @0x600000..0x3000000
KERNEL_A="${KERNEL_A:-0x240000}"; KERNEL_E="${KERNEL_E:-0x600000}"
ROOTFS_A="${ROOTFS_A:-0x600000}"; ROOTFS_E="${ROOTFS_E:-0x3000000}"

WORKDIR="workdir"
OUTPUTDIR="${OUTPUTDIR:-..}"
mkdir -p "${WORKDIR}" "${OUTPUTDIR}"

# ---- OpenIPC payload (NAND build) --------------------------------------------
# Expected members inside openipc.<soc>-nand-<release>.tgz: uImage.<soc> and a
# NAND rootfs (ubi/ubifs) image. Adjust the rootfs glob once the upstream NAND
# artifact format is fixed.
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
