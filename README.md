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

-----

### Supporting

If you like our work, please consider supporting us on [Opencollective](https://opencollective.com/openipc/contribute/backer-14335/checkout) or [PayPal](https://www.paypal.com/donate/?hosted_button_id=C6F7UJLA58MBS) or [YooMoney](https://openipc.org/donation/yoomoney.html). 

[![Backers](https://opencollective.com/openipc/tiers/backer/badge.svg?label=backer&color=brightgreen)](https://opencollective.com/openipc)
[![Backers](https://opencollective.com/openipc/tiers/badge.svg)](https://opencollective.com/openipc)

[![Backers](https://opencollective.com/openipc/tiers/backer.svg?avatarHeight=36)](https://opencollective.com/openipc#support)

### Thanks a lot !!!

<p align="center">
<a href="https://opencollective.com/openipc/contribute/backer-14335/checkout" target="_blank"><img src="https://opencollective.com/webpack/donate/button@2x.png?color=blue" width="300" alt="OpenCollective donate button" /></a>
<a href="https://www.paypal.com/donate/?hosted_button_id=C6F7UJLA58MBS"><img src="https://www.paypalobjects.com/en_US/IT/i/btn/btn_donateCC_LG.gif" alt="PayPal donate button" /> </a>
<a href="https://openipc.org/donation/yoomoney.html"><img src="https://yoomoney.ru/transfer/balance-informer/balance?id=596194605&key=291C29A811B500D7" width="100" alt="YooMoney donate button" /> </a>
</p>
