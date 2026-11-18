#!/usr/bin/env bash
# Chrome trên GNOME Wayland không tự bật bàn phím ảo khi chạm vào ô nhập chữ. Tài liệu: docs/software/touch-ui.md
# GNOME chỉ hiện OSK khi ứng dụng báo "đang nhập chữ" qua Wayland text-input-v3 -> chạy Chrome với:
#   --ozone-platform=wayland --enable-wayland-ime --wayland-text-input-version=3
# Ghi đè file .desktop ở mức user (~/.local/share/applications), không sửa file của gói (cập nhật Chrome không mất).
# Kèm thao tác cảm ứng của GNOME (gsettings của user ubuntu, lấy DBus từ phiên gnome-shell):
#   a11y screen-keyboard-enabled=true : luôn bật bàn phím ảo khi ô nhập chữ được focus (heuristic "touch mode" không bắt được Chrome)
#   a11y mouse secondary-click-enabled=true, time 0.8 s : giữ lâu = chuột phải (với sự kiện con trỏ)
# Kèm phím Esc cho bàn phím ảo trong terminal: GNOME dùng layout "<layout>-extended" khi app báo content purpose TERMINAL
#   (có Tab/Ctrl/Alt/mũi tên nhưng KHÔNG có Esc). Sinh bản us-extended.json đã thay phím emoji -> Esc vào
#   ~/.local/share/pixel-osk-layouts và cho gnome-shell đọc qua G_RESOURCE_OVERLAYS (~/.config/environment.d) -> cần đăng nhập lại.
# Dùng: scripts/97-chrome-osk.sh [host]   (mặc định $PIXEL_HOST, không có thì USB 172.16.42.1)
#       scripts/97-chrome-osk.sh [host] undo   -> gỡ ghi đè
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
H="${1:-${PIXEL_HOST:-172.16.42.1}}"; MODE="${2:-apply}"
SSH=(ssh -o UserKnownHostsFile="$REPO/.ssh_known_hosts" -o HostKeyAlias=172.16.42.1 -o BatchMode=yes "ubuntu@$H")
"${SSH[@]}" "MODE=$MODE bash -s" <<'INNER'
set -euo pipefail
FLAGS="--ozone-platform=wayland --enable-wayland-ime --wayland-text-input-version=3"
D=~/.local/share/applications; mkdir -p "$D"
for f in google-chrome.desktop com.google.Chrome.desktop; do
  src=/usr/share/applications/$f
  [ -f "$src" ] || continue
  if [ "$MODE" = undo ]; then rm -f "$D/$f"; echo "gỡ $D/$f"; continue; fi
  sed -E "s#^(Exec=/usr/bin/google-chrome-stable)( |$)#\1 $FLAGS\2#" "$src" > "$D/$f"
  echo "== $D/$f"; grep '^Exec' "$D/$f"
done
update-desktop-database "$D" 2>/dev/null || true
# --- Phím Esc cho layout terminal của bàn phím ảo ---
OSK=~/.local/share/pixel-osk-layouts; ENVD=~/.config/environment.d/90-pixel-osk.conf
if [ "$MODE" = undo ]; then
  rm -rf "$OSK" "$ENVD"; XDG_RUNTIME_DIR=/run/user/$(id -u) systemctl --user unset-environment G_RESOURCE_OVERLAYS 2>/dev/null || true
  echo "gỡ layout OSK riêng (cần đăng nhập lại)"
else
  mkdir -p "$OSK" ~/.config/environment.d
  G=/usr/share/gnome-shell/gnome-shell-osk-layouts.gresource
  gresource extract "$G" /org/gnome/shell/osk-layouts/us-extended.json > /tmp/us-extended.orig.json
  python3 - /tmp/us-extended.orig.json "$OSK/us-extended.json" <<'PYEND'
import json, sys
d = json.load(open(sys.argv[1]))
n = 0
for lvl in d["levels"]:
    if lvl.get("level") not in ("default", "shift"):
        continue
    for row in lvl["rows"]:
        for i, k in enumerate(row):
            if k.get("action") == "emoji":
                row[i] = {"label": "Esc", "keyval": "0xff1b"}
                n += 1
json.dump(d, open(sys.argv[2], "w"), ensure_ascii=False, indent=1)
print(f"us-extended.json: thay {n} phím emoji -> Esc")
PYEND
  echo "G_RESOURCE_OVERLAYS=/org/gnome/shell/osk-layouts=$OSK" > "$ENVD"
  # environment.d chỉ được đọc khi systemd --user khởi động/reload; nó KHÔNG dừng khi đăng xuất GNOME (SSH giữ nó chạy)
  XDG_RUNTIME_DIR=/run/user/$(id -u) systemctl --user daemon-reload
  echo "đã đặt $ENVD (cần đăng nhập lại để gnome-shell đọc)"
fi
P=$(pgrep -u "$(id -u)" gnome-shell | head -1)
if [ -n "$P" ]; then
  export $(tr '\0' '\n' < /proc/$P/environ | grep -E '^DBUS_SESSION_BUS_ADDRESS=')
  if [ "$MODE" = undo ]; then
    gsettings reset org.gnome.desktop.a11y.applications screen-keyboard-enabled
    gsettings reset org.gnome.desktop.a11y.mouse secondary-click-enabled
    gsettings reset org.gnome.desktop.a11y.mouse secondary-click-time
  else
    gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true
    gsettings set org.gnome.desktop.a11y.mouse secondary-click-enabled true
    gsettings set org.gnome.desktop.a11y.mouse secondary-click-time 0.8
  fi
  echo "screen-keyboard=$(gsettings get org.gnome.desktop.a11y.applications screen-keyboard-enabled) secondary-click=$(gsettings get org.gnome.desktop.a11y.mouse secondary-click-enabled) ($(gsettings get org.gnome.desktop.a11y.mouse secondary-click-time) s)"
else
  echo "!! không thấy phiên gnome-shell — chưa đặt gsettings"
fi
INNER
