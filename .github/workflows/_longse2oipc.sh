#!/bin/bash

#####
## Creates Longse-compatible firmware file
## Dependencies : u-boot-tools, dd, tr, zip
#####

WORKDIR="workdir"
OUTPUTDIR="${OUTPUTDIR:-.}"
OUTPUTFILE="${OUTPUTDIR}/${SOC^^}_${SENSOR}_BASE_BD_W_2.2.FLS"

###

mkdir -p ${WORKDIR}
mkdir -p ${OUTPUTDIR}

# make dump image
ROOTFS_A=0x350000 DUMPSIZE=0x800000 OUTPUT=${WORKDIR}/dump.bin ./_mkdump.sh

dumpsize=$(printf '%x' `stat -c %s ${WORKDIR}/dump.bin`)
dumpsizele=$(echo -ne ${dumpsize:6:2}${dumpsize:4:2}${dumpsize:2:2}${dumpsize:0:2})

# make header
dd if=/dev/zero bs=44 count=1 of=${WORKDIR}/header.bin status=none
echo -n ${NAME} | dd of=${WORKDIR}/header.bin bs=8 count=1 conv=notrunc status=none
echo -n ${SENSOR} | dd of=${WORKDIR}/header.bin bs=8 count=1 seek=1 conv=notrunc status=none
echo -n ${dumpsizele} | xxd -r -p | dd of=${WORKDIR}/header.bin bs=1 count=3 seek=16 conv=notrunc status=none
echo -n -e "\x01" | dd of=${WORKDIR}/header.bin bs=1 count=1 seek=20 conv=notrunc status=none
echo -n "BURNER_BIN" | dd of=${WORKDIR}/header.bin bs=1 seek=24 conv=notrunc status=none

# append dump to header
cat ${WORKDIR}/header.bin ${WORKDIR}/dump.bin > ${OUTPUTFILE}