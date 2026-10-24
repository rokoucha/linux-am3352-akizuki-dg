#!/bin/bash

set -eu

BASE_IMAGE=http://os.archlinuxarm.org/os/ArchLinuxARM-am33x-latest.tar.gz
IMAGE_FILE=archlinuxarm-am3352-akizuki-dg.img

ROOT=$(mktemp -d)
trap 'rm -rf $ROOT' EXIT 1 2 3 15

BASE_IMAGE_FILE=$(mktemp)
trap 'rm -f $BASE_IMAGE_FILE' EXIT 1 2 3 15
curl -Lo "${BASE_IMAGE_FILE}" "${BASE_IMAGE}"

truncate -s 2GiB "${IMAGE_FILE}"

LOOP=$(losetup -f)
sudo losetup -P "${LOOP}" "${IMAGE_FILE}"
trap 'sudo losetup -d $LOOP' EXIT 1 2 3 15

# Keep the first partition clear of the raw MLO (128KiB) and u-boot.img (384KiB-1152KiB)
sudo parted "${LOOP}" -s mklabel msdos -s mkpart primary fat16 4MiB 16MiB -s set 1 boot on -s mkpart primary ext4 16MiB 100%

sudo mkfs.fat "${LOOP}p1"
sudo mkfs.ext4 -F "${LOOP}p2"

sudo mount "${LOOP}p2" "${ROOT}"
trap 'sudo umount -R $ROOT' 1 2 3 15

sudo bsdtar -xpf "${BASE_IMAGE_FILE}" -C "${ROOT}"

sudo mkdir -p "${ROOT}/boot/uboot"
sudo mount "${LOOP}p1" "${ROOT}/boot/uboot"
echo "UUID=$(sudo blkid -s UUID -o value "${LOOP}p1") /boot/uboot vfat defaults,nofail 0 2" | sudo tee -a "${ROOT}/etc/fstab"

# The SD/eMMC controller driver is a module, so the initramfs must carry it (needs qemu-arm binfmt)
sudo sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 sdhci-omap)/' "${ROOT}/etc/mkinitcpio.conf"
sudo arch-chroot "${ROOT}" mkinitcpio -P

./build-linux-dtbs.sh
./build-u-boot.sh

sudo cp ./linux/arch/arm/boot/dts/ti/omap/am335x-akizuki-dg.dtb "${ROOT}/boot"
sudo cp ./uEnv.txt ./u-boot/MLO ./u-boot/u-boot.img "${ROOT}/boot/uboot"

sudo dd if=./u-boot/MLO of="${LOOP}" count=1 seek=1 conv=notrunc bs=128k
sudo dd if=./u-boot/u-boot.img of="${LOOP}" count=2 seek=1 conv=notrunc bs=384k

sudo umount -R "${ROOT}"

sync;sync;sync
