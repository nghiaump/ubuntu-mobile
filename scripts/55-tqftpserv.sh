#!/usr/bin/env bash
# Build tqftpserv từ upstream (gói noble 1.0 KHÔNG hiểu đường dẫn kiểu Pixel
# /readonly/vendor/firmware{,_mnt/image}/ mà modem dùng để xin wlanmdsp.mbn; hỗ trợ có từ PR #43, 05/2026).
# Kết quả: /Volumes/pixelwork/out/tqftpserv/tqftpserv (+ thư viện cần thêm)
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
exec "$REPO/scripts/20-build-env.sh" run bash -s <<'INNER'
set -euo pipefail
TAG=v1.3
SRC=/tmp/tqftpserv OUT=/work/out/tqftpserv
rm -rf "$SRC"; git -c advice.detachedHead=false clone -q --depth 1 --branch $TAG https://github.com/linux-msm/tqftpserv "$SRC"
cd "$SRC" && meson setup build --prefix=/usr >/tmp/meson.log 2>&1 || { tail -20 /tmp/meson.log; exit 1; }; ninja -C build >/dev/null
mkdir -p "$OUT"; cp build/tqftpserv "$OUT/"; strip "$OUT/tqftpserv"
ldd "$OUT/tqftpserv" | tee "$OUT/ldd.txt"
for l in $(ldd "$OUT/tqftpserv" | awk '/=>/{print $3}' | grep -E "libzstd|liblzma|libqrtr"); do cp -L "$l" "$OUT/"; done
git -C "$SRC" log --oneline -1 > "$OUT/version.txt"; ls -la "$OUT"
INNER
