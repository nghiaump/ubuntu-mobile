#!/usr/bin/env bash
# Tạo DTB biến thể bằng fdtput (thử tham số DT không cần build lại kernel), rồi đóng boot.img riêng.
# Dùng: scripts/61-dtb-variant.sh <tên> "<đường dẫn node>:<thuộc tính>=<giá trị u32>" [...]
# Ví dụ: scripts/61-dtb-variant.sh tdm-long "/remoteproc-adsp/glink-edge/apr/service@4/dais/dai@72:qcom,tdm-sync-mode=1"
# Kết quả: /Volumes/pixelwork/out/boot/boot-install-<tên>.img (thử bằng fastboot boot, KHÔNG flash)
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
NAME="${1:?tên biến thể}"; shift
EDITS="$*"
"$REPO/scripts/20-build-env.sh" run env NAME="$NAME" EDITS="$EDITS" bash -s <<'INNER'
set -euo pipefail
K=/work/out/kernel; V=/work/out/variants/$NAME; mkdir -p $V
cp $K/sdm845-google-crosshatch.dtb $V/
for e in $EDITS; do
  node=${e%%:*}; rest=${e#*:}; prop=${rest%%=*}; val=${rest#*=}
  fdtput -t u $V/sdm845-google-crosshatch.dtb "$node" "$prop" "$val"
  echo "  $node $prop = $(fdtget -t u $V/sdm845-google-crosshatch.dtb "$node" "$prop")"
done
INNER
# đóng boot.img với DTB biến thể (60-bootimg.sh đọc DTB từ out/kernel -> tạm thay rồi trả lại)
W=/Volumes/pixelwork/out
cp "$W/kernel/sdm845-google-crosshatch.dtb" "$W/kernel/sdm845-google-crosshatch.dtb.orig"
cp "$W/variants/$NAME/sdm845-google-crosshatch.dtb" "$W/kernel/sdm845-google-crosshatch.dtb"
trap 'mv "$W/kernel/sdm845-google-crosshatch.dtb.orig" "$W/kernel/sdm845-google-crosshatch.dtb"' EXIT
cp "$W/boot/boot-install.img" "$W/boot/boot-install.img.keep" 2>/dev/null || true
"$REPO/scripts/60-bootimg.sh" install >/dev/null
mv "$W/boot/boot-install.img" "$W/boot/boot-install-$NAME.img"
[[ -f $W/boot/boot-install.img.keep ]] && mv "$W/boot/boot-install.img.keep" "$W/boot/boot-install.img"
ls -la "$W/boot/boot-install-$NAME.img"
