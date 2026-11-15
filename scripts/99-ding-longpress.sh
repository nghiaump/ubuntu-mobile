#!/usr/bin/env bash
# Giữ lâu (cảm ứng) trên icon/nền desktop = chuột phải: vá Desktop Icons NG (ding@rastersoft.com).
# Đẩy bộ vá + hook apt lên máy, vá, khởi động lại tiến trình DING (extension tự bật lại) — KHÔNG cần đăng nhập lại.
# Tài liệu: docs/software/touch-ui.md
# Dùng: scripts/99-ding-longpress.sh [host]          (mặc định $PIXEL_HOST, không có thì USB 172.16.42.1)
#       scripts/99-ding-longpress.sh [host] restore  -> khôi phục mã gốc
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
H="${1:-${PIXEL_HOST:-172.16.42.1}}"; MODE="${2:-apply}"
O="$REPO/rootfs/overlay"
SSH=(ssh -o UserKnownHostsFile="$REPO/.ssh_known_hosts" -o HostKeyAlias=172.16.42.1 -o BatchMode=yes "ubuntu@$H")
scp -q -o UserKnownHostsFile="$REPO/.ssh_known_hosts" -o HostKeyAlias=172.16.42.1 \
  "$O/usr/local/sbin/pixel-ding-longpress" "$O/etc/apt/apt.conf.d/99-pixel-ding-longpress" "ubuntu@$H:/tmp/"
"${SSH[@]}" "MODE=$MODE bash -s" <<'INNER'
set -euo pipefail
sudo install -m755 /tmp/pixel-ding-longpress /usr/local/sbin/
sudo install -m644 /tmp/99-pixel-ding-longpress /etc/apt/apt.conf.d/
if [ "$MODE" = restore ]; then sudo pixel-ding-longpress --restore; else sudo pixel-ding-longpress --check && sudo pixel-ding-longpress; fi
# khởi động lại ứng dụng DING (gjs .../ding@rastersoft.com/app/ding.js); extension sẽ tự chạy lại
pkill -u ubuntu -f "[d]ing@rastersoft.com/app/ding.js" && echo "đã khởi động lại DING" || echo "DING không chạy"
sleep 4; pgrep -u ubuntu -f "[d]ing@rastersoft.com/app/ding.js" >/dev/null && echo "DING đang chạy lại" || echo "!! DING chưa chạy lại"
INNER
