#!/bin/sh
# Wi-Fi dự phòng: không vào được mạng quen sau 2 phút -> phát AP "pixel3xl-setup" (WPA2, NM method=shared,
# máy = 10.42.0.1). Từ laptop/iPhone vào AP rồi SSH/Remote Desktop 10.42.0.1 để thêm Wi-Fi mới
# (scripts/wifi-add.sh "<SSID>" 10.42.0.1). Đang phát AP thì cứ 10 phút tắt AP ~60 giây để NM thử lại mạng quen.
# DHCP của AP không cấp gateway/DNS (dnsmasq-shared.d/10-usb0-no-gateway.conf áp cho mọi kết nối shared)
# -> iPhone/laptop vẫn giữ Internet của chúng.
AP=pixel3xl-setup
log() { echo "pixel-wifi-fallback: $*"; }
nmcli -t -f NAME connection show | grep -qx "$AP" || { log "chưa có kết nối $AP (chạy scripts/93-wifi-fallback.sh)"; exit 0; }
sleep 120
while true; do
    state=$(nmcli -g GENERAL.STATE device show wlan0 2>/dev/null | cut -d' ' -f1)
    conn=$(nmcli -g GENERAL.CONNECTION device show wlan0 2>/dev/null)
    if [ "$state" = "100" ] && [ "$conn" != "$AP" ]; then
        sleep 60; continue                       # đang ở mạng quen
    fi
    if [ "$conn" = "$AP" ]; then
        sleep 600
        log "tạm tắt AP để thử lại mạng quen"
        nmcli connection down "$AP" >/dev/null 2>&1
        sleep 60; continue
    fi
    log "không có mạng quen -> bật AP $AP"
    nmcli connection up "$AP" >/dev/null 2>&1 || log "bật AP lỗi"
    sleep 60
done
