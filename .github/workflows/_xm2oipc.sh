#!/bin/bash

#####
## Creates XiongMai-compatible firmware file
## Dependencies : u-boot-tools, dd, tr, zip
#####

###
TAG=$(date +"%Y-%m-%d %H:%M:%S")

ENV_A="0x30000"
ENV_E="0x40000"

KERNEL_A="${KERNEL_A:-0x50000}"
KERNEL_E="${KERNEL_E:-0x250000}"

ROOTFS_A="${ROOTFS_A:-0x250000}"
ROOTFS_E="${ROOTFS_E:-0x750000}"

HARDWARE="${HARDWARE:-HI3516EV200_85H30AI_S38}"
DEVID="${DEVID:-000559B0}"
COMPAT="${COMPAT:-2}"

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
  "HardWareVersion": 1,
  "DevID": "${DEVID}XXXXX000000000000",
  "CompatibleVersion" : ${COMPAT},
  "Vendor": "SkipCheck"
}
EOF
)
echo ${JSON} > ${WORKDIR}/InstallDesc

# Generate U-Boot ENV
ENV_hi3518ev200=$(cat <<-EOF
bootcmd=sf probe 0; sf lock 0; setenv bootcmd 'setenv setargs setenv bootargs \${bootargs}; run setargs; sf probe 0; sf read 0x82000000 ${KERNEL_A} 0x200000; bootm 0x82000000';sa;re
bootdelay=1
baudrate=115200
bootfile="uImage"
da=mw.b 0x82000000 ff 1000000;tftp 0x82000000 u-boot.bin.img;sf probe 0;flwrite
du=mw.b 0x82000000 ff 1000000;tftp 0x82000000 user-x.cramfs.img;sf probe 0;flwrite
dr=mw.b 0x82000000 ff 1000000;tftp 0x82000000 romfs-x.cramfs.img;sf probe 0;flwrite
dw=mw.b 0x82000000 ff 1000000;tftp 0x82000000 web-x.cramfs.img;sf probe 0;flwrite
dl=mw.b 0x82000000 ff 1000000;tftp 0x82000000 logo-x.cramfs.img;sf probe 0;flwrite
dc=mw.b 0x82000000 ff 1000000;tftp 0x82000000 custom-x.cramfs.img;sf probe 0;flwrite
up=mw.b 0x82000000 ff 1000000;tftp 0x82000000 update.img;sf probe 0;flwrite
ua=mw.b 0x82000000 ff 1000000;tftp 0x82000000 upall_verify.img;sf probe 0;flwrite
tk=mw.b 0x82000000 ff 1000000;tftp 0x82000000 uImage; bootm 0x82000000
uk=mw.b 0x82000000 ff 1000000;tftp 0x82000000 uImage.\${soc} && sf probe 0;sf erase ${KERNEL_A} 0x200000; sf write 0x82000000 ${KERNEL_A} \${filesize}
ur=mw.b 0x82000000 ff 1000000;tftp 0x82000000 rootfs.squashfs.\${soc} && sf probe 0;sf erase ${ROOTFS_A} 0x500000; sf write 0x82000000 ${ROOTFS_A} \${filesize}
dd=mw.b 0x82000000 ff 1000000;tftp 0x82000000 mtd-x.jffs2.img;sf probe 0;flwrite
ipaddr=192.168.1.10
serverip=192.168.1.254
netmask=255.255.255.0
gatewayip=192.168.1.1
ethaddr=00:0b:3f:00:00:01
bootargs=mem=\${osmem:-32M} console=ttyAMA0,115200 panic=20 root=/dev/mtdblock3 rootfstype=squashfs init=/init mtdparts=hi_sfc:256k(boot),64k(wtf),2048k(kernel),5120k(rootfs),-(rootfs_data)
osmem=${OSMEM}
totalmem=${TOTALMEM}
soc=${SOC}
stdin=serial
stdout=serial
stderr=serial
verify=n

EOF
)

