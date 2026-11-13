#!/usr/bin/env bash
# Thêm/kết nối Wi-Fi mới cho điện thoại (chạy trên Mac). Mặc định qua cáp USB (172.16.42.1) — không cần Internet.
# Mật khẩu gõ ẩn, gửi qua stdin của SSH: không hiện trên màn hình, không nằm trong tham số lệnh hay file trên Mac.
# NetworkManager trên máy lưu mạng này (chỉ root đọc được) và tự kết nối lại về sau.
# Dùng: scripts/wifi-add.sh            (hỏi tên Wi-Fi + mật khẩu)
#       scripts/wifi-add.sh "Tên Wi-Fi" [host]
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SSID="${1:-}"; H="${2:-172.16.42.1}"
SSH=(ssh -o UserKnownHostsFile="$REPO/.ssh_known_hosts" -o BatchMode=yes -o ConnectTimeout=10 "ubuntu@$H")
"${SSH[@]}" true || { echo "Không SSH được tới $H — cắm cáp USB, chờ ~30s rồi thử lại." >&2; exit 1; }
echo "== Mạng Wi-Fi quanh điện thoại:"
"${SSH[@]}" 'sudo nmcli device wifi rescan 2>/dev/null; sleep 3; nmcli -f SSID,SIGNAL,SECURITY device wifi list | head -15'
[[ -n "$SSID" ]] || read -r -p "Tên Wi-Fi (SSID): " SSID
read -r -s -p "Mật khẩu Wi-Fi \"$SSID\" (để trống nếu mạng mở): " PW; echo
REMOTE_SCRIPT=$(cat <<'REMOTE'
set -euo pipefail
IFS= read -r SSID; IFS= read -r PW
if [ -n "$PW" ]; then
  sudo nmcli --wait 45 device wifi connect "$SSID" password "$PW"
else
  sudo nmcli --wait 45 device wifi connect "$SSID"
fi
sleep 3
nmcli -f DEVICE,STATE,CONNECTION device | grep -E "wlan0"
ip -4 -o addr show wlan0 | awk '{print "IP Wi-Fi:", $4}'
tailscale ip -4 2>/dev/null | sed 's/^/IP Tailscale: /' || true
REMOTE
)
# Lọc mật khẩu khỏi mọi thông báo lỗi trả về (phòng hờ)
printf '%s\n%s\n' "$SSID" "$PW" | "${SSH[@]}" "bash -c $(printf %q "$REMOTE_SCRIPT")" 2>&1 \
  | { if [[ -n "$PW" ]]; then sed "s/$(printf '%s' "$PW" | sed 's/[][\.*^$/]/\\&/g')/***/g"; else cat; fi; }
