#!/usr/bin/env bash
# Tạo/mount không gian làm việc trên SSD ngoài (exFAT) dưới dạng sparsebundle
# APFS phân biệt hoa/thường. Idempotent: chạy lại chỉ mount nếu đã tồn tại.
#   Dùng:  scripts/00-workspace.sh          # tạo nếu chưa có + mount
#          scripts/00-workspace.sh detach   # tháo ra an toàn trước khi rút SSD
set -euo pipefail

HOST_VOL="${HOST_VOL:-/Volumes/LIB}"
HOST_DIR="$HOST_VOL/pixel-ubuntu"
BUNDLE="$HOST_DIR/pixelwork.sparsebundle"
VOLNAME="pixelwork"
MNT="/Volumes/$VOLNAME"
MAX_SIZE="${MAX_SIZE:-50g}"   # trần; dung lượng thực chỉ tăng khi ghi dữ liệu

if [[ "${1:-}" == "detach" ]]; then
  hdiutil detach "$MNT"
  exit 0
fi

[[ -d "$HOST_VOL" ]] || { echo "Không thấy $HOST_VOL — cắm SSD vào trước." >&2; exit 1; }
mkdir -p "$HOST_DIR"

if [[ ! -d "$BUNDLE" ]]; then
  echo "Tạo $BUNDLE (tối đa $MAX_SIZE, Case-sensitive APFS)"
  hdiutil create -type SPARSEBUNDLE -fs "Case-sensitive APFS" \
    -volname "$VOLNAME" -size "$MAX_SIZE" "$BUNDLE"
fi

if ! mount | grep -q " on $MNT "; then
  hdiutil attach -owners on "$BUNDLE"
fi

# Không cho Spotlight index (đỡ tốn I/O khi build kernel)
touch "$MNT/.metadata_never_index"
mkdir -p "$MNT"/{downloads,factory,firmware,kernel,rootfs,out,logs}
echo "Workspace sẵn sàng tại $MNT"
df -h "$MNT" "$HOST_VOL"