ENV_hi3516cv300=$(cat <<-EOF
bootcmd=sf probe 0; sf lock 0; setenv bootcmd 'setenv setargs setenv bootargs \${bootargs}; run setargs; sf probe 0; sf read 0x82000000 ${KERNEL_A} 0x200000; bootm 0x82000000';sa;re
bootdelay=1
baudrate=115200
ethaddr=00:00:23:34:45:66
ipaddr=192.168.1.10
serverip=192.168.1.254
netmask=255.255.0.0
gatewayip=192.168.1.1
bootfile="uImage"
da=mw.b 0x82000000 ff 1000000;tftp 0x82000000 u-boot.bin.img;sf probe 0;flwrite
du=mw.b 0x82000000 ff 1000000;tftp 0x82000000 user-x.cramfs.img;sf probe 0;flwrite
dr=mw.b 0x82000000 ff 1000000;tftp 0x82000000 romfs-x.cramfs.img;sf probe 0;flwrite
dw=mw.b 0x82000000 ff 1000000;tftp 0x82000000 web-x.cramfs.img;sf probe 0;flwrite
dl=mw.b 0x82000000 ff 1000000;tftp 0x82000000 logo-x.cramfs.img;sf probe 0;flwrite
dc=mw.b 0x82000000 ff 1000000;tftp 0x82000000 custom-x.cramfs.img;sf probe 0;flwrite
up=mw.b 0x82000000 ff 1000000;tftp 0x82000000 update.img;sf probe 0;flwrite
ua=mw.b 0x82000000 ff 1000000;tftp 0x82000000 upall_verify.img;sf probe 0;flwrite
tk=tftp 0x82000000 uImage;setenv setargs setenv bootargs ${bootargs};run setargs;bootm 0x82000000
uk=mw.b 0x82000000 ff 1000000;tftp 0x82000000 uImage.\${soc} && sf probe 0;sf erase ${KERNEL_A} 0x200000; sf write 0x82000000 ${KERNEL_A} \${filesize}
ur=mw.b 0x82000000 ff 1000000;tftp 0x82000000 rootfs.squashfs.\${soc} && sf probe 0;sf erase ${ROOTFS_A} 0x500000; sf write 0x82000000 ${ROOTFS_A} \${filesize}
dd=mw.b 0x82000000 ff 1000000;tftp 0x82000000 mtd-x.jffs2.img;sf probe 0;flwrite
bootargs=mem=\${osmem:-32M} console=ttyAMA0,115200 panic=20 root=/dev/mtdblock3 rootfstype=squashfs init=/init mtdparts=hi_sfc:256k(boot),64k(wtf),2048k(kernel),5120k(rootfs),-(rootfs_data)
osmem=${OSMEM}
totalmem=${TOTALMEM}
soc=${SOC}
stdin=serial
stdout=serial
stderr=serial
verify=n

EOF
)

ENV_hi3516dv100=$(cat <<-EOF
bootdelay=0
baudrate=115200
mdio_intf=rmii
ethaddr=00:00:23:34:45:66
ipaddr=192.168.1.10
serverip=192.168.1.254
netmask=255.255.0.0
gatewayip=192.168.1.1
bootfile="uImage"
da=mw.b 0x82000000 ff 1000000;tftp 0x82000000 u-boot.bin.img;sf probe 0;flwrite
du=mw.b 0x82000000 ff 1000000;tftp 0x82000000 user-x.cramfs.img;sf probe 0;flwrite
dr=mw.b 0x82000000 ff 1000000;tftp 0x82000000 romfs-x.cramfs.img;sf probe 0;flwrite
dw=mw.b 0x82000000 ff 1000000;tftp 0x82000000 web-x.cramfs.img;sf probe 0;flwrite
dl=mw.b 0x82000000 ff 1000000;tftp 0x82000000 logo-x.cramfs.img;sf probe 0;flwrite
dc=mw.b 0x82000000 ff 1000000;tftp 0x82000000 custom-x.cramfs.img;sf probe 0;flwrite
up=mw.b 0x82000000 ff 1000000;tftp 0x82000000 update.img;sf probe 0;flwrite
tk=mw.b 0x82000000 ff 1000000;tftp 0x82000000 uImage.img; bootm 0x82000000
dd=mw.b 0x82000000 ff 1000000;tftp 0x82000000 mtd-x.jffs2.img;sf probe 0;flwrite
de=mw.b 0x82000000 ff 1000000;tftp 0x82000000 u-boot.env.bin.img;sf probe 0;flwrite
uk=mw.b 0x82000000 ff 1000000;tftp 0x82000000 uImage.${SOC} && sf probe 0;sf erase ${KERNEL_A} 0x200000; sf write 0x82000000 ${KERNEL_A} \${filesize}
ur=mw.b 0x82000000 ff 1000000;tftp 0x82000000 rootfs.squashfs.${SOC} && sf probe 0;sf erase ${ROOTFS_A} 0x500000; sf write 0x82000000 ${ROOTFS_A} \${filesize}
bootargs=mem=${TOTALMEM} console=ttyAMA0,115200 panic=20 root=/dev/mtdblock3 rootfstype=squashfs init=/init mtdparts=hi_sfc:256k(boot),256k(env),2048k(kernel),5120k(rootfs),-(rootfs_data)
bootcmd=sf probe 0; sf lock 0; setenv bootcmd 'sf probe 0; sf read 0x82000000 ${KERNEL_A} 0x200000; bootm 0x82000000';sa;re
muxctl0=0x200f0080
muxval0=0
gpio0=0x94
gpioval0=0x0
osmem=${OSMEM}
totalmem=${TOTALMEM}
soc=${SOC}
stdin=serial
stdout=serial
stderr=serial
verify=n

EOF
)

