#!/bin/bash

#####
## Build a PIHC-format firmware that the camhi (Hi3516CV610) vendor's
## `upgrade.cgi` admin endpoint accepts as a normal firmware update.
##
## STATUS: UNTESTED ON HARDWARE. The container format is reverse-engineered
## and the packer is unit-tested, but no end-to-end flash has been performed.
## See camhi-NOTES.md for what is verified vs assumed.
##
## Inputs (env vars):
##   SOC      — OpenIPC SoC tag (default hi3516cv6xx — the only Hi3516CV610
##              build OpenIPC currently publishes).
##   RELEASE  — OpenIPC flavor (default ultimate; lite is not published for
##              this SoC, and may be required if rootfs does not fit — see the
##              size check below).
##   HARDWARE — Hardware name stamped into u-boot env (cosmetic).
##   OSMEM    — kernel "mem=" value (default 46400KB — the vendor's own value).
##   TOTALMEM — totalmem env (default 64M).
##
## Dependencies: u-boot-tools (mkenvimage) OR the bundled uboot_env.py fallback;
##               python3 (>= 3.8); tar.
#####

set -euo pipefail

SOC="${SOC:-hi3516cv6xx}"
RELEASE="${RELEASE:-ultimate}"
HARDWARE="${HARDWARE:-CAMHI_CV610}"
OSMEM="${OSMEM:-46400KB}"
TOTALMEM="${TOTALMEM:-64M}"

WORKDIR="${WORKDIR:-workdir}"
OUTPUTDIR="${OUTPUTDIR:-..}"
TARBALL="${TARBALL:-openipc.${SOC}-nor-${RELEASE}.tgz}"
HERE="$(cd "$(dirname "$0")" && pwd)"

# Partition geometry for the Hi3516CV610 camhi reference device. Verified from
# the live device on 2026-06-06 (/proc/mtd + /proc/cmdline):
#   mtdparts=sfc:192K(boot),64K(env),2112K(kernel),3456K(rootfs),10560K(ipc)
# 16 MB SPI NOR, 64 KB erase blocks.
ADDR_KERNEL_START="0x00040000"
ADDR_ROOTFS_START="0x00250000"
ENV_SIZE="0x10000"                                 # 64 KB env partition (mtd1)
KERNEL_PART_SIZE=$((0x250000 - 0x40000))           # 2,162,688 bytes (mtd2)
ROOTFS_PART_SIZE=$((0x5B0000 - 0x250000))          # 3,538,944 bytes (mtd3)

mkdir -p "${WORKDIR}" "${OUTPUTDIR}"

tar -xvz -f "${TARBALL}" -C "${WORKDIR}/" --exclude "*.md5sum" || {
    echo "Error: cannot untar ${TARBALL}." >&2
    exit 1
}

KERNEL_SRC=$(ls "${WORKDIR}"/uImage* 2>/dev/null | head -n1 || true)
ROOTFS_SRC=$(ls "${WORKDIR}"/rootfs.squashfs* 2>/dev/null | head -n1 || true)
[[ -z "${KERNEL_SRC}" || -z "${ROOTFS_SRC}" ]] && {
    echo "Error: ${TARBALL} missing uImage* or rootfs.squashfs*." >&2
    exit 1
}

# Size guard. The reference vendor rootfs already fills the 3456 KB partition
# (df reported /dev/root 3.3M used 3.3M 100%), so OpenIPC's squashfs has very
# little headroom here. If the ultimate build overflows, a lite build or a
# repartition is required — fail loudly rather than produce a brick.
KERNEL_SIZE=$(wc -c <"${KERNEL_SRC}")
ROOTFS_SIZE=$(wc -c <"${ROOTFS_SRC}")
if (( KERNEL_SIZE > KERNEL_PART_SIZE )); then
    echo "Error: kernel ${KERNEL_SIZE} > kernel partition ${KERNEL_PART_SIZE}." >&2
    exit 1
