#!/bin/bash

set -eu

ARCH=arm
CROSS_COMPILE=arm-linux-gnueabihf-

pushd ./u-boot

git switch -d v2024.01
git apply ../patches/u-boot/*.patch

make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" distclean
make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" am335x-akiduki-dg_defconfig
make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" -j4

popd
