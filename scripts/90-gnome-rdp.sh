#!/usr/bin/env bash
# Pha 5: bật GNOME Remote Login (RDP, phiên GNOME riêng/headless) trên điện thoại để điều khiển từ Mac.
# Mật khẩu đọc từ bàn phím (không hiện, không ghi file/log), gửi qua stdin của SSH.
# Dùng: scripts/90-gnome-rdp.sh [host]   (mặc định 172.16.42.1)
# Trên Mac: Windows App -> Add PC -> <host>:3389; lớp RDP hỏi user/mật khẩu, sau đó màn hình GDM hỏi lại.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
H="${1:-172.16.42.1}"
SSH=(ssh -o UserKnownHostsFile="$REPO/.ssh_known_hosts" -o BatchMode=yes "ubuntu@$H")
if [[ -z "${PIXEL_PW:-}" ]]; then
  read -r -s -p "Mật khẩu cho user ubuntu + RDP: " PIXEL_PW; echo
fi
# LƯU Ý: KHÔNG được vừa pipe mật khẩu vừa dùng heredoc cho stdin của ssh (heredoc thắng -> `read PW`
# đọc nhầm dòng kế tiếp của script làm mật khẩu). Script đi qua tham số, chỉ mật khẩu đi qua stdin.
REMOTE_SCRIPT=$(cat <<'REMOTE'
set -euo pipefail
IFS= read -r PW
[ -n "$PW" ] || { echo "mật khẩu rỗng" >&2; exit 1; }
printf 'ubuntu:%s\n' "$PW" | sudo chpasswd
id gnome-remote-desktop >/dev/null
D=/var/lib/gnome-remote-desktop/.local/share/gnome-remote-desktop
sudo install -d -o gnome-remote-desktop -g gnome-remote-desktop -m 700 "$D"
if ! sudo test -s "$D/rdp-tls.crt"; then
  sudo -u gnome-remote-desktop openssl req -new -newkey rsa:3072 -days 3650 -nodes -x509 \
    -subj "/CN=pixel3xl" -keyout "$D/rdp-tls.key" -out "$D/rdp-tls.crt" 2>/dev/null
fi
sudo grdctl --system rdp set-tls-key "$D/rdp-tls.key"
sudo grdctl --system rdp set-tls-cert "$D/rdp-tls.crt"
sudo grdctl --system rdp set-credentials ubuntu "$PW"
sudo grdctl --system rdp enable
sudo systemctl set-default graphical.target >/dev/null
sudo install -d /etc/systemd/system/gnome-remote-desktop.service.d
printf '[Unit]\nAfter=gdm.service display-manager.service\nWants=gdm.service\n' | sudo tee /etc/systemd/system/gnome-remote-desktop.service.d/10-after-gdm.conf >/dev/null
sudo systemctl daemon-reload
sudo systemctl enable --now gdm3.service 2>&1 | grep -v -i "symlink\|sysv" || true
sleep 5   # chờ GDM rồi mới (re)start RDP: chạy trước GDM thì không mở cổng 3389
sudo systemctl enable gnome-remote-desktop.service 2>/dev/null; sudo systemctl restart gnome-remote-desktop.service
sleep 5
sudo grdctl --system status | grep -v -i -E "password|credential"
sudo ss -ltnp | grep -E ":3389 " || echo "!! chưa thấy cổng 3389"
REMOTE
)
printf '%s\n' "$PIXEL_PW" | "${SSH[@]}" "bash -c $(printf %q "$REMOTE_SCRIPT")"
