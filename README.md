# Linux on the STM32F476 Discovery board!

The [STM32F476 Discovery board](http://www.st.com/en/evaluation-tools/32f746gdiscovery.html) features a STM32F7 microcontroller based on ARM® Cortex®-M7 core with 1 MB internal flash, 64 MB SDRAM, 128 MB SPI flash, a 480 x 272 TFT display, an Ethernet connector, USB host, and more. This repository contains mainly a Makefile to build a Linux system to run on this board.

The system can be loaded over TFTP via the bootloader, or it can be flashed in the internal flash. In the later case, the kernel and root filesystem with Busybox are compressed with GZIP to fit in the tight 1 MB.

![alt text](https://github.com/fdugast/stm32f746-disco_system/blob/master/doc/stm32f746-disco_linux.png)

## How to build

Git and a compiler exported to the path are needed, such as [arm-2010q1-189-arm-uclinuxeabi-i686-pc-linux-gnu.tar.bz2](https://sourcery.mentor.com/public/gnu_toolchain/arm-uclinuxeabi/arm-2010q1-189-arm-uclinuxeabi-i686-pc-linux-gnu.tar.bz2) from Mentor Graphics.

### Bootloader

U-Boot from Emcraft Systems runs fine on this board and supports Ethernet, which helps a lot for development. The code comes from [this repository](https://github.com/fdugast/stm32f746-disco_u-boot).

Copy the U-Boot configuration into the source folder:

`$ cp config/stm32f746-discovery.h src/u-boot/include/configs/stm32f746-discovery.h`

Run:

`$ make build_u-boot`

### Kernel

µClinux from [this repository](https://github.com/fdugast/stm32f746-disco_linux) is used and supports Ethernet, the TFT display, USART, GPIOs.

Copy the Linux configuration into the source folder:

`$ cp config/linux src/linux/.config`

Run:

`$ make build_linux`

### Root file system

The file system is expected to be under `rootfs/files`. An example root file system with a precompiled Busybox can be found under `doc/initdir.tar`, thanks to https://github.com/angmouzakitis/linux-stm32f7.

To build the image with CPIO, compress it and create a RAM disk, run:

`$ make build/rootfs.img.gz.uImage`

### System image

One scenario is to build a U-Boot image containing the kernel and the root file system, which is loaded to the board over TFTP when the bootloader starts. This is more convenient for development. Run:

`$ make system_uImage`

The other scenario is to build an image ready to flash containing the bootloader, the kernel and the root file system. This scenario is for embedded systems running standalone, without the need for a PC nearby. Run:

`$ make system_bin`

## How to flash

OpenOCD is used to write to the internal flash.

In order to flash only the bootloader, for example if to load the U-Boot image over TFTP, use:

`$ make flash_u-boot`

To flash the whole system, use:

`$ make flash_system`

## How to run

When the internal flash contains the whole system, the Busybox prompt should come automatically about half a second after powering up the board.

When the internal flash contains only the bootloader, then a PC connected over Ethernet with the IP 172.17.0.1 must be serving the image `build/system.uImage` over a TFTP server.

In both cases, the U-Boot console output is sent to the USART port 6 at 115200 baud.
