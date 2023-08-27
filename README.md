# Sequence
## Building the partition table
With `sgdisk` installed, run `generate-ptable.sh` with `DEVICE_TYPE` and `SECTOR_SIZE` to fit your HiKey device. Normally `DEVICE_TYPE=32g` and `SECTOR_SIZE=512` since HiKey 960 comes with a 32GB UFS storage, and it heavily relies on the sector size of 512 bytes.

This would be time-consuming because it uses `dd`, not `fallocate`. After the process, the script will output the partition table to both the console and the text file `ptable.log` for reference.

## Creating the disk image
HiKey partition layout requires many garbage partitions. Although not all of them could be salvaged, we will use at least some of them for our use.

- `boot` (the 7th partition) will be used only for EFI system partition. Its space is too limited to actually contain DTBs and GRUB modules.
- `vendor` (the 11th partition) will act as the actual boot partition.
- `system` (the 10th partition) is too small to act as the actual root, while being too large not to use. Thus we will use it as the `/var` partition.
- Obviously, `userdata` (the last partition), the largest among all the partitions, will be used as our root partition.

Therefore, according to the partition table dumped in the preceding command, create images for `boot` (ESP), `vendor` (`/boot`), `system` (`/var`) and `userdata` (root). Special care must be added for the ESP that it must be formatted with `mformat` (from `mtools`) rather than the standard `mkfs.vfat` due to its very small size. (Use `mformat -i (image name) -n 64 -h 255 -T 131072 -v "BOOT" -C`.) Format the rest of the images according to your file system of choice. (I recommend `ext4` for `/boot`.)

## Filling the partitions
Mount the disk images on an appropriate mount point. Untar a generic AArch64 Arch Linux ARM image to it. Install `qemu-user-static` and `qemu-user-static-binfmt` on the host system, and copy `qemu-aarch64-static` into `(mount point root)/usr/bin/`. You can now `arch-chroot` into the root. Populate keyrings and sync. Then remove the generic kernel (`linux-aarch64`) from the system because we will replace it with our own. Install systemd-boot to the EFI partition (`bootctl --esp-path=/efi --boot-path=/boot --no-variables install`).

## Prepare images
Convert applicable images (images with Linux filesystems like `ext4` or `btrfs`) with the tool `img2simg` included in the `android-tools` package. Then convert the DTB packed with your kernel with the command `mkdtimg`. (Usage: `mkdtimg -d[INPUT DTB] -o[OUTPUT IMAGE]`) If applicable, either modify your images' file names or the file names from `flash-all.sh`.

Alternatively, I also provide my own images as a template. As per a generic ALARM installation, you can login with `root`/`root` or `alarm`/`alarm`. It also has `wpa_supplicant` installed, but not manually enabled. `wheel` can `sudo` and `alarm` is in the `wheel` group. Pacman key population was done before, so you don't have to.

## Flashing
After all images are prepared, boot the board with the Android Fastboot mode by putting the DIP switches at the appropriate positions. (Auto Power: **ON**, Boot Mode: **OFF**, Ext Boot: **ON**) Connect with your board's serial output with your program of choice (e.g., `minicom` or `screen`) and power it on. Verify whether it outputs the fastboot message. If not, you probably have to [recover your board first](https://www.96boards.org/documentation/consumer/hikey/hikey960/installation/board-recovery.md.html).

After Fastboot is up, connect with the board's OTG slot (USB C-type) and flash with the `flash-all.sh` script. It expects the following images to be present (if unmodified):

- `efi.img` (EFI system partition; the 7th partition)
- `var.simg` (The 10th partition's image, converted to a sparse image with `img2simg`)
- `boot.simg` (The 11th partition's sparse image)
- `userdata.simg` (The last partition's sparse image)
- `hi3660-hikey960.dtb.img` (The DTB converted with `mkdtimg`)

The rest of the images are firmware ones and they are pulled from `stock-images/`. Power down the board and put the DIP to the normal boot positions. (Auto Power: **ON**, Boot Mode: **OFF**, Ext Boot: **OFF**) Power it on to check whether it boots. Depending on your use case, check whether your board outputs to serial, the monitor, or both.

Depending on the Fastboot software installed on your board, the partition table might not get properly flashed, causing potential problems. If your board requires recovery, then power the board off, put the DIP to the recovery positions (Auto Power: **ON**, Boot Mode: **ON**, Ext Boot: **OFF**), and then power it again. Then start over by running `recovery.py` instead. This will rinse the board's low level firmware and allow the partition table of the board to be flashed.