#!/bin/sh
# Nạp module theo từng modalias (giả lập udev coldplug), in alias + dmesg mới sau mỗi lần.
# Chạy tiền cảnh qua tstream.py để nếu máy reset thì biết alias cuối cùng.
dmesg -c >/dev/null
find /sys/devices -name modalias -exec cat {} + 2>/dev/null | sort -u > /tmp/aliases
echo "tổng alias: $(wc -l < /tmp/aliases)"
while read a; do
  echo "== $a"
  modprobe -q "$a"; sleep 0.5
  dmesg -c | sed 's/^/   /' | grep -v -E "SUBSYSTEM=|DEVICE=" | tail -6
done < /tmp/aliases
echo "== XONG: $(lsmod | wc -l) module"
