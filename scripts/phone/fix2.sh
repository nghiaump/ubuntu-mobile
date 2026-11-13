#!/bin/sh
# Chạy TRÊN ĐIỆN THOẠI (initramfs debug). Luôn dùng `chroot $R /bin/sh -c` (busybox ưu tiên applet của nó).
H=http://172.16.42.2:8000; R=/mnt/root; DEV=$(findfs LABEL=pixelroot)
mkdir -p $R && mount -t ext4 "$DEV" $R; for m in proc sys dev; do mount --bind /$m $R/$m; done
J='journalctl --no-pager -o short-monotonic'
chroot $R /bin/sh -c "$J --list-boots | tail -3"
echo "=== boot Ubuntu gần nhất: cycle / ssh / usb0"
chroot $R /bin/sh -c "$J -b 0 | grep -i -E 'cycle|ssh|usb0|usb-gadget|firstboot|Failed|failed' | grep -v -E 'SUBSYSTEM|DEVICE' | cut -c1-220 | tail -30"
echo "=== áp overlay + bật unit"
wget -q -O /tmp/overlay.tar $H/overlay.tar && tar -C $R -xpf /tmp/overlay.tar
rm -f $R/etc/NetworkManager/conf.d/10-pixel-wifi.conf
chroot $R /bin/sh -c "systemctl enable pixel-sshkeys.service 2>&1; ssh-keygen -A; ls /etc/ssh/ssh_host_*_key.pub; systemctl is-enabled ssh.socket ssh.service usb-gadget.service serial-getty@ttyGS0.service NetworkManager.service"
for m in proc sys dev; do umount $R/$m; done; sync; umount $R; echo "XONG fix2"
