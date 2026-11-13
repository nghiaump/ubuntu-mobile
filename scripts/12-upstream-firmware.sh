#!/usr/bin/env bash
# Pha 2: lấy firmware chung từ linux-firmware upstream (gói noble 20240318 quá cũ:
# board-2.bin chưa chắc có variant Google_crosshatch). Cố định theo tag.
set -euo pipefail
TAG="${LF_TAG:-20261019}"
W=/Volumes/pixelwork
BASE="https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain"
DEST="$W/firmware/rootfs-overlay/lib/firmware"
FILES=(
  ath10k/WCN3990/hw1.0/board-2.bin
  ath10k/WCN3990/hw1.0/firmware-5.bin
  ath10k/WCN3990/hw1.0/notice.txt_wlanmdsp
  qcom/a630_sqe.fw
  qcom/a630_gmu.bin
  qca/crbtfw21.tlv
  qca/crnv21.bin
)
for f in "${FILES[@]}"; do
  mkdir -p "$DEST/$(dirname "$f")"
  curl -fsSL --retry 3 -o "$DEST/$f" "$BASE/$f?h=$TAG"
  printf "%-45s %8d bytes\n" "$f" "$(stat -f %z "$DEST/$f")"
done
# (không dùng `strings | grep -q`: grep thoát sớm → SIGPIPE → pipefail báo lỗi giả)
grep -a -c "variant=Google_crosshatch" "$DEST/ath10k/WCN3990/hw1.0/board-2.bin" >/dev/null \
  && echo "board-2.bin: có variant Google_crosshatch ✔" \
  || { echo "board-2.bin: THIẾU variant Google_crosshatch" >&2; exit 1; }
( cd "$DEST" && shasum -a 256 "${FILES[@]}" > "$W/firmware/SHA256SUMS-linux-firmware-$TAG" )
echo "linux-firmware $TAG -> $DEST"
