#!/usr/bin/env bash
# Pha 1: trích firmware riêng của máy từ factory image (modem.img FAT + vendor.img ext4)
# và đặt đúng đường dẫn firmware-name trong DTS mainline:
#   qcom/sdm845/Google/blueline/{adsp,cdsp,mba,modem,venus,a630_zap,ipa_fws}.mbn
# (DTS dùng chung thư mục "blueline" cho cả Pixel 3 và 3 XL — xem sdm845-google-common.dtsi)
# Kèm wlanmdsp.mbn + *.jsn (cho tqftpserv/pd-mapper).
# Dùng: scripts/11-extract-firmware.sh [thư mục img của build, mặc định build mới nhất]
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
W=/Volumes/pixelwork
IMG="${1:-$(ls -d "$W"/factory/crosshatch-*/img | sort | tail -1)}"
DEBUGFS=/opt/homebrew/opt/e2fsprogs/sbin/debugfs
command -v mcopy >/dev/null || { echo "thiếu mtools (brew install mtools)" >&2; exit 1; }
[[ -x $DEBUGFS ]] || { echo "thiếu e2fsprogs (brew install e2fsprogs)" >&2; exit 1; }

BUILD="$(basename "$(dirname "$IMG")")"
RAW="$W/firmware/raw-$BUILD"
DEST="$W/firmware/rootfs-overlay/lib/firmware/qcom/sdm845/Google/blueline"
rm -rf "$RAW" "$DEST"; mkdir -p "$RAW/modem" "$RAW/vendor" "$DEST"

echo "== modem.img (FAT) -> $RAW/modem"
mcopy -s -n -i "$IMG/modem.img" ::/ "$RAW/modem/"

echo "== vendor.img (sparse ext4) -> $RAW/vendor"
python3 -I "$HERE/lib/simg2img.py" "$IMG/vendor.img" "$RAW/vendor.raw"
# debugfs cố chown về uid Android → macOS báo "Operation not permitted": vô hại, lọc đi
"$DEBUGFS" -R "rdump /firmware $RAW/vendor" "$RAW/vendor.raw" 2>&1 \
  | grep -v -e '^debugfs ' -e 'changing ownership' || true
rm -f "$RAW/vendor.raw"

# Tìm file theo tên không phân biệt hoa/thường trong cả hai nguồn
find_one() { find "$RAW/modem" "$RAW/vendor" -type f -iname "$1" 2>/dev/null | sort | head -1; }

echo "== Gộp/copy firmware vào $DEST"
for name in adsp cdsp mba modem venus a630_zap ipa_fws wlanmdsp; do
  mbn="$(find_one "$name.mbn")"; mdt="$(find_one "$name.mdt")"
  if [[ -n $mbn ]]; then
    cp "$mbn" "$DEST/$name.mbn"; echo "  $name.mbn  <- copy ${mbn#$RAW/}"
  elif [[ -n $mdt ]]; then
    python3 -I "$HERE/lib/pil_squash.py" "$DEST/$name.mbn" "$mdt" | sed "s|$RAW/||"
  else
    echo "  !! KHÔNG tìm thấy $name (.mbn/.mdt)"
  fi
done
# File JSON mô tả protection domain cho pd-mapper (adspr.jsn, modemr.jsn, ...)
find "$RAW/modem" "$RAW/vendor" -type f -iname '*.jsn' -exec cp {} "$DEST/" \;

# Bản riêng của máy cho BT (WCN3990) và board file Wi-Fi: chưa dùng trực tiếp (DTS không trỏ tới),
# giữ để so với linux-firmware upstream khi test ở Pha 3.
EXTRA="$W/firmware/device-extra"; rm -rf "$EXTRA"; mkdir -p "$EXTRA"
for f in crbtfw21.tlv crnv21.bin bdwlan-crosshatch.bin a630_gmu.bin a630_sqe.fw; do
  [[ -f $RAW/vendor/firmware/$f ]] && cp "$RAW/vendor/firmware/$f" "$EXTRA/"
done
cp "$RAW/modem/verinfo/ver_info.txt" "$EXTRA/" 2>/dev/null || true

echo "== Đối chiếu với firmware-name trong DTS"
for f in adsp cdsp a630_zap ipa_fws mba modem venus; do
  [[ -s $DEST/$f.mbn ]] && echo "  OK   qcom/sdm845/Google/blueline/$f.mbn" \
                        || echo "  THIẾU qcom/sdm845/Google/blueline/$f.mbn"
done
( cd "$DEST" && shasum -a 256 * > "$W/firmware/SHA256SUMS-$BUILD" )
ls -la "$DEST"
echo "Nguồn thô giữ ở $RAW (để tra cứu: BT nvm, board file...)."
