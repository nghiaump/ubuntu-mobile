#!/bin/sh
# LƯU Ý: busybox-static (standalone shell) ưu tiên applet của nó (dpkg, tar...) kể cả trong chroot
#        -> luôn gọi `chroot $R /bin/sh -c ...` (đường dẫn tuyệt đối), glob cũng phải nằm trong sh -c.
# Chạy TRÊN ĐIỆN THOẠI (initramfs debug): đọc journal lần boot trước, áp overlay, cài .deb còn thiếu qua chroot.
H=http://172.16.42.2:8000
DEV=$(findfs LABEL=pixelroot); R=/mnt/root
mkdir -p $R && mount -t ext4 "$DEV" $R
for m in proc sys dev; do mount --bind /$m $R/$m; done
echo "=== journal boot trước: usb-gadget, NetworkManager"
chroot $R /bin/sh -c "journalctl -b -1 --no-pager -o short-monotonic -u usb-gadget -u NetworkManager 2>&1" | tail -40
echo "=== áp overlay"
wget -q -O /tmp/overlay.tar $H/overlay.tar && tar -C $R -xpf /tmp/overlay.tar && rm -f $R/etc/NetworkManager/conf.d/10-pixel-wifi.conf
echo "=== cài .deb"
mkdir -p $R/tmp/debs
for f in $(wget -q -O - $H/debs/list.txt); do wget -q -O $R/tmp/debs/$f $H/debs/$f; done
chroot $R /bin/sh -c "dpkg -i /tmp/debs/*.deb 2>&1 | tail -6"
rm -rf $R/tmp/debs
chroot $R /bin/sh -c "command -v iptables; iptables --version"
for m in proc sys dev; do umount $R/$m; done
sync; umount $R; echo "XONG fix-rootfs trên $DEV"
