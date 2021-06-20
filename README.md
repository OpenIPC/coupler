# Coupler
[![XM to OpenIPC](https://github.com/OpenIPC/coupler/actions/workflows/xm.yml/badge.svg)](https://github.com/OpenIPC/coupler/releases)

Releases contain automatically generated firmware files for transition from stock to [OpenIPC](https://openipc.org)

**WARNING**! Development builds! **DO NOT** flash, if you dont have required hardware or skills to do the recovery.

# Supported vendors

## XiongMai

### Device ID's:

#### Hi3516EV200 + IMX307/SC2315E
* [559A7](https://github.com/OpenIPC/coupler/releases/download/latest/000559A7_OpenIPC_HI3516EV200_50H20AI_S38_2021-06-20.bin)
* [559B0](https://github.com/OpenIPC/coupler/releases/download/latest/000559B0_OpenIPC_HI3516EV200_85H30AI_S38_2021-06-20.bin)
* [559CD](https://github.com/OpenIPC/coupler/releases/download/latest/000559CD_OpenIPC_HI3516EV200_85HF30T_S38_2021-06-20.bin)

#### Hi3516EV300 + IMX335
* [529B2](https://github.com/OpenIPC/coupler/releases/download/latest/000529B2_OpenIPC_HI3516EV300_85H50AI_2021-06-20.bin)

### Flashing
Use vendor-specific software (DeviceManager, [IPCam_DMS](https://team.openipc.org/ipcam_dms/)) or flash file via web

### Usage
After reboot camera will get IP from DHCP server, check out [project site ](https://openipc.org/firmware/) and [wiki](https://github.com/OpenIPC/openipc-2.1/wiki) for more info

### Rollback
To rollback firmware to stock, you will have to connect UART console and do TFTP recovery
