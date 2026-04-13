#!/bin/bash

MODEL=${MODEL:-TC-321N-V2}
HARDINFO=${HARDINFO:-300502}
PRODUCTMODEL=${PRODUCTMODEL:-528527}
SNS_TYPE=${SNS_TYPE:-70}
SOC=${SOC:-ssc337}
MTD0=${MTD0:-256}
MTD1=${MTD1:-4480}
MTD2=${MTD2:-3008}

HARDID="${HARDINFO:4:2}${HARDINFO:2:2}${HARDINFO:1:1}${HARDINFO:0:1}"

WORKDIR="tmp"
DLDIR="dl"
SRCDIR="in"
OUTPUTDIR="out"
BOXDATA="${WORKDIR}/new.box"
OUTPUTFILE="${4:-${MODEL}-${PRODUCTMODEL}-${SOC}.box}"
FIRMWARE=${FIRMWARE:-ssc337_lite_tiandy-tc-c321n-v2-nor.tgz}
UBOOT=${UBOOT:-u-boot-ssc337-nor.bin}

mkdir $WORKDIR $OUTPUTDIR > /dev/null 2>&1
rm ${BOXDATA} > /dev/null 2>&1

getfilesizele(){
    local filename=$1
    local filesize=$((`stat -c %s $filename` $2))
    local size=$(printf '%08x' $filesize)
    echo -ne ${size:6:2}${size:4:2}${size:2:2}${size:0:2}
}

create_prodmodule() {
prodmodule=$(cat << EOF
[start]
[mediadevice]
productmodel=${MODEL};
videoinput=1;
sensortype=${SNS_TYPE};
videooutport=1;
pinnum=0;
poutnum=0;
[end]
EOF
)

echo "$prodmodule"
}

create_box_data() {
    local FILENAME=`basename $1`

    if [ $FILENAME != "ProductModule" ]; then
        IMGFILE="$SRCDIR/${FILENAME}.img"
        LOAD_ADDR=0
        ENTRY_ADDR=${HARDID}
        mkimage -A arm -T kernel -C none -O linux -a "$LOAD_ADDR" -e "$ENTRY_ADDR" \
                -n "$FILENAME" -d $SRCDIR/${FILENAME} $IMGFILE
    else
        IMGFILE="$SRCDIR/${FILENAME}"
    fi

    filesize=$(stat -c %s "$IMGFILE")
    padding_needed=$(( (8 - (filesize % 8)) % 8 ))
    dumpsizele=$(getfilesizele $IMGFILE)

    {
        printf "%-128s" "$1" | tr ' ' '\000'
        printf "%08s" "$dumpsizele" | xxd -r -p
        printf "%08s" "$dumpsizele" | xxd -r -p
        cat ${IMGFILE}
        dd if=/dev/zero bs=1 count="$padding_needed" status=none
    } >> "${BOXDATA}"

}

# dump + cut dump
SOC=$SOC FIRMWARE=$FIRMWARE UBOOT=$UBOOT ROOTFS_A=0x350000 DUMPSIZE=0x800000 OUTPUTDIR=dumps OUTPUT=dumps/${FIRMWARE%.*}.dump ./_mkdump.sh
OUTPUT_DIR=${SRCDIR} ./_cutdump.sh dumps/${FIRMWARE%.*}.dump $MTD0 $MTD1 $MTD2

# box
create_prodmodule > $SRCDIR/ProductModule

create_box_data "/nvs/ProductModule"
create_box_data "/dev/mtdblock0"
create_box_data "/dev/mtdblock1"
create_box_data "/dev/mtdblock2"
#create_box_data "/dev/mtdblock3"

dumpsizele=$(getfilesizele $BOXDATA +40)
dumpsizenohdrle=$(getfilesizele $BOXDATA)

# make header
dd if=/dev/zero bs=40 count=1 of=${WORKDIR}/header.bin status=none
echo -n "Tiandy" | dd of=${WORKDIR}/header.bin bs=8 count=1 conv=notrunc status=none
echo -n ${dumpsizele} | xxd -r -p | dd of=${WORKDIR}/header.bin bs=1 count=3 seek=8 conv=notrunc status=none
echo -n -e "\x00\x00\x03\x00" | dd of=${WORKDIR}/header.bin bs=1 count=4 seek=12 conv=notrunc status=none
echo -n -e "\xFF\xFF\x1A\x00\x00\x00\x01\x00" | dd of=${WORKDIR}/header.bin bs=1 count=8 seek=16 conv=notrunc status=none
echo -n -e "\x52\x07\xC3\x41" | dd of=${WORKDIR}/header.bin bs=1 count=4 seek=24 conv=notrunc status=none
echo -n ${dumpsizenohdrle} | xxd -r -p | dd of=${WORKDIR}/header.bin bs=1 count=4 seek=32 conv=notrunc status=none

# append payload to header
cat ${WORKDIR}/header.bin $BOXDATA > ${OUTPUTDIR}/${OUTPUTFILE}
