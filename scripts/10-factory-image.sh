#!/usr/bin/env bash
# Pha 1: tải factory image crosshatch chính thức, kiểm SHA-256, giải nén các image cần thiết.
# Dùng: scripts/10-factory-image.sh <URL dl.google.com ...-factory-xxxx.zip> <SHA256>
# URL và SHA-256 lấy từ https://developers.google.com/android/images (người dùng tự
# đồng ý điều khoản của Google trên trình duyệt rồi copy vào đây).
set -euo pipefail
URL="${1:?thiếu URL}"; SHA="${2:?thiếu SHA256}"
W=/Volumes/pixelwork
[[ -d $W/factory ]] || { echo "Chưa mount workspace: chạy scripts/00-workspace.sh" >&2; exit 1; }
[[ $URL == https://dl.google.com/dl/android/aosp/crosshatch-*-factory-*.zip ]] || {
  echo "URL không giống factory image crosshatch của Google: $URL" >&2; exit 1; }

ZIP="$W/factory/$(basename "$URL")"
if [[ ! -f $ZIP ]] || ! echo "$SHA  $ZIP" | shasum -a 256 -c --status; then
  curl -fL --retry 3 -C - -o "$ZIP" "$URL"
fi
echo "$SHA  $ZIP" | shasum -a 256 -c

BUILD="$(basename "$ZIP" .zip)"; BUILD="${BUILD%-factory-*}"   # crosshatch-sp1a.xxx
OUT="$W/factory/$BUILD"
mkdir -p "$OUT"
# Factory zip: <build>/flash-all.sh, bootloader-*.img, radio-*.img, image-<build>.zip
unzip -o -q "$ZIP" -d "$W/factory"
INNER="$(ls "$OUT"/image-crosshatch-*.zip)"
# Chỉ lấy những image cần: firmware (vendor, modem) + tham chiếu stock (boot, dtbo, vbmeta)
unzip -o -q "$INNER" vendor.img boot.img dtbo.img vbmeta.img android-info.txt -d "$OUT/img"
# modem.img (FAT16) KHÔNG nằm trong image-*.zip mà nằm trong radio-*.img (container FBPK v1).
python3 -I "$(dirname "$0")/lib/fbpk_unpack.py" "$(ls "$OUT"/radio-crosshatch-*.img)" "$OUT/img"
ls -la "$OUT" "$OUT/img"
( cd "$OUT/img" && shasum -a 256 ./*.img > SHA256SUMS )
echo "Xong. Image ở $OUT/img ; flash-all.sh ở $OUT (đường lui khôi phục Android)."