fi
if (( ROOTFS_SIZE > ROOTFS_PART_SIZE )); then
    echo "Error: rootfs ${ROOTFS_SIZE} > rootfs partition ${ROOTFS_PART_SIZE}." >&2
    echo "       Try RELEASE=lite, or repartition (out of scope for this build)." >&2
    exit 1
fi

# u-boot env (flashed to mtd1). Two deliberate changes from the vendor env
# (verified vendor /proc/cmdline shown for reference):
#   1. init=/bin/sh  ->  init=/init   (OpenIPC runs /init as PID 1)
#   2. last partition renamed "ipc" -> "rootfs_data" so OpenIPC's overlay
#      mechanism finds a writable data partition where it expects one. The
#      offset/size are unchanged; only the mtdparts label differs. OpenIPC's
#      `firstboot` is expected to format this overlay on first boot. UNTESTED.
# Everything else (mem, console, mtdparts geometry) is kept as the vendor set
# it, to stay in a configuration the SoC is known to boot.
cat >"${WORKDIR}/u-boot.env.txt" <<EOF
bootdelay=1
baudrate=115200
bootcmd=sf probe 0; sf read 0x42000000 ${ADDR_KERNEL_START} 0x200000; bootm 0x42000000
bootargs=mem=${OSMEM} earlycon=pl011,0x11040000 console=ttyAMA0,115200 panic=20 rw root=/dev/mtdblock3 rootfstype=squashfs init=/init mtdparts=sfc:192K(boot),64K(env),2112K(kernel),3456K(rootfs),10560K(rootfs_data)
osmem=${OSMEM}
totalmem=${TOTALMEM}
soc=${SOC}
hardware=${HARDWARE}
stdin=serial
stdout=serial
stderr=serial
EOF

if command -v mkenvimage >/dev/null 2>&1; then
    mkenvimage -s "${ENV_SIZE}" -o "${WORKDIR}/bootarg.img" "${WORKDIR}/u-boot.env.txt"
else
    python3 "${HERE}/uboot_env.py" -s "${ENV_SIZE}" -o "${WORKDIR}/bootarg.img" "${WORKDIR}/u-boot.env.txt"
fi

# Pad kernel/rootfs to their partition sizes with 0xFF (NOR erased state).
# LC_ALL=C forces tr into byte mode; without it the macOS BSD tr treats 0xFF
# as a multibyte UTF-8 sequence and doubles the output.
pad_to() {
    local src="$1" dst="$2" size="$3" cur need
    cur=$(wc -c <"${src}")
    cp "${src}" "${dst}"
    if (( cur < size )); then
        need=$((size - cur))
        dd if=/dev/zero bs=1 count="${need}" 2>/dev/null | LC_ALL=C tr '\000' '\377' >>"${dst}"
    fi
}
pad_to "${KERNEL_SRC}" "${WORKDIR}/kernel.img" "${KERNEL_PART_SIZE}"
pad_to "${ROOTFS_SRC}" "${WORKDIR}/rootfs.img" "${ROOTFS_PART_SIZE}"

# boot.img is intentionally omitted: leaving the vendor u-boot in place keeps
# TFTP recovery available if the conversion goes wrong.
# ipc.img is intentionally omitted: the vendor app store (mtd4) is not written;
# OpenIPC reformats that space as its overlay on first boot.
# upgrade.zip stays empty (pihc_pack.py supplies a 22-byte EOCD-only ZIP,
# below the 1024-byte Hichip-cipher threshold).

OUTPUT="${OUTPUTDIR}/openipc.${SOC}.${HARDWARE}.pkg"
python3 "${HERE}/pihc_pack.py" \
    --bootarg "${WORKDIR}/bootarg.img" \
    --kernel  "${WORKDIR}/kernel.img" \
    --rootfs  "${WORKDIR}/rootfs.img" \
    --filename "openipc.pkg" \
    -o "${OUTPUT}"

echo "Built ${OUTPUT}"
ls -la "${OUTPUT}"
