#!/bin/bash

set -eu

ARCH=arm

pushd ./linux

git switch -d v5.10
git apply ../patches/linux/*.patch

make ARCH="${ARCH}" multi_v7_defconfig
make ARCH="${ARCH}" dtbs -j4

popd
