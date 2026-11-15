#!/bin/sh
# Pixel 3 XL: gán địa chỉ Bluetooth (BD address) cho WCN3990 — tài liệu: docs/hardware/connectivity.md
# Mainline (btqca + hci_uart) để controller ở trạng thái "Unconfigured — missing public-address" vì bootloader
# không truyền địa chỉ (DT local-bd-address = 0) -> BlueZ không thấy controller ("No default controller available").
# Địa chỉ gốc nằm trong phân vùng persist của Android (KHÔNG đụng). Thay vào đó: địa chỉ ỔN ĐỊNH, duy nhất theo máy:
#   sha256("pixel3xl-bt-" + androidboot.serialno) 6 byte đầu, bit locally-administered = 1, bit multicast = 0.
# Ghi đè được: đặt BDADDR=XX:XX:XX:XX:XX:XX trong /etc/default/pixel-bt-addr.
set -eu
[ -r /etc/default/pixel-bt-addr ] && . /etc/default/pixel-bt-addr
BDADDR="${BDADDR:-}"
for i in $(seq 1 60); do [ -e /sys/class/bluetooth/hci0 ] && break; sleep 1; done
[ -e /sys/class/bluetooth/hci0 ] || { echo "không có hci0"; exit 0; }
if [ -z "$BDADDR" ]; then
  S=$(tr ' ' '\n' < /proc/cmdline | sed -n 's/^androidboot.serialno=//p')
  [ -n "$S" ] || S=$(cat /etc/machine-id)
  BDADDR=$(printf 'pixel3xl-bt-%s' "$S" | sha256sum | cut -c1-12 | python3 -c \
    'import sys; h=bytearray.fromhex(sys.stdin.read().strip()); h[0]=(h[0]|0x02)&0xFE; print(":".join("%02X"%b for b in h))')
fi
# Chỉ gán khi controller đang thiếu địa chỉ (unconfigured)
# btmgmt (bt_shell) khi không có terminal: stdin /dev/null -> thoát NGAY trước khi nhận phản hồi (không in gì);
# không có stdin -> chờ mãi. Cho stdin là pipe mở 2 s (sleep 2 |) + timeout 5.
mgmt() { sleep 2 | timeout 5 btmgmt "$@" 2>&1; }
if mgmt config | grep -q "missing options:.*public-address"; then
  mgmt --index 0 public-addr "$BDADDR" | tail -1
  echo "đã gán địa chỉ Bluetooth (locally administered, ổn định theo máy)"
else
  echo "controller đã có địa chỉ — bỏ qua"
fi
