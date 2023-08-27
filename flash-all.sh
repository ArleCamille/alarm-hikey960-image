#!/bin/bash
echo "Flashing preliminary images..."
fastboot flash ptable prm_ptable.img
fastboot flash xloader stock-images/hisi-sec_xloader.img
fastboot reboot-bootloader

fastboot flash fastboot stock-images/l-loader.bin
fastboot flash fip stock-images/fip.bin
fastboot flash nvme stock-images/hisi-nvme.img
fastboot flash fw_lpm3   stock-images/hisi-lpm3.img
fastboot flash trustfirmware   stock-images/hisi-bl31.bin
fastboot reboot-bootloader

fastboot flash ptable prm_ptable.img
fastboot flash xloader stock-images/hisi-sec_xloader.img
fastboot flash fastboot stock-images/l-loader.bin
fastboot flash fip stock-images/fip.bin

echo "Flashing system and userspace images..."
fastboot flash boot efi.img
fastboot flash dts hi3660-hikey960.dtb.img
fastboot flash system var.simg
fastboot flash vendor boot.simg
fastboot flash userdata rootfs.simg