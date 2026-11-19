#!/usr/bin/env python3
"""
Rostelecom / Uniview "VideoComfort" (VC) → OpenIPC transition, via the stock
U-Boot's on-board SD-card auto-updater.

These cameras (e.g. Rostelecom IPC8232SWC-WE-B = Uniview C1L-2WN, HiSilicon
hi3516ev300 + SP2305) ship a stock U-Boot whose bootcmd, on every power-on, runs
`fwupdate mmc 0:1 ...` — it reads files named after each NAND partition from the
first FAT partition of an SD card, erases that partition and writes the file to
it, then boots. The check is magic+CRC only (no signature), so it accepts our
files.

The rootfs comes from the device-specific OpenIPC builder profile
`hi3516ev300_ultimate_rostelecom-ipc8232swc-we` (SP2305 sensor, the GPIO38
SD-slot-power fix, the LED map, RTL8188FU Wi-Fi), the U-Boot from the generic
hi3516ev300 release.

OpenIPC's NAND image is simply `U-Boot @ 0` + `rootfs.ubi @ 0x100000`. The stock
partition map is boot(1M) tech(1M) kernel(8M) app(16M) config(rest), and
tech/kernel/app are contiguous from 0x100000 — so we hand the updater:

    boot    = OpenIPC U-Boot            -> flashed at 0x000000
    tech    = rootfs.ubi[0x000000 : 0x100000]  (1 MiB)  -> 0x100000
    kernel  = rootfs.ubi[0x100000 : 0x900000]  (8 MiB)  -> 0x200000
    app     = rootfs.ubi[0x900000 : end]       (<=16MiB) -> 0xa00000

Written back-to-back from 0x100000, those three reconstruct the exact
`rootfs.ubi` at 0x100000. After the reset OpenIPC U-Boot attaches ubi0 and boots
— no UART, no network, no recovery server. Verified end-to-end on the qemu
digital twin of this camera.

The user: copy the four files to a FAT32 SD card, insert, power on, wait ~1 min,
power off, remove the card. (Keep a backup of your stock NAND first — recovery
needs UART.)

Usage:
    python3 _rostelecom2oipc.py u-boot-hi3516ev300-nand.bin rootfs.ubi.hi3516ev300 \
        --outdir out --soc hi3516ev300 \
        [--boot-size 0x100000 --tech-size 0x100000 --kernel-size 0x800000 --app-size 0x1000000]
"""
import argparse
import os
import sys


def hx(x):
    return int(x, 0)


def main():
    ap = argparse.ArgumentParser(description="Rostelecom/Uniview VC -> OpenIPC SD files")
    ap.add_argument("uboot", help="OpenIPC U-Boot (u-boot-<soc>-nand.bin)")
    ap.add_argument("rootfs_ubi", help="OpenIPC rootfs.ubi.<soc>")
    ap.add_argument("--outdir", default="out", help="output directory")
    ap.add_argument("--soc", default="hi3516ev300")
    # stock partition sizes (defaults match the IPC8232SWC-WE-B map)
    ap.add_argument("--boot-size", type=hx, default=0x100000, help="boot part size (1 MiB)")
    ap.add_argument("--tech-size", type=hx, default=0x100000, help="tech part size (1 MiB)")
    ap.add_argument("--kernel-size", type=hx, default=0x800000, help="kernel part size (8 MiB)")
    ap.add_argument("--app-size", type=hx, default=0x1000000, help="app part size (16 MiB)")
    args = ap.parse_args()

    uboot = open(args.uboot, "rb").read()
    ubi = open(args.rootfs_ubi, "rb").read()

    if len(uboot) > args.boot_size:
        sys.exit("[!] U-Boot (%d B) exceeds boot partition (%d B)" % (len(uboot), args.boot_size))

    # rootfs.ubi lives at 0x100000; split across tech|kernel|app (contiguous)
    tech_end = args.tech_size
    kernel_end = tech_end + args.kernel_size
    pieces = [
        ("boot", uboot),
        ("tech", ubi[0:tech_end]),
        ("kernel", ubi[tech_end:kernel_end]),
        ("app", ubi[kernel_end:]),
    ]
    if len(pieces[3][1]) > args.app_size:
        sys.exit("[!] rootfs.ubi too large: app slice %d B > app partition %d B "
                 "(rootfs.ubi=%d B)" % (len(pieces[3][1]), args.app_size, len(ubi)))

    os.makedirs(args.outdir, exist_ok=True)
    off = 0
    for name, data in pieces:
        path = os.path.join(args.outdir, name)
        open(path, "wb").write(data)
        nand = 0 if name == "boot" else 0x100000 + (off - args.boot_size)
        off += args.boot_size if name == "boot" else len(data)
        print("[+] %-7s %8d B -> NAND partition '%s'" % (name, len(data), name))

    # a note file so an SD card is self-describing
    readme = (
        "OpenIPC transition for a Rostelecom/Uniview VideoComfort camera (%s).\n\n"
        "1. Format an SD card as FAT32.\n"
        "2. Copy these files (boot, tech, kernel, app) to the card root.\n"
        "3. Insert the card, power the camera on, wait ~1 minute (it flashes "
        "and reboots into OpenIPC), then power off and remove the card.\n\n"
        "WARNING: this overwrites the firmware. Back up your stock NAND first — "
        "recovery requires UART. See https://openipc.org\n" % args.soc)
    open(os.path.join(args.outdir, "README.txt"), "w").write(readme)
    print("[i] wrote %s/{boot,tech,kernel,app,README.txt}" % args.outdir)


if __name__ == "__main__":
    main()
