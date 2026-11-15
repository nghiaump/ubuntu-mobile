#!/usr/bin/env bash
# Cài extension GNOME tự viết "pixel3xl-shell@pixel3xl" (rootfs/gnome-extensions/) — tài liệu: docs/software/touch-ui.md
#   (1) tai thỏ: dải đen + thanh trên/cửa sổ nằm dưới tai thỏ   (2) bàn phím ảo cho Chrome/Electron
# GNOME Wayland chỉ nạp extension MỚI/ĐỔI CODE khi phiên khởi động lại (đăng xuất/đăng nhập hoặc reboot).
# Dùng: scripts/98-gnome-shell-ext.sh [host] [px]   px = độ cao tai thỏ (px vật lý, ghi ~/.config/pixel-notch-px; 0 = tắt dải)
#       scripts/98-gnome-shell-ext.sh [host] undo
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
H="${1:-${PIXEL_HOST:-172.16.42.1}}"; ARG="${2:-}"
UUID=pixel3xl-shell@pixel3xl
OLD=pixel-notch@pixel3xl            # tên cũ (v1), gỡ khi cài
SSH=(ssh -o UserKnownHostsFile="$REPO/.ssh_known_hosts" -o HostKeyAlias=172.16.42.1 -o BatchMode=yes "ubuntu@$H")
if [[ "$ARG" != undo ]]; then
  COPYFILE_DISABLE=1 tar --no-xattrs -C "$REPO/rootfs/gnome-extensions" -czf - "$UUID" \
    | "${SSH[@]}" "mkdir -p ~/.local/share/gnome-shell/extensions && tar -C ~/.local/share/gnome-shell/extensions -xzf - && rm -rf ~/.local/share/gnome-shell/extensions/$OLD"
fi
"${SSH[@]}" "UUID=$UUID OLD=$OLD ARG='$ARG' bash -s" <<'INNER'
set -euo pipefail
P=$(pgrep -u "$(id -u)" gnome-shell | head -1)
export $(tr '\0' '\n' < /proc/$P/environ | grep -E '^DBUS_SESSION_BUS_ADDRESS=')
cur=$(gsettings get org.gnome.shell enabled-extensions)
edit() { python3 -c "import ast,sys; l=ast.literal_eval(sys.argv[1].replace('@as ','')); l=[x for x in l if x not in (sys.argv[2],sys.argv[3])]; l+=[sys.argv[2]] if sys.argv[4]=='add' else []; print(l)" "$cur" "$UUID" "$OLD" "$1"; }
if [ "$ARG" = undo ]; then
  gsettings set org.gnome.shell enabled-extensions "$(edit del)"; rm -rf ~/.local/share/gnome-shell/extensions/$UUID; echo "đã gỡ $UUID (cần đăng nhập lại)"; exit 0
fi
case "$ARG" in ''|*[!0-9]*) ;; *) echo "$ARG" > ~/.config/pixel-notch-px ;; esac
gsettings set org.gnome.shell enabled-extensions "$(edit add)"
gsettings set org.gnome.shell disable-user-extensions false
echo "enabled-extensions: $(gsettings get org.gnome.shell enabled-extensions)"
echo "độ cao tai thỏ: $(cat ~/.config/pixel-notch-px 2>/dev/null || echo '172 (mặc định)') px vật lý"
echo "trạng thái hiện tại: $(gnome-extensions info $UUID 2>/dev/null | grep -E 'State' | xargs || echo 'chưa nạp — cần đăng nhập lại')"
INNER
