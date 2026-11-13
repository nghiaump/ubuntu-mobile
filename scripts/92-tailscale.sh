#!/usr/bin/env bash
# Pha 5: cài Tailscale (kho apt chính thức, Ubuntu noble arm64) để truy cập điện thoại từ xa.
# Kernel cần CONFIG_TUN (đã =y). Đăng nhập: script in URL, NGƯỜI DÙNG tự mở và đăng nhập tài khoản của họ.
# Dùng: scripts/92-tailscale.sh [host]   (mặc định 172.16.42.1)
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
H="${1:-172.16.42.1}"
SSH=(ssh -o UserKnownHostsFile="$REPO/.ssh_known_hosts" -o BatchMode=yes "ubuntu@$H")
"${SSH[@]}" 'bash -s' <<'REMOTE'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
if ! command -v tailscale >/dev/null; then
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg \
    | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list \
    | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null
  sudo apt-get update -q >/dev/null
  sudo apt-get install -y -q tailscale >/tmp/tailscale-install.log 2>&1 || { tail -20 /tmp/tailscale-install.log; exit 1; }
fi
sudo systemctl enable --now tailscaled >/dev/null 2>&1
tailscale version | head -1
systemctl is-active tailscaled
if tailscale status >/dev/null 2>&1; then
  echo "ĐÃ ĐĂNG NHẬP:"; tailscale ip -4; tailscale status | head -5
else
  echo "== Chưa đăng nhập. URL đăng nhập (người dùng tự mở):"
  # `tailscale up` chờ tới khi đăng nhập xong; chỉ cần lấy URL, phiên chờ vẫn giữ trong tailscaled
  sudo timeout 20 tailscale up --hostname=pixel3xl 2>&1 | grep -E -o "https://login\.tailscale\.com/[^ ]+" | head -1 || true
fi
REMOTE
