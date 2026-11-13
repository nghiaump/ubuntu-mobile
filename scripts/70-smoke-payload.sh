#!/usr/bin/env bash
# Pha 3: đóng gói thử nghiệm để chạy TRONG RAM từ initramfs (không ghi gì vào máy):
#   lib/modules/<rel>, lib/firmware (overlay), rmtfs/tqftpserv/qrtr-lookup/iw + thư viện (lấy từ rootfs.img)
# -> /Volumes/pixelwork/out/smoke/payload.tar ; phục vụ bằng: scripts/70-smoke-payload.sh serve
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
W=/Volumes/pixelwork
if [[ "${1:-build}" == serve ]]; then
  cp "$REPO/scripts/phone/"*.sh "$W/out/smoke/"
  cd "$W/out/smoke" && exec python3 -I -m http.server 8000 --bind 172.16.42.2
fi
exec "$REPO/scripts/20-build-env.sh" priv bash -s <<'INNER'
set -euo pipefail
OUT=/work/out/smoke; P=/tmp/pl; R=/mnt/r
rm -rf "$P"; mkdir -p "$OUT" "$P/bin" "$P/lib" "$P/lib/modules" "$R"
KREL=$(cat /work/out/kernel/kernel.release)
cp -a "/work/out/kernel/modules/lib/modules/$KREL" "$P/lib/modules/"
rm -f "$P/lib/modules/$KREL/build" "$P/lib/modules/$KREL/source"
cp -a /work/firmware/rootfs-overlay/lib/firmware "$P/lib/"
mount -o loop,ro /work/out/rootfs/rootfs.img "$R"
for b in /usr/bin/rmtfs /usr/bin/tqftpserv /usr/bin/qrtr-lookup /usr/sbin/iw; do
  [[ -e $R$b ]] || { echo "thiếu $b"; continue; }
  cp -L "$R$b" "$P/bin/"
  chroot "$R" ldd "$b" | awk '/=>/{print $3} /ld-linux/{print $1}' | while read -r l; do
    [[ -n $l && -e $R$l ]] && cp -L "$R$l" "$P/lib/"
  done
done
# CRDA/cfg80211 cần regulatory.db (gói wireless-regdb trong rootfs)
cp -L "$R"/usr/lib/firmware/regulatory.db* "$P/lib/firmware/" 2>/dev/null || true
umount "$R"
# tqftpserv v1.3 (scripts/55-tqftpserv.sh) thay bản 1.0 của noble (không hiểu /readonly/vendor/...)
cp /work/out/tqftpserv/tqftpserv "$P/bin/tqftpserv"; cp /work/out/tqftpserv/lib*.so.* "$P/lib/"
ls "$P/bin" "$P/lib" | tr '\n' ' '; echo
tar -C "$P" -cf "$OUT/payload.tar" .
ls -la "$OUT/payload.tar"
INNER
