#!/bin/bash -e

#####
## Creates Longse-compatible firmware file
## Dependencies : u-boot-tools, dd, tr, zip
#####

WORKDIR="workdir"
OUTPUTDIR="${OUTPUTDIR:-.}"
OUTPUTFILE="${OUTPUTDIR}/${SOC^^}_${SENSOR}_BASE_BD_W_2.2.FLS"
HEADERSIZE=44
DUMPSIZE=0x800000
FIRMWARE_A=0x50000

###

mkdir -p ${WORKDIR}
mkdir -p ${OUTPUTDIR}

# make dump image: u-boot, blank env, then kernel and rootfs back to back
# (firmware.bin from the split tarball; U-Boot finds the rootfs on its own)
tar -xz -f dl/openipc.${SOC}-nor-lite-split.tgz -C ${WORKDIR}/ --exclude "*.md5sum"
dd if=/dev/zero bs=$((DUMPSIZE)) count=1 status=none | tr "\000" "\377" > ${WORKDIR}/dump.bin
dd if=${WORKDIR}/u-boot-${SOC}-nor.bin of=${WORKDIR}/dump.bin conv=notrunc status=none
dd if=${WORKDIR}/firmware.bin.${SOC} of=${WORKDIR}/dump.bin bs=$((FIRMWARE_A)) seek=1 conv=notrunc status=none

# stock firmware rejects the file unless this field equals the whole file size
filesize=$(( $(stat -c %s ${WORKDIR}/dump.bin) + HEADERSIZE ))
filesizele=$(printf '%08x' ${filesize} | sed -E 's/(..)(..)(..)(..)/\4\3\2\1/')

# make header
dd if=/dev/zero bs=${HEADERSIZE} count=1 of=${WORKDIR}/header.bin status=none
echo -n ${NAME} | dd of=${WORKDIR}/header.bin bs=8 count=1 conv=notrunc status=none
echo -n ${SENSOR} | dd of=${WORKDIR}/header.bin bs=8 count=1 seek=1 conv=notrunc status=none
echo -n ${filesizele} | xxd -r -p | dd of=${WORKDIR}/header.bin bs=1 count=4 seek=16 conv=notrunc status=none
echo -n -e "\x01" | dd of=${WORKDIR}/header.bin bs=1 count=1 seek=20 conv=notrunc status=none
echo -n "BURNER_BIN" | dd of=${WORKDIR}/header.bin bs=1 seek=24 conv=notrunc status=none

# append dump to header
cat ${WORKDIR}/header.bin ${WORKDIR}/dump.bin > ${OUTPUTFILE}