# Môi trường build arm64 native (Apple Silicon) cho kernel + rootfs Pixel 3 XL
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential gcc bc bison flex libssl-dev libelf-dev libncurses-dev \
      cpio kmod rsync git ca-certificates curl wget xz-utils zstd lz4 gzip unzip file \
      python3 python3-pip pipx device-tree-compiler \
      b4 mkbootimg android-sdk-libsparse-utils \
      debootstrap e2fsprogs dosfstools fdisk util-linux \
      busybox-static \
      meson ninja-build pkg-config libqrtr-dev libzstd-dev liblzma-dev \
 && rm -rf /var/lib/apt/lists/*
RUN git config --system user.name "pixel-builder" \
 && git config --system user.email "builder@localhost" \
 && git config --system --add safe.directory '*'
# mkbootimg của gói Ubuntu noble thiếu module python 'gki' (lỗi đóng gói) -> dùng bản AOSP, ghim tag
ARG MKBOOTIMG_TAG=android-15.0.0_r1
RUN mkdir -p /opt/mkbootimg \
 && curl -fsSL "https://android.googlesource.com/platform/system/tools/mkbootimg/+archive/refs/tags/${MKBOOTIMG_TAG}.tar.gz" \
    | tar -xz -C /opt/mkbootimg \
 && ln -sf /opt/mkbootimg/mkbootimg.py /usr/local/bin/mkbootimg \
 && ln -sf /opt/mkbootimg/unpack_bootimg.py /usr/local/bin/unpack_bootimg \
 && mkbootimg --help >/dev/null
# avbtool (AOSP external/avb): ABL Pixel 3 đòi boot.img có AVB footer kể cả khi đã unlock
RUN mkdir -p /opt/avb \
 && curl -fsSL "https://android.googlesource.com/platform/external/avb/+archive/refs/tags/${MKBOOTIMG_TAG}.tar.gz" \
    | tar -xz -C /opt/avb avbtool.py test/data/testkey_rsa2048.pem \
 && ln -sf /opt/avb/avbtool.py /usr/local/bin/avbtool \
 && avbtool version
WORKDIR /work
