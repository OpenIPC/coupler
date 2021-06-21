#!/bin/bash

#####
## Creates XiongMai-compatible firmware file
## Dependencies : u-boot-tools, dd, tr, zip
#####

###
TAG=$(date +"%Y-%m-%d %H:%M:%S")

KERNEL_A="${KERNEL_A:-0x50000}"
KERNEL_E="${KERNEL_E:-0x250000}"

ROOTFS_A="${ROOTFS_A:-0x250000}"
ROOTFS_E="${ROOTFS_E:-0x750000}"

HARDWARE="${HARDWARE:-HI3516EV200_85H30AI_S38}"
DEVID="${DEVID:-000559B0}"

OSMEM="${OSMEM:-32M}"
TOTALMEM="${TOTALMEM:-64M}"
SOC="${SOC:-hi3516ev200}"

FLASH_SIZE="${FLASH_SIZE:-0x800000}"
ROOTFS_DATA="${ROOTFS_DATA:-$(($FLASH_SIZE - $ROOTFS_E ))}"

WORKDIR="workdir"
OUTPUTDIR="${OUTPUTDIR:-..}"
###

IFS=" "

mkdir -p ${WORKDIR}
mkdir -p ${OUTPUTDIR}

tar -xvz -f openipc.${SOC}-br.tgz -C ${WORKDIR}/

# Check if give files exceed partition boundaries
[[ $(stat --printf="%s" ${WORKDIR}/rootfs*) -gt $(($ROOTFS_E - $ROOTFS_A)) ]] || [[ $(stat --printf="%s" ${WORKDIR}/uImage*) -gt $(($KERNEL_E - $KERNEL_A)) ]] && echo "Filesize exceeds boundaries" && exit 1

# Generate Readme
README=$(cat <<-EOF

DevID:\t\t${DEVID}
Hardware:\t${HARDWARE}
Flash:\t\t${FLASH_SIZE}
Built:\t\t${TAG}

EOF
)
echo -e ${README} > ${WORKDIR}/Readme.txt

# Generate InstallDesc
JSON=$(cat <<-EOF
{
  "UpgradeCommand": [{
      "Command":  "Burn",
      "FileName": "uImage.img"
  }, {
      "Command":  "Burn",
      "FileName": "rootfs.img"
  }, {
      "Command":  "Burn",
      "FileName": "u-boot.env.img"
  }, {
      "Command":  "Burn",
      "FileName": "mtd-x.jffs2.img"
  }],
  "SupportFlashType": [
    {
      "FlashID": "SkipCheck"
    }
  ],
  "Hardware": "${HARDWARE}",
  "DevID": "${DEVID}XXXXX000000000000",
  "CompatibleVersion" : 2,
  "Vendor": "SkipCheck"
}
EOF
)
echo ${JSON} > ${WORKDIR}/InstallDesc

# Generate U-Boot ENV
ENV=$(cat <<-EOF
bootdelay=0
baudrate=115200
ethaddr=00:00:23:34:45:66
ipaddr=192.168.1.10
serverip=192.168.1.254
netmask=255.255.0.0
gatewayip=192.168.1.1
bootfile="uImage"
da=mw.b 0x42000000 ff 1000000;tftp 0x42000000 u-boot.bin.img;sf probe 0;flwrite
de=mw.b 0x42000000 ff 1000000;tftp 0x42000000 u-boot.env.img;sf probe 0;flwrite
dl=mw.b 0x42000000 ff 1000000;tftp 0x42000000 logo-x.cramfs.img;sf probe 0;flwrite
dr=mw.b 0x42000000 ff 1000000;tftp 0x42000000 romfs-x.cramfs.img;sf probe 0;flwrite
du=mw.b 0x42000000 ff 1000000;tftp 0x42000000 user-x.cramfs.img;sf probe 0;flwrite
dc=mw.b 0x42000000 ff 1000000;tftp 0x42000000 custom-x.cramfs.img;sf probe 0;flwrite
dw=mw.b 0x42000000 ff 1000000;tftp 0x42000000 web-x.cramfs.img;sf probe 0;flwrite
dd=mw.b 0x42000000 ff 1000000;tftp 0x42000000 mtd-x.jffs2.img;sf probe 0;flwrite
up=mw.b 0x42000000 ff 1000000;tftp 0x42000000 update.img;sf probe 0;flwrite
ua=mw.b 0x42000000 ff 1000000;tftp 0x42000000 upall_verify.img;sf probe 0;flwrite
tk=tftp 0x42000000 uImage;setenv setargs setenv bootargs \${bootargs};run setargs;bootm 0x42000000
uk=mw.b 0x42000000 ff 1000000;tftp 0x42000000 uImage.\${soc} && sf probe 0;sf erase ${KERNEL_A} 0x200000; sf write 0x42000000 ${KERNEL_A} \${filesize}
ur=mw.b 0x42000000 ff 1000000;tftp 0x42000000 rootfs.squashfs.\${soc} && sf probe 0;sf erase ${ROOTFS_A} 0x500000; sf write 0x42000000 ${ROOTFS_A} \${filesize}
bootargs=mem=\${osmem:-32M} console=ttyAMA0,115200 panic=20 root=/dev/mtdblock3 rootfstype=squashfs init=/init mtdparts=hi_sfc:256k(boot),64k(wtf),2048k(kernel),5120k(rootfs),-(rootfs_data)
bootcmd=sf probe 0; sf lock 0; setenv bootcmd 'setenv setargs setenv bootargs \${bootargs}; run setargs; sf probe 0; sf read 0x42000000 ${KERNEL_A} 0x200000; bootm 0x42000000';sa;re
osmem=${OSMEM}
totalmem=${TOTALMEM}
soc=${SOC}
stdin=serial
stdout=serial
stderr=serial
verify=n

EOF
)
echo -ne ${ENV} | mkenvimage -s 0x10000 -o ${WORKDIR}/u-boot.env - &&
  mkimage -A arm -O linux -T kernel -n "uboot_env" -a 0x30000 -e 0x40000 -d ${WORKDIR}/u-boot.env ${WORKDIR}/u-boot.env.img

# Generate JFFS2 placeholder
dd if=/dev/zero count=${ROOTFS_DATA} ibs=1 | tr "\000" "\377" > ${WORKDIR}/mtd-x &&
  mkimage -A arm -O linux -T standalone -n "rootfs_data" -a ${ROOTFS_E} -e ${FLASH_SIZE} -d ${WORKDIR}/mtd-x ${WORKDIR}/mtd-x.jffs2.img

# Generate firmware file
mkimage -A arm -O linux -T kernel -n "kernel" -a ${KERNEL_A} -e ${KERNEL_E} -d ${WORKDIR}/uImage* ${WORKDIR}/uImage.img &&
mkimage -A arm -O linux -T kernel -n "rootfs" -a ${ROOTFS_A} -e ${ROOTFS_E} -d ${WORKDIR}/rootfs* ${WORKDIR}/rootfs.img &&
cd ${WORKDIR} && zip ${OUTPUTDIR}/${DEVID}_OpenIPC_${HARDWARE}.bin u-boot.env.img rootfs.img uImage.img mtd-x.jffs2.img InstallDesc Readme.txt && cd ..
rm -rf ${WORKDIR}
