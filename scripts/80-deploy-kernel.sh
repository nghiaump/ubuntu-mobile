#!/usr/bin/env bash
# Pha 4+: đưa kernel/module mới lên Ubuntu đang chạy (qua SSH USB), rồi về fastboot và `fastboot boot` thử.
# KHÔNG flash: muốn ghi boot_b phải chạy riêng (và hỏi người dùng).
# Dùng: scripts/80-deploy-kernel.sh [host]   (mặc định 172.16.42.1)
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
W=/Volumes/pixelwork; H="${1:-172.16.42.1}"
SSH=(ssh -o UserKnownHostsFile="$REPO/.ssh_known_hosts" -o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=2 -o ServerAliveCountMax=3 "ubuntu@$H")
KREL=$(cat "$W/out/kernel/kernel.release")
echo "== đẩy module $KREL + /boot/pixel"
COPYFILE_DISABLE=1 tar --no-xattrs --no-mac-metadata -C "$W/out/kernel/modules/lib/modules" --exclude "._*" --exclude build --exclude source -czf - "$KREL" \
  | "${SSH[@]}" "sudo rm -rf /usr/lib/modules/$KREL.new && sudo mkdir -p /usr/lib/modules/$KREL.new && sudo tar -C /usr/lib/modules/$KREL.new -xzf - --no-same-owner \
     && sudo rm -rf /usr/lib/modules/$KREL && sudo mv /usr/lib/modules/$KREL.new/$KREL /usr/lib/modules/$KREL && sudo rmdir /usr/lib/modules/$KREL.new \
     && sudo depmod -a $KREL && echo depmod ok"
COPYFILE_DISABLE=1 tar --no-xattrs --no-mac-metadata -C "$W/out/kernel" -cf - Image.gz sdm845-google-crosshatch.dtb config | "${SSH[@]}" "sudo tar -C /boot/pixel -xf - --no-same-owner"
echo "== reboot -> bootloader"
"${SSH[@]}" "sudo sync; sudo systemctl reboot -ff --reboot-argument=bootloader" || true
until fastboot devices | grep -q fastboot; do sleep 2; done
fastboot boot "$W/out/boot/boot-install.img"
echo "== chờ SSH"
for i in $(seq 1 60); do "${SSH[@]}" true 2>/dev/null && break; sleep 3; done
"${SSH[@]}" "uname -v; systemctl is-system-running"
