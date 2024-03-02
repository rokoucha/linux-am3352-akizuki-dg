#!/bin/bash

set -eu

BASE_IMAGE=http://os.archlinuxarm.org/os/ArchLinuxARM-am33x-latest.tar.gz
IMAGE_FILE=archlinuxarm-am3352-akizuki-dg.img

BOOT=$(mktemp -d)
ROOT=$(mktemp -d)
trap 'rm -rf $BOOT $ROOT' EXIT 1 2 3 15

BASE_IMAGE_FILE=$(mktemp)
trap 'rm -f $BASE_IMAGE_FILE' EXIT 1 2 3 15
curl -Lo "${BASE_IMAGE_FILE}" "${BASE_IMAGE}"

truncate -s 2GiB "${IMAGE_FILE}"

LOOP=$(losetup -f)
sudo losetup -P "${LOOP}" "${IMAGE_FILE}"
trap 'sudo losetup -d $LOOP' EXIT 1 2 3 15

sudo parted "${LOOP}" -s mklabel msdos -s mkpart primary fat16 0 16MiB -s set 1 boot on -s mkpart primary ext4 16MiB 100%

sudo mkfs.fat "${LOOP}p1"
sudo mkfs.ext4 -F "${LOOP}p2"

sudo mount "${LOOP}p1" "${BOOT}"
sudo mount "${LOOP}p2" "${ROOT}"
trap 'sudo umount $BOOT $ROOT' 1 2 3 15

sudo bsdtar -xpf "${BASE_IMAGE_FILE}" -C "${ROOT}"

sudo cp -a "${ROOT}/boot/zImage" "${BOOT}"
sudo rm -rf "${ROOT}/boot"

./build-linux-dtbs.sh
./build-u-boot.sh

sudo cp ./uEnv.txt ./u-boot/MLO ./u-boot/u-boot.img ./linux/arch/arm/boot/dts/am335x-akizuki-dg.dtb "${BOOT}"

sudo dd if=./u-boot/MLO of="${LOOP}" count=1 seek=1 conv=notrunc bs=128k
sudo dd if=./u-boot/u-boot.img of="${LOOP}" count=2 seek=1 conv=notrunc bs=384k

sudo umount "${BOOT}"
sudo umount "${ROOT}"

sync;sync;sync
