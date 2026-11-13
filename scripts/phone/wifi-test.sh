#!/bin/sh
# Chạy TRÊN ĐIỆN THOẠI (initramfs). Mọi thứ nằm trong tmpfs; rmtfs chạy -r (không ghi EFS).
# Bước: payload -> coldplug module theo modalias (initramfs không có udev) -> rmtfs -s (tự khởi động modem)
#       -> tqftpserv (phục vụ wlanmdsp.mbn cho modem) -> ath10k_snoc -> wlan0 -> scan
H=http://172.16.42.2:8000
cd /tmp
[ -d /tmp/pl ] || { wget -q -O payload.tar $H/payload.tar && mkdir -p pl && tar -C pl -xf payload.tar && rm payload.tar; }
# bind lại mỗi lần (nếu /tmp/pl bị tạo lại, mount cũ trỏ vào thư mục đã xoá)
mkdir -p /lib/modules /lib/firmware
umount /lib/modules /lib/firmware 2>/dev/null
mount --bind /tmp/pl/lib/modules /lib/modules
mount --bind /tmp/pl/lib/firmware /lib/firmware
ls /lib/modules /lib/firmware/qcom/sdm845/Google/blueline | head -3
LD=/tmp/pl/lib/ld-linux-aarch64.so.1
run() { $LD --library-path /tmp/pl/lib "$@"; }
mkdir -p /dev/disk/by-partlabel
for u in /sys/class/block/*/uevent; do
  n=$(sed -n 's/^PARTNAME=//p' $u); d=$(sed -n 's/^DEVNAME=//p' $u)
  [ -n "$n" ] && ln -sf /dev/$d /dev/disk/by-partlabel/$n
done
coldplug() { find /sys/devices -name modalias -exec cat {} + 2>/dev/null | sort -u > /tmp/aliases
             xargs -n 40 modprobe -a -q < /tmp/aliases 2>/dev/null; }
echo "== coldplug"; for i in 1 2 3; do coldplug; sleep 2; done
for m in qrtr qrtr_smd qcom_pd_mapper rmtfs_mem qcom_q6v5_mss ath10k_snoc; do modprobe -q $m || echo "!! modprobe $m"; done
sleep 2
ls -la /dev/qcom_rmtfs_mem* 2>&1
for r in /sys/class/remoteproc/remoteproc*; do echo "$r: $(cat $r/name) state=$(cat $r/state)"; done
echo "== rmtfs -r -P -s"
pidof rmtfs >/dev/null || { run /tmp/pl/bin/rmtfs -r -P -s -v > /tmp/rmtfs.log 2>&1 & }
pidof tqftpserv >/dev/null || { run /tmp/pl/bin/tqftpserv > /tmp/tqftpserv.log 2>&1 & }
for i in $(seq 1 30); do grep -q running /sys/class/remoteproc/*/state 2>/dev/null && \
  [ "$(for r in /sys/class/remoteproc/*; do [ "$(cat $r/name)" = 4080000.remoteproc ] && cat $r/state; done)" = running ] && break; sleep 1; done
for r in /sys/class/remoteproc/remoteproc*; do echo "$r: $(cat $r/name) state=$(cat $r/state)"; done
echo "== chờ wlan0"; for i in $(seq 1 40); do [ -e /sys/class/net/wlan0 ] && break; sleep 1; done
ip link
if [ -e /sys/class/net/wlan0 ]; then
  ip link set wlan0 up; sleep 4
  run /tmp/pl/bin/iw dev wlan0 scan 2>&1 | grep -E "^BSS|SSID:|signal:" | head -24
fi
echo "== dmesg"
dmesg | grep -i -E "remoteproc|q6v5|mss|modem|ath10k|wlan|rmtfs|firmware|pd_mapper|qrtr|msm|panel|dsi|adreno|a630|zap|gmu|venus" | grep -v -i "simple-framebuffer" | tail -70
echo "--- rmtfs.log"; tail -15 /tmp/rmtfs.log; echo "--- tqftpserv.log"; tail -15 /tmp/tqftpserv.log
