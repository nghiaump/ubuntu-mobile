#!/bin/sh
# Dựng USB gadget NCM (mạng) + ACM (serial) qua configfs. IP do NetworkManager cấp (usb0.nmconnection).
set -e
G=/sys/kernel/config/usb_gadget/g1
case "${1:-start}" in
stop)
    [ -d $G ] || exit 0
    echo "" > $G/UDC 2>/dev/null || true
    rm -f $G/configs/c.1/ncm.usb0 $G/configs/c.1/acm.usb0
    rmdir $G/configs/c.1/strings/0x409 $G/configs/c.1 $G/functions/ncm.usb0 $G/functions/acm.usb0 $G/strings/0x409 $G 2>/dev/null || true
    exit 0 ;;
esac
mountpoint -q /sys/kernel/config || mount -t configfs configfs /sys/kernel/config
[ -d $G ] && [ -n "$(cat $G/UDC 2>/dev/null)" ] && exit 0
if [ -d $G/configs/c.1 ]; then
    # gadget đã được dựng (vd. initramfs để lại): chỉ gắn lại UDC — ghi *_addr lúc này sẽ bị -EBUSY
    ls /sys/class/udc | head -n1 > $G/UDC
    ip link set usb0 up 2>/dev/null || true
    exit 0
fi
mkdir -p $G; cd $G
echo 0x1d6b > idVendor; echo 0x0104 > idProduct; echo 0x0100 > bcdDevice; echo 0x0200 > bcdUSB
mkdir -p strings/0x409
echo "Google" > strings/0x409/manufacturer
echo "Pixel 3 XL (Ubuntu)" > strings/0x409/product
cut -c1-8 /etc/machine-id > strings/0x409/serialnumber
mkdir -p functions/ncm.usb0 functions/acm.usb0
echo "02:00:00:3a:00:01" > functions/ncm.usb0/host_addr
echo "02:00:00:3a:00:02" > functions/ncm.usb0/dev_addr
mkdir -p configs/c.1/strings/0x409
echo "NCM+ACM" > configs/c.1/strings/0x409/configuration
echo 500 > configs/c.1/MaxPower
ln -sf $G/functions/ncm.usb0 configs/c.1/
ln -sf $G/functions/acm.usb0 configs/c.1/
for i in $(seq 1 50); do [ -n "$(ls /sys/class/udc 2>/dev/null)" ] && break; sleep 0.2; done
ls /sys/class/udc | head -n1 > UDC
# Đường lui: tự bật usb0 để luôn có IPv6 link-local (ssh ubuntu@fe80::...%enX) kể cả khi NM lỗi
ip link set usb0 up 2>/dev/null || true
