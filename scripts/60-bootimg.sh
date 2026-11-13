#!/usr/bin/env bash
# Tạo boot.img cho ABL Pixel 3 XL. Thông số lấy theo boot.img stock (unpack_bootimg):
#   header v2, pagesize 4096, base 0, kernel 0x8000, ramdisk 0x01000000, tags 0x100, dtb 0x01f00000,
#   kernel nén LZ4 frame (giống stock), DTB trong section dtb (header v2).
# Dùng: scripts/60-bootimg.sh smoke     -> out/boot/boot-smoke.img   (ở lại initramfs, shell debug)
#       scripts/60-bootimg.sh install   -> out/boot/boot-install.img (switch_root vào LABEL=pixelroot)
#       EXTRA_CMDLINE="..." để thêm tham số.
#       BOARD_ID=0x11505 : ghi đè qcom,board-id trong DTB (mainline ghi 0x21505 = "B1 DVT1.1" của Pixel 3;
#                          dtbo stock: C1 = 3 XL dùng 0x1xx05, cao nhất "C1 DVT1.1" = 0x11505)
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:?smoke|install}"
case "$MODE" in
  smoke)   ROOTARG="" ;;
  install) ROOTARG="pixel.root=LABEL=pixelroot pixel.rootfstype=ext4 net.ifnames=0" ;;  # net.ifnames=0: giữ tên usb0/wlan0
  *) echo "mode: smoke|install" >&2; exit 1 ;;
esac
CMDLINE="console=tty0 loglevel=7 clk_ignore_unused pd_ignore_unused $ROOTARG ${EXTRA_CMDLINE:-}"
# Mặc định 0x11505: ABL của 3 XL từ chối DTB mainline (0x21505 = Pixel 3) — "Invalid Parameter" (smoke test #1)
exec "$REPO/scripts/20-build-env.sh" run env BOARD_ID="${BOARD_ID-0x11505}" bash -s "$MODE" "$CMDLINE" <<'INNER'
set -euo pipefail
MODE="$1"; CMDLINE="$(echo $2)"
K=/work/out/kernel; OUT=/work/out/boot
[[ -f $OUT/initramfs.cpio.gz ]] || { echo "Chưa có initramfs (scripts/40-initramfs.sh)" >&2; exit 1; }
lz4 -q -f -9 "$K/Image" "$OUT/Image.lz4"
DTB="$K/sdm845-google-crosshatch.dtb"
if [[ -n "$BOARD_ID" ]]; then
  cp "$DTB" "$OUT/crosshatch-boardid.dtb"; DTB="$OUT/crosshatch-boardid.dtb"
  fdtput -t x "$DTB" / qcom,board-id "$BOARD_ID" 0
fi
echo "DTB board-id: $(fdtget -t x "$DTB" / qcom,board-id)  msm-id: $(fdtget -t x "$DTB" / qcom,msm-id)"
mkbootimg --header_version 2 \
  --kernel "$OUT/Image.lz4" --ramdisk "$OUT/initramfs.cpio.gz" --dtb "$DTB" \
  --base 0x0 --kernel_offset 0x00008000 --ramdisk_offset 0x01000000 --tags_offset 0x00000100 \
  --dtb_offset 0x01f00000 --pagesize 4096 --os_version 12.0.0 --os_patch_level 2022-06 \
  --cmdline "$CMDLINE" -o "$OUT/boot-$MODE.img"
# ABL Pixel 3 từ chối boot.img không có AVB footer ("Error verifying the received boot.img: Invalid
# Parameter"). boot.img stock = 64 MiB, có AVBf footer. Thêm hash footer ký bằng test key AOSP
# (máy đã unlock nên chấp nhận khoá lạ); salt cố định để kết quả tái lập được.
avbtool add_hash_footer --image "$OUT/boot-$MODE.img" --partition_name boot --partition_size 67108864 \
  --algorithm SHA256_RSA2048 --key /opt/avb/test/data/testkey_rsa2048.pem \
  --salt 7069786533786c2d6d61696e6c696e65 --rollback_index 0
avbtool info_image --image "$OUT/boot-$MODE.img" | grep -E "Footer version|Image size|Algorithm|Partition Name|Original image size"
unpack_bootimg --boot_img "$OUT/boot-$MODE.img" --out /tmp/chk | grep -E "header version|kernel_size|ramdisk size|dtb size|command line"
SZ=$(stat -c %s "$OUT/boot-$MODE.img")
echo "boot-$MODE.img: $SZ bytes (phân vùng boot = 67108864)"
[[ $SZ -le 67108864 ]] || { echo "!! boot.img lớn hơn phân vùng boot" >&2; exit 1; }
sha256sum "$OUT/boot-$MODE.img" | tee "$OUT/boot-$MODE.img.sha256"
INNER
