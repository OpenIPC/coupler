# camhi (Hi3516CV610) — engineering notes

> **Status: UNTESTED on hardware.** The container format and partition
> geometry below are reverse-engineered from the vendor `ipc_server` binary
> and read from one live reference device. The packer is unit-tested. **No
> end-to-end conversion flash has been performed.** Treat the produced `.pkg`
> as a candidate to validate on a spare unit with UART, not a finished
> product.

## Verified (vendor binary + live device, 2026-06-06)

Reference device: CamHi-app camera, web banner `Server: Hipcam`,
`getsysinfo.cgi` returns `devid="IPCAM"`, CGI prefix `/cgi-bin/hi3510/`.

* **SoC:** Hisilicon **Hi3516CV610**. Vendor MPP banner
  `HI3516CV610_MPP_V1.0.1.0 B040 Release`; loader script `load3516cv610`.
* **Kernel:** Linux 5.10.221, musl, dual ARMv7 Cortex-A7.
* **Flash:** 16 MB SPI NOR (`sfc`), 64 KB erase blocks. From `/proc/mtd` and
  `/proc/cmdline`:

  | mtd | name   | size            | offset      |
  |-----|--------|-----------------|-------------|
  | 0   | boot   | 0x030000 (192K) | 0x000000    |
  | 1   | env    | 0x010000 (64K)  | 0x030000    |
  | 2   | kernel | 0x210000 (2112K)| 0x040000    |
  | 3   | rootfs | 0x360000 (3456K)| 0x250000    |
  | 4   | ipc    | 0xA50000 (10560K)| 0x5B0000   |

* **Vendor bootargs:** `... root=/dev/mtdblock3 rootfstype=squashfs
  mtdparts=sfc:192K(boot),64K(env),2112K(kernel),3456K(rootfs),10560K(ipc)
  init=/bin/sh`. The `init=/bin/sh` is why OpenIPC needs an env override to
  `init=/init`.
* **Root filesystem:** squashfs on mtd3, mounted read-only; `df` shows it
  **100% full at 3.3 M** — i.e. almost no headroom in the 3456 K partition.
* **Upload path:** `upgrade.cgi` (admin auth) accepts the PIHC `.pkg`. The web
  realm default is `admin`/`admin` (confirmed: `getsysinfo.cgi` answered with
  those). The vendor flow is `upgrade.cgi` → in-binary decrypt+stage
  (`SysUpdateEx`) → `/mnt/mtd/ipc/upgrade` (a 9484-byte ARM ELF, not a script)
  → `/mnt/mtd/ipc/flash_upg.sh boot.img bootarg.img kernel.img rootfs.img
  ipc.img upgrade.zip`.
* **PIHC container format:** 512-byte header (`PIHC` magic 0x43484950, type
  4098, six component lengths, six `MD5(component||"IPCAM")` hex strings),
  then concatenated component bytes. Integrity is MD5-only, no signature.
  Encoded in `pihc_pack.py` with unit tests.

## Assumed / NOT verified — validate before trusting

* **That the `.pkg` flashes and boots OpenIPC.** No hardware flash done.
* **`flash_upg.sh` exact behaviour.** It is 416 bytes; we did not capture its
  contents (telnet on the reference unit was unstable). The component→mtd
  mapping (boot→mtd0 … ipc→mtd4) is inferred from the argument order and the
  staged filenames, not confirmed by reading the script.
* **Overlay partition.** The build relabels mtd4 `ipc` → `rootfs_data` in the
  new env so OpenIPC's overlay finds a writable area. Whether OpenIPC's
  `firstboot`/overlay actually adopts it (and formats the old jffs2) is
  untested.
* **rootfs fits.** OpenIPC's `hi3516cv6xx` ultimate squashfs may exceed the
  3456 K rootfs partition (the vendor's own rootfs already fills it). The
  build script aborts if it overflows; a lite build or repartition may be
  needed. OpenIPC currently publishes only the ultimate flavor for this SoC.
* **Sensor.** Unknown — `sensor.conf` on the reference unit was not read.
  No sensor is baked into the build; set it post-flash with
  `fw_setenv sensor <name>`.
* **Root shell password.** Not publicly known and not a fixed vendor default;
  obtaining a shell on a stock unit needs UART or a u-boot env override.

## Recovery

The build omits the `boot.img` component, so the vendor u-boot is preserved
and TFTP recovery via UART remains available. This is the intended safety net
while the conversion is still unverified.
