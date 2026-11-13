#!/bin/sh
# Chạy TRÊN ĐIỆN THOẠI (initramfs debug): mount rootfs Ubuntu (LABEL=pixelroot) và áp overlay.tar mới nhất.
set -e
DEV=$(findfs LABEL=pixelroot)
mkdir -p /mnt/root && mount -t ext4 "$DEV" /mnt/root
wget -q -O /tmp/overlay.tar http://172.16.42.2:8000/overlay.tar
tar -C /mnt/root -xpf /tmp/overlay.tar
# file cũ đã đổi tên trong repo
rm -f /mnt/root/etc/NetworkManager/conf.d/10-pixel-wifi.conf
ls -la /mnt/root/etc/NetworkManager/conf.d/ /mnt/root/usr/local/sbin/
echo "--- journal lần boot trước (usb/NM):"; ls /mnt/root/var/log/journal/ 2>/dev/null
sync; umount /mnt/root; echo "ĐÃ ÁP OVERLAY vào $DEV"
