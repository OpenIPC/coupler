![OpenIPC Logo](https://cdn.themactep.com/images/logo_openipc.png)

# Coupler
[![XM to OpenIPC](https://github.com/OpenIPC/coupler/actions/workflows/xm.yml/badge.svg)](https://github.com/OpenIPC/coupler/releases)
![GitHub repo size](https://img.shields.io/github/repo-size/OpenIPC/coupler)
![GitHub issues](https://img.shields.io/github/issues/OpenIPC/coupler)
![GitHub pull requests](https://img.shields.io/github/issues-pr/OpenIPC/coupler)
[![License](https://img.shields.io/github/license/OpenIPC/openipc-2.1)](https://opensource.org/licenses/MIT)

Releases contain automatically generated firmware files for transition from stock to [OpenIPC](https://openipc.org)

**WARNING**! Coupler is a work-in-progress. If the firmware update fails, then it will be necessary to [to carry out a tftp recovery process](https://github.com/OpenIPC/wiki/blob/master/en/installation.md). You are **strongly advised** to **carefully** review the [recovery process documentation](https://github.com/OpenIPC/wiki/blob/master/en/installation.md) **and** check for any relevant [open issues](https://github.com/OpenIPC/coupler/issues), **before** proceeding.

# Supported vendors

# XiongMai

It's highly **recommended** to upgrade to latest available stock firmware before transition.

## Download

### Find your Device ID

You can use coupler if a coupler binary is available which matches the "**System version**" for your device.

For example a device running vendor firmware with the version "V5.00.R02.**000059A8**.10010.040400.0020000" has device ID "**000059A8**".

There are several ways to discover the vendor firmware version:

* The IPCam's built-in web interface e.g. "Device Config" → "Info" → "Version".
* The vendor's management software e.g. XiongMai's DeviceManager.
* [IPCam_DMS](https://team.openipc.org/ipcam_dms/IPCam_DMS_20201121_EN.zip) management software (Windows binaries, but also run under Wine on Linux).
* [ipctool](https://openipc.github.io/ipctool/).

Select the firmware from the download list which *exactly* matches **your** device's ID.

### Find your Image Sensor

Many firmwares in the list below are compatible with multiple different image sensor (CCD) types, and must be configured to expect a particular sensor type before images or video can be captured. You should ensure that you know the image sensor (CCD) make/model which your camera uses. This can be found using the methods listed above for determining the device ID, but is also often shown on the item description or model number (e.g. when the item is sold, or on the product packaging).

### Hi3516Cv100/Hi3518Av100/Hi3518Cv100/Hi3518Ev100 (Untested!)
* [00001510](https://github.com/OpenIPC/coupler/releases/download/latest/00001510_OpenIPC_50H10L.bin)
* [00001520](https://github.com/OpenIPC/coupler/releases/download/latest/00001520_OpenIPC_50H20L.bin)
* [00001531](https://github.com/OpenIPC/coupler/releases/download/latest/00001531_OpenIPC_53H13.bin)
* [00001532](https://github.com/OpenIPC/coupler/releases/download/latest/00001532_OpenIPC_53H20L.bin)
* [00002510](https://github.com/OpenIPC/coupler/releases/download/latest/00002510_OpenIPC_50H10L_S39.bin)
* [00002520](https://github.com/OpenIPC/coupler/releases/download/latest/00002520_OpenIPC_50H20L_S39.bin) (No sensor driver)
* [00002531](https://github.com/OpenIPC/coupler/releases/download/latest/00002531_OpenIPC_53H13_S39.bin)
* [00002532](https://github.com/OpenIPC/coupler/releases/download/latest/00002532_OpenIPC_53H20L_S39.bin) (No sensor driver)
* [00006510](https://github.com/OpenIPC/coupler/releases/download/latest/00006510_OpenIPC_HI3518E_50H10L_S39.bin)
* [00006531](https://github.com/OpenIPC/coupler/releases/download/latest/00006531_OpenIPC_HI3518E_53H13_S39.bin)

### Hi3516Cv200/Hi3518Ev200
* [00018510](https://github.com/OpenIPC/coupler/releases/download/latest/00018510_OpenIPC_50H10L_S38.bin)
* [00018520](https://github.com/OpenIPC/coupler/releases/download/latest/00018520_OpenIPC_50H20L_18EV200_S38.bin)
* [00018532](https://github.com/OpenIPC/coupler/releases/download/latest/00018532_OpenIPC_53H20L_16CV200_S38.bin)

### Hi3516Cv300/Hi3516Ev100 + IMX291/IMX307/SC2235
* [00022520](https://github.com/OpenIPC/coupler/releases/download/latest/00022520_OpenIPC_50H20L.bin)
* [00031520](https://github.com/OpenIPC/coupler/releases/download/latest/00031520_OpenIPC_50H20L.bin)
* [00035520](https://github.com/OpenIPC/coupler/releases/download/latest/00035520_OpenIPC_HI3516EV100_50H20L_S38.bin)
* [000319AB](https://github.com/OpenIPC/coupler/releases/download/latest/000319AB_OpenIPC_50H20L_SG.bin)

### Hi3516Av100/Hi3516Dv100
* [00014830](https://github.com/OpenIPC/coupler/releases/download/latest/00014830_OpenIPC_HI3516D_83H30.bin)
* [00014840](https://github.com/OpenIPC/coupler/releases/download/latest/00014840_OpenIPC_HI3516D_83H40.bin)
* [00014911](https://github.com/OpenIPC/coupler/releases/download/latest/00014911_OpenIPC_HI3516D_83H20.bin)
* [00014914](https://github.com/OpenIPC/coupler/releases/download/latest/00014914_OpenIPC_HI3516D_N81820.bin)

### Hi3516Ev200 + IMX307/SC2315E/SC2239
* [000559A7](https://github.com/OpenIPC/coupler/releases/download/latest/000559A7_OpenIPC_HI3516EV200_50H20AI_S38.bin)
* [000559B0](https://github.com/OpenIPC/coupler/releases/download/latest/000559B0_OpenIPC_HI3516EV200_85H30AI_S38.bin)
* [000559CD](https://github.com/OpenIPC/coupler/releases/download/latest/000559CD_OpenIPC_HI3516EV200_85HF30T_S38.bin)

### Hi3516Ev300 +IMX335/SC4236/SC2239
* [000529B2](https://github.com/OpenIPC/coupler/releases/download/latest/000529B2_OpenIPC_HI3516EV300_85H50AI.bin)
* [000529D9](https://github.com/OpenIPC/coupler/releases/download/latest/000529D9_OpenIPC_HI3516EV300_N80050YA.bin)
* [000529E9](https://github.com/OpenIPC/coupler/releases/download/latest/000529E9_OpenIPC_HI3516EV300_85HF50T.bin)
* [000589C9](https://github.com/OpenIPC/coupler/releases/download/latest/000589C9_OpenIPC_HI3516EV300_83H50AI_S38.bin)

### GK7205v200 + IMX307/SC2315E/SC2239
* [000659A7](https://github.com/OpenIPC/coupler/releases/download/latest/000659A7_OpenIPC_IPC_GK7205V200_50H20AI_S38.bin)
* [000659CD](https://github.com/OpenIPC/coupler/releases/download/latest/000659CD_OpenIPC_IPC_GK7205V200_85HF30T_S38.bin)
* [000659I7](https://github.com/OpenIPC/coupler/releases/download/latest/000659I7_OpenIPC_IPC_GK7205V200_85K40T_S38.bin)

### GK7205v210 + IMX307  
* [000739AG](https://github.com/OpenIPC/coupler/releases/download/latest/000739AG_OpenIPC_IPC_GK7205V200_G3S.bin)

### GK7205v300 + IMX335
* [000699H7](https://github.com/OpenIPC/coupler/releases/download/latest/000699H7_OpenIPC_IPC_GK7205V300_85K50T.bin)

### GK7605v100 + SC2239
* [000669HC](https://github.com/OpenIPC/coupler/releases/download/latest/000669HC_OpenIPC_IPC_GK7605V100_83K50W_S38.bin)

### Hi3536CV100 / Hi3536DV100
**WARNING!** Provides linux rootfs ! Manual Rollback only !
* [00000197](https://github.com/OpenIPC/coupler/releases/download/latest/00000197_OpenIPC_NBD8008R-U.bin)
* [00000202](https://github.com/OpenIPC/coupler/releases/download/latest/00000202_OpenIPC_NBD8008R-PL.bin)

## Flashing
Use vendor-specific software (e.g. XiongMai DeviceManager), [IPCam_DMS](https://team.openipc.org/ipcam_dms/IPCam_DMS_20201121_EN.zip), or the camera's built-in web server (n.b. not all vendor firmwares support browser based updates) to install the OpenIPC coupler firmware binary.

## Initial configuration
After flashing and rebooting, the camera will request an IP from a DHCP server. It will listen for web based management (e.g. http://w.x.y.z/ where the w.x.y.z is replaced with the IP address is the one that your local DHCP server has assigned), and also on ssh. After the first boot with the new firmware you need to clean the overlay partition. Run this command in your terminal window: ```firstboot``` . The coupler firmware build may not be the latest, so you may want to upgrade the firmware further at this point.

If no image is available via the web interface, then the sensor may need to be manually configured. This can be checked via ssh with `fw_printenv -n sensor`, which may respond `unknown`. On HiSilicon SoCs, a list of known sensor types can be found in the `/usr/bin/load_hisilicon` script. Once you have a matching sensor type, it can be set with e.g. `fw_setenv sensor imx291_i2c`.

## Usage
Check the main [project docs](https://openipc.org/firmware/) and [wiki](https://github.com/OpenIPC/openipc-2.1/wiki) for more info.

## Rollback
To rollback firmware to stock, you will have to connect UART console and do TFTP recovery

Our [ExIPCam](https://team.openipc.org/exipcam/) software can do that in semi-automatic mode.

##### Alternative TFTP recovery:
* Setup a TFTP server
* Make sure that the network to which the camera is connected has internet access.
* Download appropriate recovery.img file for you IPC board from Releases page/Original firmware (https://github.com/OpenIPC/coupler/releases/tag/original), place it to TFTP root folder and rename to update.img
* ```ipctool printenv (review serverip and ipaddr)```
In the output of this command, we are looking for the value "serverip" (e.g. serverip=192.168.1.254), set the received IP address on the computer with TFTP and launch the TFTP server.

###### HiSilicon
* ```ipctool``` 
This is to download the latest version of ipctool from the repository
* ```/tmp/ipctool setenv bootcmd "run up && re; setenv setargs setenv bootargs \${bootargs}; run setargs; sf probe 0; sf read 0x42000000 0x50000 0x200000; bootm 0x42000000"```
* ```reboot```

###### XM530
* ```ipctool```
This is to download the latest version of ipctool from the repository
* ```/tmp/ipctool setenv bootargs "mem=32M console=ttyAMA0,115200 root=/dev/mtdblock2 rootfstype=cramfs mtdparts=xm_sfc:256K(boot),1536K(kernel),1280K(romfs),4544K(user),256K(custom),320K(mtd)"```
* ```/tmp/ipctool setenv bootcmd "run up;sf probe 0;sf read 80007fc0 40000 180000;bootm 80007fc0" ```
* ```reboot```

# Longse/Herospeed
## WARNING! BACKUP IS MANDATORY! ROLLBACK IS NOT POSSIBLE!
## Device ID's 

Obtain stock firmware file and open it in an editor. First 8 bytes are **NAME** and next 8 bytes are **SENSOR**

For example:  ```16AV300 IMX415b```

## Flashing
Get appropriate [file for your model](https://github.com/OpenIPC/coupler/releases/tag/herospeed) and flash it via web.

-----

### Support

OpenIPC offers two levels of support.

- Free support through the community (via [chat](https://openipc.org/#telegram-chat-groups) and [mailing lists](https://github.com/OpenIPC/firmware/discussions)).
- Paid commercial support (from the team of developers).

Please consider subscribing for paid commercial support if you intend to use our product for business.
As a paid customer, you will get technical support and maintenance services directly from our skilled team.
Your bug reports and feature requests will get prioritized attention and expedited solutions. It's a win-win
strategy for both parties, that would contribute to the stability your business, and help core developers
to work on the project full-time.

If you have any specific questions concerning our project, feel free to [contact us](mailto:flyrouter@gmail.com).

### Participating and Contribution

If you like what we do, and willing to intensify the development, please consider participating.

You can improve existing code and send us patches. You can add new features missing from our code.

You can help us to write a better documentation, proofread and correct our websites.

You can just donate some money to cover the cost of development and long-term maintaining of what we believe
is going to be the most stable, flexible, and open IP Network Camera Framework for users like yourself.

You can make a financial contribution to the project at [Open Collective](https://opencollective.com/openipc/contribute/backer-14335/checkout).

Thank you.

<p align="center">
<a href="https://opencollective.com/openipc/contribute/backer-14335/checkout" target="_blank"><img src="https://opencollective.com/webpack/donate/button@2x.png?color=blue" width="375" alt="Open Collective donate button"></a>
</p>
