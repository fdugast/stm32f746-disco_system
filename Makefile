build_dir = build
src_dir = src
u-boot_src_dir = u-boot
u-boot_repository = git@github.com:fdugast/stm32f746-disco_u-boot.git
u-boot_bin = $(build_dir)/u-boot.bin
openocd_dir = ../openocd
linux_src_dir = linux
linux_repository = git@github.com:fdugast/stm32f746-disco_linux.git
linux_bin = $(build_dir)/kernel.uImage
linux_gz_bin = $(build_dir)/kernel.gz.uImage
config_dir = config
mkimage = $(src_dir)/$(u-boot_src_dir)/tools/mkimage
rootfs_dir = rootfs
#rootfs_files_dir = $(rootfs_dir)/files_original
rootfs_files_dir = $(rootfs_dir)/files
rootfs_img = rootfs.img
rootfs_img_gz = $(rootfs_dir)/rootfs.img.gz
rootfs_img_gz_bin = $(build_dir)/rootfs.img.gz.uImage
system_uImage = $(build_dir)/system.uImage
system_bin = $(build_dir)/system.bin
tftp_dir = /srv/tftp/stm32f7
busybox_version = 1.25.1
busybox_src_url = http://busybox.net/downloads/busybox-$(busybox_version).tar.bz2
#busybox_dir=$(rootfs_dir)/busybox-1.25.1
busybox_src_dir = busybox-$(busybox_version)
ARCH=arm
CROSS_COMPILE=arm-uclinuxeabi-
PARALLEL=-j9
CFLAGS_APP="-march=armv7-m -mtune=cortex-m4 -mlittle-endian -mthumb"

all: system_bin copy_to_tftp
	
busybox_bin:
	make -C $(src_dir)/$(busybox_src_dir) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) SKIP_STRIP=y CFLAGS=$(CFLAGS_APP) $(PARALLEL)
	cp $(src_dir)/$(busybox_src_dir)/busybox_unstripped $(rootfs_files_dir)/bin/busybox

prepare_busybox_sources: check_wget_exists
	@echo Preparing sources for busybox
	@if [ ! -d $(src_dir)/$(busybox_src_dir) ]; then \
		mkdir -p $(src_dir);\
		cd $(src_dir);\
		wget $(busybox_src_url);\
		tar jxvf busybox-$(busybox_version).tar.bz2;\
	fi

menuconfig_busybox:
	make -C $(src_dir)/$(busybox_src_dir) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) menuconfig

app: rootfs/app/app.c
	$(CROSS_COMPILE)gcc $(CFLAGS_APP) rootfs/app/app.c -o rootfs/app/app
	cp rootfs/app/app rootfs/files/bin/app

system_bin: $(linux_bin)
	dd if=/dev/zero of=$(system_bin) bs=1024k count=1
	dd if=build/u-boot.bin of=$(system_bin) conv=notrunc bs=1
	dd if=$(rootfs_img_gz_bin) of=$(system_bin) conv=notrunc bs=1 seek=98k
	dd if=$(linux_gz_bin) of=$(system_bin) conv=notrunc bs=1 seek=300k
	
system_uImage: $(linux_bin) $(rootfs_img_gz_bin)
	@echo Building $(system_uImage)
	dd if=/dev/zero of=$(system_uImage) bs=6M count=1
	dd if=$(linux_bin) of=$(system_uImage) conv=notrunc bs=1
	dd if=$(rootfs_img_gz_bin) of=$(system_uImage) conv=notrunc bs=1 seek=2M
	cp $(system_uImage) $(tftp_dir)/

$(rootfs_img_gz_bin):
	@if [ ! -d $(rootfs_files_dir) ]; then \
		echo $(rootfs_files_dir) is empty, try decompressing doc/initdir.tar there as root;\
		exit 1;\
	fi
	mkdir -p $(build_dir)
	@echo Building $(rootfs_img)
	cd $(rootfs_files_dir) && find . | cpio -o --format=newc > ../$(rootfs_img)
	@echo Building $(rootfs_img_gz)
	gzip -c $(rootfs_dir)/$(rootfs_img) > $(rootfs_img_gz)
	@echo Building $(rootfs_img_gz_bin)
	mkimage -A arm -O linux -T ramdisk -d $(rootfs_img_gz) -C gzip -a 0xc0208000 -e 0xc0208001 $(rootfs_img_gz_bin)
	
