#!/usr/bin/env bash
# Tạo kết nối AP "pixel3xl-setup" (mật khẩu ngẫu nhiên, chỉ in ra MỘT lần cho người dùng) + bật dịch vụ dự phòng.
# Dùng: scripts/93-wifi-fallback.sh [host]   (mặc định 172.16.42.1)
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
H="${1:-172.16.42.1}"
SSH=(ssh -o UserKnownHostsFile="$REPO/.ssh_known_hosts" -o BatchMode=yes "ubuntu@$H")
scp -q -o UserKnownHostsFile="$REPO/.ssh_known_hosts" -o BatchMode=yes \
  "$REPO/rootfs/overlay/usr/local/sbin/pixel-wifi-fallback.sh" \
  "$REPO/rootfs/overlay/etc/systemd/system/pixel-wifi-fallback.service" "ubuntu@$H:/tmp/"
PW=$(LC_ALL=C tr -dc 'A-HJ-NP-Za-km-z2-9' </dev/urandom 2>/dev/null | head -c 12 || true)   # || true: tr nhận SIGPIPE khi head đủ ký tự (pipefail)
printf '%s\n' "$PW" | "${SSH[@]}" 'bash -c '"$(printf %q '
set -euo pipefail
IFS= read -r PW
sudo install -m 755 /tmp/pixel-wifi-fallback.sh /usr/local/sbin/
sudo install -m 644 /tmp/pixel-wifi-fallback.service /etc/systemd/system/
sudo nmcli connection delete pixel3xl-setup >/dev/null 2>&1 || true
sudo nmcli connection add type wifi ifname wlan0 con-name pixel3xl-setup ssid pixel3xl-setup \
  802-11-wireless.mode ap 802-11-wireless.band bg ipv4.method shared ipv6.method disabled \
  wifi-sec.key-mgmt wpa-psk wifi-sec.proto rsn wifi-sec.pairwise ccmp wifi-sec.group ccmp wifi-sec.psk "$PW" \
  connection.autoconnect no >/dev/null
sudo systemctl daemon-reload
sudo systemctl enable --now pixel-wifi-fallback.service >/dev/null 2>&1
systemctl is-active pixel-wifi-fallback.service
nmcli -f NAME,AUTOCONNECT connection show | grep -E "pixel3xl-setup"
')"
echo "== AP dự phòng: SSID pixel3xl-setup  mật khẩu: $PW  (máy = 10.42.0.1)"
