# Coupler
[![XM to OpenIPC](https://github.com/OpenIPC/coupler/actions/workflows/xm.yml/badge.svg)](https://github.com/OpenIPC/coupler/actions/workflows/xm.yml)

Releases contain automatically generated firmware files for transition from stock to OpenIPC

**WARNING**! Development builds! **DO NOT** flash, if you dont have required hardware or skills to do the recovery.

# Supported vendors
## XiongMai
### Device ID's:
* 559A7
* 529B2
* 559B0
* 559CD
### Flashing
Use vendor-specific software (DeviceManager, IPCam_DMS) or flash file via web
### Usage
After reboot camera will get IP from DHCP server, check out project site for [more info](https://openipc.org/firmware/)
### Rollback
To rollback firmware to stock, you will have to connect UART console and do TFTP recovery