$(linux_bin): build_linux
	

build_linux: check_compiler_exists prepare_linux_sources
	@echo Building Linux
	mkdir -p $(build_dir)
	make -C $(src_dir)/$(linux_src_dir) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) $(PARALLEL) Image
	$(mkimage) -A arm -O linux -T kernel -C none -a 0xc0008000 -e 0xc0008001 -n 'Linux-uImage' -d $(src_dir)/$(linux_src_dir)/arch/arm/boot/Image $(linux_bin)
	make -C $(src_dir)/$(linux_src_dir) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) $(PARALLEL) zImage
	$(mkimage) -A arm -O linux -T kernel -C none -a 0xc0508000 -e 0xc0508001 -n 'Linux-uImage' -d $(src_dir)/$(linux_src_dir)/arch/arm/boot/zImage $(linux_gz_bin)
	cp $(linux_bin) $(tftp_dir)/

build_linux_gz: check_compiler_exists prepare_linux_sources
	@echo Building Linux
	make -C $(src_dir)/$(linux_src_dir) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) $(PARALLEL) zImage
	mkdir -p $(build_dir)
	$(mkimage) -A arm -O linux -T kernel -C gzip -a 0xc0008000 -e 0xc0008001 -n 'Linux-uImage' -d $(src_dir)/$(linux_src_dir)/arch/arm/boot/zImage $(linux_bin)

menuconfig_linux:
	make -C $(src_dir)/$(linux_src_dir) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) menuconfig

prepare_linux_sources: check_git_exists
	@echo Preparing sources for Linux
	@if [ ! -d $(src_dir)/$(linux_src_dir) ]; then \
		mkdir -p $(src_dir);\
		git clone $(linux_repository) $(src_dir)/$(linux_src_dir); \
	fi	

$(u-boot_bin): build_u-boot
	

build_u-boot: check_compiler_exists prepare_u-boot_sources
	@echo Building u-boot
	make -C $(src_dir)/$(u-boot_src_dir) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) stm32f746-discovery
	mkdir -p $(build_dir)
	cp $(src_dir)/$(u-boot_src_dir)/u-boot.bin $(u-boot_bin)

prepare_u-boot_sources: check_git_exists
	@echo Preparing sources for u-boot
	@if [ ! -d $(src_dir)/$(u-boot_src_dir) ]; then \
		mkdir -p $(src_dir);\
		git clone $(u-boot_repository) $(src_dir)/$(u-boot_src_dir); \
	fi

flash_u-boot: #$(u-boot_bin)
	cd $(openocd_dir)/openocd-stm32f7/tcl && \
		../src/openocd \
		-f board/stm32f7discovery.cfg \
		-c "program $(shell pwd)/$(u-boot_bin) 0x08000000" \
		-c "reset run" -c shutdown

flash_system: #$(u-boot_bin)
	cd $(openocd_dir)/openocd-stm32f7/tcl && \
		../src/openocd \
		-f board/stm32f7discovery.cfg \
		-c "program $(shell pwd)/$(system_bin) 0x08000000" \
		-c "reset run" -c shutdown

clean_u-boot:
	make -C $(src_dir)/$(u-boot_src_dir) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) clean

check_git_exists:
	@echo Checking if git is present in PATH
	@which git > /dev/null

check_wget_exists:
	@echo Checking if wget is present in PATH
	@which wget > /dev/null

check_compiler_exists:
	@echo Checking if compiler is present in PATH, if not get it for example from arm-2010q1-189-arm-uclinuxeabi-i686-pc-linux-gnu.tar.bz2
	@which $(CROSS_COMPILE)gcc > /dev/null

clean:
	rm -rf $(build_dir)

dist-clean: clean
	rm -rf $(src_dir)

.PHONY: 