ENV_hi3516ev200=$(cat <<-EOF
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

ENV_hi3536dv100=$(cat <<-EOF
bootdelay=0
baudrate=115200
ethaddr=00:00:23:34:45:66
ipaddr=192.168.1.10
serverip=192.168.1.254
netmask=255.255.0.0
gatewayip=192.168.1.1
bootfile="uImage"
da=mw.b 0x82000000 ff 1000000;tftp 0x82000000 u-boot.bin.img;sf probe 0;flwrite
du=mw.b 0x82000000 ff 1000000;tftp 0x82000000 user-x.cramfs.img;sf probe 0;flwrite
dr=mw.b 0x82000000 ff 1000000;tftp 0x82000000 romfs-x.cramfs.img;sf probe 0;flwrite
dw=mw.b 0x82000000 ff 1000000;tftp 0x82000000 web-x.cramfs.img;sf probe 0;flwrite
dl=mw.b 0x82000000 ff 1000000;tftp 0x82000000 logo-x.cramfs.img;sf probe 0;flwrite
dc=mw.b 0x82000000 ff 1000000;tftp 0x82000000 custom-x.cramfs.img;sf probe 0;flwrite
up=mw.b 0x82000000 ff 1000000;tftp 0x82000000 update.img;sf probe 0;flwrite
tk=mw.b 0x82000000 ff 1000000;tftp 0x82000000 zImage.img; bootm 0x82000000
dd=mw.b 0x82000000 ff 1000000;tftp 0x82000000 mtd-x.jffs2.img;sf probe 0;flwrite
de=mw.b 0x82000000 ff 1000000;tftp 0x82000000 u-boot.env.bin.img;sf probe 0;flwrite
uk=mw.b 0x82000000 ff 1000000;tftp 0x82000000 uImage.${SOC} && sf probe 0;sf erase ${KERNEL_A} 0x200000; sf write 0x82000000 ${KERNEL_A} \${filesize}
ur=mw.b 0x82000000 ff 1000000;tftp 0x82000000 rootfs.squashfs.${SOC} && sf probe 0;sf erase ${ROOTFS_A} 0x500000; sf write 0x82000000 ${ROOTFS_A} \${filesize}
bootargs=mem=${TOTALMEM} console=ttyAMA0,115200 panic=20 root=/dev/mtdblock3 rootfstype=squashfs init=/init mtdparts=hi_sfc:256k(boot),64k(env),2048k(kernel),5120k(rootfs),-(rootfs_data)
bootcmd=sf probe 0; sf lock 0; setenv bootcmd 'sf probe 0; sf read 0x82000000 ${KERNEL_A} 0x200000; bootm 0x82000000';sa;re
osmem=${OSMEM}
totalmem=${TOTALMEM}
soc=${SOC}
stdin=serial
stdout=serial
stderr=serial
verify=n

EOF
)

ENV_gk7205v200=$(cat <<-EOF
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
bootargs=mem=\${osmem:-32M} console=ttyAMA0,115200 panic=20 root=/dev/mtdblock3 rootfstype=squashfs init=/init mtdparts=sfc:256k(boot),64k(wtf),2048k(kernel),5120k(rootfs),-(rootfs_data)
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

ENV_nt98562=$(cat <<-EOF
arch=arm
baudrate=115200
board=nvt-na51055
board_name=nvt-na51055
bootdelay=0
cpu=armv7
ethaddr=00:00:23:34:45:66
eth1addr=00:00:23:34:45:77
ethprime=eth0
fdt_high=0x04000000
gatewayip=192.168.1.1
hostname=oaalnx
ipaddr=192.168.1.10
netmask=255.255.255.0
serverip=192.168.1.254
ld=mw.b 0x01000000 ff 100000;tftpboot 0x01000000 loader.bin.img;flwrite
df=mw.b 0x01000000 ff 100000;tftpboot 0x01000000 fdt.bin.img;flwrite
da=mw.b 0x01000000 ff 0x800000;tftpboot 0x01000000 u-boot.bin.img;sf probe 0;flwrite
de=mw.b 0x01000000 ff 0x800000;tftpboot 0x01000000 u-boot.env.img;sf probe 0;flwrite
dl=mw.b 0x01000000 ff 0x800000;tftpboot 0x01000000 logo-x.squashfs.img;sf probe 0;flwrite
dr=mw.b 0x01000000 ff 0x800000;tftpboot 0x01000000 romfs-x.squashfs.img;sf probe 0;flwrite
du=mw.b 0x01000000 ff 0x800000;tftpboot 0x01000000 user-x.squashfs.img;sf probe 0;flwrite
dc=mw.b 0x01000000 ff 0x800000;tftpboot 0x01000000 custom-x.squashfs.img;sf probe 0;flwrite
dw=mw.b 0x01000000 ff 0x800000;tftpboot 0x01000000 web-x.squashfs.img;sf probe 0;flwrite
dd=mw.b 0x01000000 ff 0x800000;tftpboot 0x01000000 mtd-x.jffs2.img;sf probe 0;flwrite
up=mw.b 0x01000000 ff 0x800000;tftpboot 0x01000000 update.img;sf probe 0;flwrite
ua=mw.b 0x01000000 ff 0x800000;tftpboot 0x01000000 upall_verify.img;sf probe 0;flwrite
tk=tftpboot 0x01000000 uImage;setenv setargs setenv bootargs ${bootargs};run setargs;nvt_boot 0x01000000
loadlogo=sf probe 0;sf read 0x02000000  ;logoload 0x02000000;decjpg 0;bootlogo
loadromfs=sf probe 0;sf read 0x02000000 0x40000 0x2E0000;squashfsload;nvt_boot
uk=mw.b 0x01000000 ff 1000000;tftp 0x01000000 uImage.\${soc} && sf probe 0;sf erase ${KERNEL_A} 0x200000; sf write 0x01000000 ${KERNEL_A} \${filesize}
ur=mw.b 0x01000000 ff 1000000;tftp 0x01000000 rootfs.squashfs.\${soc} && sf probe 0;sf erase ${ROOTFS_A} 0x500000; sf write 0x01000000 ${ROOTFS_A} \${filesize}
bootcmd=sf probe 0; sf lock 0; setenv bootcmd 'setenv setargs setenv bootargs \${bootargs}; run setargs; sf probe 0; sf read 0x03500000 ${KERNEL_A} 0x200000; nvt_boot';sa;re
bootargs=earlyprintk console=ttyS0,115200 mem=\${osmem:-32M} panic=20 nprofile_irq_duration=on root=/dev/mtdblock3 rootfstype=squashfs init=/init mtdparts=spi_nor.0:64k(loader),256k(boot),2048k(kernel),5120k(rootfs),-(rootfs_data)
osmem=${OSMEM}
totalmem=${TOTALMEM}
soc=${SOC}
stderr=ns16550_serial
stdin=ns16550_serial
stdout=ns16550_serial
vendor=novatek

EOF
)

ENV_xm530=$(cat <<-EOF
bootcmd=sf probe 0; sf read 0x80007fc0 0x50000 0x200000; bootm 0x80007fc0
bootdelay=1
baudrate=115200
cramfsaddr=0x60040000
da=mw.b 0x81000000 ff 800000;tftp 0x81000000 u-boot.bin.img;sf probe 0;flwrite
du=mw.b 0x81000000 ff 800000;tftp 0x81000000 user-x.cramfs.img;sf probe 0;flwrite
dr=mw.b 0x81000000 ff 800000;tftp 0x81000000 romfs-x.cramfs.img;sf probe 0;flwrite
dw=mw.b 0x81000000 ff 800000;tftp 0x81000000 web-x.cramfs.img;sf probe 0;flwrite
dc=mw.b 0x81000000 ff 800000;tftp 0x81000000 custom-x.cramfs.img;sf probe 0;flwrite
up=mw.b 0x81000000 ff 800000;tftp 0x81000000 update.img;sf probe 0;flwrite
ua=mw.b 0x81000000 ff 800000;tftp 0x81000000 upall_verify.img;sf probe 0;flwrite
tk=mw.b 0x81000000 ff 800000;tftp 0x81000000 uImage; bootm 0x81000000
dd=mw.b 0x81000000 ff 800000;tftp 0x81000000 mtd-x.jffs2.img;sf probe 0;flwrite
uk=mw.b 0x81000000 ff 1000000;tftp 0x81000000 uImage.${SOC};sf probe 0;sf erase ${KERNEL_A} 0x200000; sf write 0x81000000 ${KERNEL_A} \${filesize}
ur=mw.b 0x81000000 ff 1000000;tftp 0x81000000 rootfs.squashfs.${SOC};sf probe 0;sf erase ${ROOTFS_A} 0x500000; sf write 0x81000000 ${ROOTFS_A} \${filesize}
ipaddr=192.168.1.10
serverip=192.168.1.254
netmask=255.255.0.0
gatewayip=192.168.1.1
ethact=dwmac.10010000
ethaddr=00:00:23:34:45:66
bootargs=mem=${OSMEM} console=ttyAMA0,115200 panic=20 root=/dev/mtdblock3 rootfstype=squashfs init=/init mtdparts=xm_sfc:256k(boot),64k(env),2048k(kernel),5120k(rootfs),-(rootfs_data)
osmem=${OSMEM}
totalmem=${TOTALMEM}
soc=${SOC}
stdin=serial
stdout=serial
stderr=serial
verify=n

EOF
)

ENV_xm510=$(cat <<-EOF
bootcmd=sf probe 0; sf read 0x80007fc0 0x50000 0x200000; bootm 0x80007fc0
bootdelay=1
baudrate=115200
cramfsaddr=0x60040000
da=mw.b 0x81000000 ff 800000;tftp 0x81000000 u-boot.bin.img;sf probe 0;flwrite
du=mw.b 0x81000000 ff 800000;tftp 0x81000000 user-x.cramfs.img;sf probe 0;flwrite
dr=mw.b 0x81000000 ff 800000;tftp 0x81000000 romfs-x.cramfs.img;sf probe 0;flwrite
dw=mw.b 0x81000000 ff 800000;tftp 0x81000000 web-x.cramfs.img;sf probe 0;flwrite
dc=mw.b 0x81000000 ff 800000;tftp 0x81000000 custom-x.cramfs.img;sf probe 0;flwrite
up=mw.b 0x81000000 ff 800000;tftp 0x81000000 update.img;sf probe 0;flwrite
ua=mw.b 0x81000000 ff 800000;tftp 0x81000000 upall_verify.img;sf probe 0;flwrite
tk=mw.b 0x81000000 ff 800000;tftp 0x81000000 uImage; bootm 0x81000000
dd=mw.b 0x81000000 ff 800000;tftp 0x81000000 mtd-x.jffs2.img;sf probe 0;flwrite
uk=mw.b 0x81000000 ff 800000;tftp 0x81000000 uImage.${SOC};sf probe 0;sf erase ${KERNEL_A} 0x200000; sf write 0x81000000 ${KERNEL_A} \${filesize}
ur=mw.b 0x81000000 ff 800000;tftp 0x81000000 rootfs.squashfs.${SOC};sf probe 0;sf erase ${ROOTFS_A} 0x500000; sf write 0x81000000 ${ROOTFS_A} \${filesize}
ipaddr=192.168.1.10
serverip=192.168.1.254
netmask=255.255.0.0
gatewayip=192.168.1.1
ethaddr=00:00:23:34:45:66
bootargs=mem=18M console=ttyAMA0,115200 panic=20 root=/dev/mtdblock3 rootfstype=squashfs init=/init mtdparts=xm_sfc:256k(boot),64k(env),2048k(kernel),5120k(rootfs),-(rootfs_data)
osmem=18M
totalmem=${TOTALMEM}
soc=${SOC}
stdin=serial
stdout=serial
stderr=serial
verify=n

EOF
)

case $SOC in
  *"xm530"*)
    ENV=${ENV_xm530}
    ;;
  *"xm510"*)
    ENV=${ENV_xm510}
    ;;
  *"hi3516dv100"*)
    ENV_A="0x40000"
    ENV_E="0x80000"
    KERNEL_A="0x80000"
    KERNEL_E="0x280000"
    ROOTFS_A="0x280000"
    ROOTFS_E="0x780000"
    ENVSIZE="0x40000"
    ENV=${ENV_hi3536dv100}
    ;;
  *"hi3516ev"*)
    ENV=${ENV_hi3516ev200}
    ;;
  *"hi3516cv200"*)
    ENV=${ENV_hi3518ev200}
    ;;
  *"hi3516cv300"*)
    ENV_A="0x20000"
    ENV_E="0x30000"
    ENV=${ENV_hi3516cv300}
    ;;
  *"hi3516ev100"*)
    ENV_A="0x20000"
    ENV_E="0x30000"
    ENV=${ENV_hi3516cv300}
    ;;
  *"hi3518ev200"*)
    ENV=${ENV_hi3518ev200}
    ;;
  *"hi3536cv100"*)
    ENV_A="0x40000"
    ENV_E="0x50000"
    ENV=${ENV_hi3536dv100}
    ;;
  *"hi3536dv100"*)
    ENV_A="0x40000"
    ENV_E="0x50000"
    ENV=${ENV_hi3536dv100}
    ;;
  *"gk7205v"*)
    ENV=${ENV_gk7205v200}
    ;;
  *"gk7605v"*)
    ENV=${ENV_gk7205v200}
    ;;
  *"nt98562"*)
    ENV=${ENV_nt98562}
    ;;
