![OpenIPC Logo](https://cdn.themactep.com/images/logo_openipc.png)

# Coupler
[![XM to OpenIPC](https://github.com/OpenIPC/coupler/actions/workflows/xm.yml/badge.svg)](https://github.com/OpenIPC/coupler/releases)
![GitHub repo size](https://img.shields.io/github/repo-size/OpenIPC/coupler)
![GitHub issues](https://img.shields.io/github/issues/OpenIPC/coupler)
![GitHub pull requests](https://img.shields.io/github/issues-pr/OpenIPC/coupler)
[![License](https://img.shields.io/github/license/OpenIPC/openipc-2.1)](https://opensource.org/licenses/MIT)

Releases contain automatically generated firmware files for transition from stock to [OpenIPC](https://openipc.org)

**WARNING**! Development builds! **DO NOT** flash, if you dont have required hardware or skills to do the recovery.

# Supported vendors

## XiongMai

It's highly **recommended** to upgrade to latest available stock firmware before transition.

## Device ID's

Use vendor-specific software (DeviceManager, [IPCam_DMS](https://team.openipc.org/ipcam_dms/)) or web (Device Config->Info->Version) 
to find out "**System version**" 

For example: V5.00.R02.**000559A7**.10010.040400.0020000

## Download

### Hi3516Cv200/Hi3518Ev200
* [00018510](https://github.com/OpenIPC/coupler/releases/download/latest/00018510_OpenIPC_50H10L_S38.bin)
* [00018520](https://github.com/OpenIPC/coupler/releases/download/latest/00018520_OpenIPC_50H20L_18EV200_S38.bin)
* [00018532](https://github.com/OpenIPC/coupler/releases/download/latest/00018532_OpenIPC_53H20L_16CV200_S38.bin)

### Hi3516Cv300/Hi3516Ev100 + IMX291/IMX307/SC2235
* [00022520](https://github.com/OpenIPC/coupler/releases/download/latest/00022520_OpenIPC_50H20L.bin)
* [00031520](https://github.com/OpenIPC/coupler/releases/download/latest/00031520_OpenIPC_50H20L.bin)
* [00035520](https://github.com/OpenIPC/coupler/releases/download/latest/00035520_OpenIPC_HI3516EV100_50H20L_S38.bin)
* [000319AB](https://github.com/OpenIPC/coupler/releases/download/latest/000319AB_OpenIPC_50H20L_SG.bin)

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

### GK7205v300 + IMX335
* [000669H7](https://github.com/OpenIPC/coupler/releases/download/latest/000669H7_OpenIPC_IPC_GK7205V300_85K50T.bin)

### GK7605v100 + SC2239
* [000669HC](https://github.com/OpenIPC/coupler/releases/download/latest/000669HC_OpenIPC_IPC_GK7605V100_83K50W_S38.bin)

### XM510/XM530/XM550
**WARNING!** Manual Rollback only !
* [00023650](https://github.com/OpenIPC/coupler/releases/download/latest/00023650_OpenIPC_50X10_32M.bin)
* [00023651](https://github.com/OpenIPC/coupler/releases/download/latest/00023651_OpenIPC_53X13_32M.bin)

* [00030678](https://github.com/OpenIPC/coupler/releases/download/latest/00030678_OpenIPC_XM530_80X20_8M.bin)
* [00030679](https://github.com/OpenIPC/coupler/releases/download/latest/00030679_OpenIPC_XM530_80X50_8M.bin)
* [0003068b](https://github.com/OpenIPC/coupler/releases/download/latest/0003068b_OpenIPC_XM530_85X20_8M.bin)
* [00030695](https://github.com/OpenIPC/coupler/releases/download/latest/00030695_OpenIPC_XM530_R80X20-PQ_8M.bin)
* [000309E5](https://github.com/OpenIPC/coupler/releases/download/latest/000309E5_OpenIPC_XM530_85X20T_8M.bin)
* [000309ED](https://github.com/OpenIPC/coupler/releases/download/latest/000309ED_OpenIPC_XM530_80X30T_8M.bin)

### Hi3536CV100 / Hi3536DV100
**WARNING!** Provides linux rootfs ! Manual Rollback only !
* [00000197](https://github.com/OpenIPC/coupler/releases/download/latest/00000197_OpenIPC_NBD8008R-U.bin)
* [00000202](https://github.com/OpenIPC/coupler/releases/download/latest/00000202_OpenIPC_NBD8008R-PL.bin)

## Flashing
Use vendor-specific software (DeviceManager, [IPCam_DMS](https://team.openipc.org/ipcam_dms/)) or flash file via web

## Usage
After reboot camera will get IP from DHCP server, check out [project site ](https://openipc.org/firmware/) and [wiki](https://github.com/OpenIPC/openipc-2.1/wiki) for more info

## Rollback
To rollback firmware to stock, you will have to connect UART console and do TFTP recovery

Our [ExIPCam](https://team.openipc.org/exipcam/) software can do that in semi-automatic mode.

##### Alternative TFTP recovery:
* Setup a TFTP server
* Download appropriate recovery.img from Releases page, place it to TFTP root and rename to update.img
* ```ipctool --printenv (review serverip and ipaddr)```
###### HiSilicon
* ```ipctool --setenv bootcmd="run up && re; setenv setargs setenv bootargs \${bootargs}; run setargs; sf probe 0; sf read 0x42000000 0x50000 0x200000; bootm 0x42000000"```
* ```reboot```
###### XM530
* ```ipctool --setenv bootargs="mem=32M console=ttyAMA0,115200 root=/dev/mtdblock2 rootfstype=cramfs mtdparts=xm_sfc:256K(boot),1536K(kernel),1280K(romfs),4544K(user),256K(custom),320K(mtd)"```
* ```ipctool --setenv bootcmd="run up;sf probe 0;sf read 80007fc0 40000 180000;bootm 80007fc0" ```
* ```reboot```

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

You can make a financial contribution to the project
at [Open Collective](https://opencollective.com/openipc/contribute/backer-14335/checkout),
or via [PayPal](https://www.paypal.com/donate/?hosted_button_id=C6F7UJLA58MBS),
or via [YooMoney](https://openipc.org/donation/yoomoney.html).

Thank you.

<a href="https://opencollective.com/openipc/contribute/backer-14335/checkout" target="_blank"><img src="https://opencollective.com/webpack/donate/button@2x.png?color=blue" width="375" alt="Open Collective donate button"></a>
<a href="https://www.paypal.com/donate/?hosted_button_id=C6F7UJLA58MBS"><img src="https://www.paypalobjects.com/en_US/IT/i/btn/btn_donateCC_LG.gif" alt="PayPal donate button"></a>
<a href="https://openipc.org/donation/yoomoney.html"><img src="https://yoomoney.ru/transfer/balance-informer/balance?id=596194605&key=291C29A811B500D7" width="140" alt="YooMoney donate button"></a>
