#!/bin/bash -e

#####
## Creates a fullflash dump file
## Dependencies : dd
#####

DUMPSIZE=${DUMPSIZE:-0x800000}
KERNEL_A=${KERNEL_A:-0x50000}
ROOTFS_A=${ROOTFS_A:-0x250000}

WORKDIR="workdir"
OUTPUTDIR="${OUTPUTDIR:-dumps}"

OUTPUTFILE="${OUTPUT:-${OUTPUTDIR}/openipc.${SOC}-dump.bin}"

###

mkdir -p ${WORKDIR}
mkdir -p ${OUTPUTDIR}

tar -xz -f openipc.${SOC}-br.tgz -C ${WORKDIR}/ --exclude "*.md5sum" || exit 1

# make dump image
dd if=/dev/zero bs=$((${DUMPSIZE})) count=1 status=none | tr "\000" "\377" > ${OUTPUTFILE}
dd if=u-boot-${SOC}-universal.bin of=${OUTPUTFILE} bs=$((${KERNEL_A})) conv=notrunc status=none
dd if=${WORKDIR}/uImage.${SOC} of=${OUTPUTFILE} bs=$((${KERNEL_A})) seek=1  conv=notrunc status=none
dd if=${WORKDIR}/rootfs.squashfs.${SOC} of=${OUTPUTFILE} seek=1 bs=$((${ROOTFS_A})) conv=notrunc status=none