esac

echo -ne ${ENV} | mkenvimage -s ${ENVSIZE:-0x10000} -o ${WORKDIR}/u-boot.env - &&
  mkimage -A arm -O linux -T kernel -n "uboot_env" -a ${ENV_A} -e ${ENV_E} -d ${WORKDIR}/u-boot.env ${WORKDIR}/u-boot.env.img

# Generate JFFS2 placeholder
dd if=/dev/zero count=${ROOTFS_DATA} ibs=1 | tr "\000" "\377" > ${WORKDIR}/mtd-x &&
  mkimage -A arm -O linux -T standalone -n "rootfs_data" -a ${ROOTFS_E} -e ${FLASH_SIZE} -d ${WORKDIR}/mtd-x ${WORKDIR}/mtd-x.jffs2.img

# Generate firmware file
mkimage -A arm -O linux -T kernel -n "kernel" -a ${KERNEL_A} -e ${KERNEL_E} -d ${WORKDIR}/uImage* ${WORKDIR}/uImage.img &&
mkimage -A arm -O linux -T kernel -n "rootfs" -a ${ROOTFS_A} -e ${ROOTFS_E} -d ${WORKDIR}/rootfs* ${WORKDIR}/rootfs.img &&
cd ${WORKDIR} && zip ${OUTPUTDIR}/${DEVID}_OpenIPC_${HARDWARE}.bin u-boot.env.img rootfs.img uImage.img mtd-x.jffs2.img InstallDesc Readme.txt && cd ..
rm -rf ${WORKDIR}
