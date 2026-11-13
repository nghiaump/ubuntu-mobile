#!/bin/sh
# Thử từng nhóm (chạy TRÊN ĐIỆN THOẠI, initramfs, mọi thứ trong RAM):
#   sh stage.sh base     : tải payload, bind /lib/modules + /lib/firmware, by-partlabel, stream dmesg về Mac:9999
#   sh stage.sh display  : dispcc + msm + panel s6e3ha8 (driver panel thật)
#   sh stage.sh modem    : qrtr, pd-mapper, rmtfs_mem, reset-pdc, aoss, q6v5_mss + rmtfs -r -P -s + tqftpserv
#   sh stage.sh wifi     : ath10k_snoc -> wlan0 -> scan
H=http://172.16.42.2:8000
LD=/tmp/pl/lib/ld-linux-aarch64.so.1
run() { $LD --library-path /tmp/pl/lib "$@"; }
# tiến trình nền phải tách khỏi phiên telnet (setsid), nếu không sẽ chết vì SIGHUP khi phiên đóng
bg() { log=$1; shift; setsid "$@" </dev/null >"$log" 2>&1 & sleep 1; }
mp() { for m in "$@"; do modprobe $m && echo "  + $m" || echo "  !! $m"; done; }
rprocs() { for r in /sys/class/remoteproc/remoteproc*; do [ -e $r ] && echo "  $(basename $r): $(cat $r/name) $(cat $r/state)"; done; }
case "$1" in
base)
  cd /tmp
  [ -d /tmp/pl ] || { wget -q -O payload.tar $H/payload.tar && mkdir -p pl && tar -C pl -xf payload.tar && rm payload.tar; }
  mkdir -p /lib/modules /lib/firmware
  umount /lib/modules /lib/firmware 2>/dev/null
  mount --bind /tmp/pl/lib/modules /lib/modules && mount --bind /tmp/pl/lib/firmware /lib/firmware
  mkdir -p /dev/disk/by-partlabel
  for u in /sys/class/block/*/uevent; do
    n=$(sed -n 's/^PARTNAME=//p' $u); d=$(sed -n 's/^DEVNAME=//p' $u)
    [ -n "$n" ] && ln -sf /dev/$d /dev/disk/by-partlabel/$n
  done
  dmesg -n 8
  if ! pidof nc >/dev/null; then setsid sh -c 'cat /dev/kmsg | nc 172.16.42.2 9999' </dev/null >/dev/null 2>&1 & sleep 1; fi
  echo "base OK: $(ls /lib/modules) ; stream dmesg -> Mac:9999"; rprocs ;;
display)
  mp qcom-refgen-regulator qcom-labibb-regulator dispcc_sdm845 msm panel_samsung_s6e3ha8
  sleep 5; ls /sys/class/drm; cat /sys/class/graphics/fb*/name 2>/dev/null
  dmesg | grep -i -E "msm|dsi|panel|dpu|mdss|drm|a630|gmu|zap" | tail -30 ;;
modem)
  mkdir -p /var/lib/tqftpserv
  mp qrtr qrtr_smd qcom_pd_mapper rmtfs_mem reset_qcom_pdc qcom_aoss pwrseq-qcom-wcn ath10k_snoc qcom_q6v5_mss
  sleep 2; ls -la /dev/qcom_rmtfs_mem* 2>&1; rprocs
  pidof rmtfs >/dev/null || bg /tmp/rmtfs.log $LD --library-path /tmp/pl/lib /tmp/pl/bin/rmtfs -r -P -s -v
  pidof tqftpserv >/dev/null || bg /tmp/tqftpserv.log $LD --library-path /tmp/pl/lib /tmp/pl/bin/tqftpserv
  sleep 15; rprocs
  run /tmp/pl/bin/qrtr-lookup | head -40
  echo "--- rmtfs.log"; tail -20 /tmp/rmtfs.log; echo "--- tqftpserv.log"; tail -10 /tmp/tqftpserv.log
  dmesg | grep -i -E "remoteproc|q6v5|mss|modem|rmtfs|pdc|aoss|qrtr|pd_mapper|sysmon" | tail -30 ;;
wifi)
  mp pwrseq-qcom-wcn ath10k_snoc
  for i in $(seq 1 40); do [ -e /sys/class/net/wlan0 ] && break; sleep 1; done
  ip link | grep -A1 wlan0 || echo "  !! chưa có wlan0"
  if [ -e /sys/class/net/wlan0 ]; then ip link set wlan0 up; sleep 4
    run /tmp/pl/bin/iw dev wlan0 scan 2>&1 | grep -E "SSID:|signal:" | head -24; fi
  echo "--- tqftpserv.log"; tail -10 /tmp/tqftpserv.log
  dmesg | grep -i -E "ath10k|wlan|wlfw|qmi|firmware|regulatory" | tail -30 ;;
*) echo "stage: base|display|modem|wifi" ;;
esac
