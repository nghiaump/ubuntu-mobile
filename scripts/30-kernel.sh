#!/usr/bin/env bash
# Pha 2: build kernel mainline cho Pixel 3 XL (chạy trên Mac, build trong container arm64).
#   base       : v7.4-rc2 (series panel v3 KHÔNG áp sạch lên 7.3.4 — xung đột ở patch 4)
#   + series   : "Pixel 3 XL display panel support" v3 (20261108-crosshatch-panel-v3-0-87dd4ec4f7cc@ixit.cz)
#   + patch    : kernel/patches/*.patch của repo (TEXT_OFFSET cho ABL)
#   config     : arm64 defconfig + kernel/pixel3.config
# Kết quả: /Volumes/pixelwork/out/kernel/{Image,Image.gz,sdm845-google-crosshatch.dtb,modules/,config,kernel.release}
# Dùng: scripts/30-kernel.sh [prepare|build|all]   (mặc định all)
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
STEP="${1:-all}"
exec "$REPO/scripts/20-build-env.sh" run bash -s "$STEP" <<'INNER'
set -euo pipefail
STEP="$1"
BASE=v7.4-rc2
SRC=/work/kernel/linux
OUT=/work/kernel/build
DIST=/work/out/kernel
PANEL_MBX=/work/kernel/patches/panel/v3_20261108_david_pixel_3_xl_display_panel_support.mbx
cd "$SRC"
# virtiofs (bind mount Docker Desktop) làm git hiểu nhầm file bị sửa -> nới so sánh stat
git config core.checkStat minimal; git config core.trustctime false

prepare() {
  [[ -f $PANEL_MBX ]] || { mkdir -p "$(dirname "$PANEL_MBX")"
    (cd "$(dirname "$PANEL_MBX")" && b4 am -o . 20261108-crosshatch-panel-v3-0-87dd4ec4f7cc@ixit.cz); }
  git checkout -q -f -B pixel3 "$BASE"
  git am -3 -q "$PANEL_MBX"
  for p in /repo/kernel/patches/*.patch; do git am -3 -q "$p"; done
  echo "== nhánh pixel3:"; git log --oneline "$BASE"..HEAD
}

build() {
  mkdir -p "$OUT" "$DIST"
  make -s O="$OUT" defconfig
  scripts/kconfig/merge_config.sh -m -O "$OUT" "$OUT/.config" /repo/kernel/pixel3.config >/dev/null
  make -s O="$OUT" olddefconfig
  # Những option PHẢI built-in cho lần boot đầu; báo lỗi nếu Kconfig hạ xuống m/n
  need_y="ARCH_QCOM PINCTRL_SDM845 SDM_GCC_845 QCOM_RPMH REGULATOR_QCOM_RPMH INTERCONNECT_QCOM_SDM845
          SCSI_UFSHCD SCSI_UFS_QCOM PHY_QCOM_QMP_UFS USB_DWC3 USB_DWC3_QCOM PHY_QCOM_QUSB2
          PHY_QCOM_QMP_COMBO USB_GADGET USB_CONFIGFS USB_CONFIGFS_NCM USB_CONFIGFS_ACM DRM DRM_SIMPLEDRM
          FRAMEBUFFER_CONSOLE EXT4_FS DEVTMPFS BLK_DEV_INITRD RELOCATABLE
          SDM_GPUCC_845 INTERCONNECT_QCOM_OSM_L3 POWER_RESET_QCOM_PON SQUASHFS_XZ SECURITY_APPARMOR DYNAMIC_DEBUG"
  need_m="BATTERY_MAX1720X SND_SOC_CS35L36 VIDEO_IMX355 TOUCHSCREEN_S6SY761 QCOM_SPMI_RRADC IP_NF_NAT IP_NF_FILTER NETFILTER_XT_NAT IP_NF_TARGET_MASQUERADE DRM_MSM DRM_PANEL_SAMSUNG_S6E3HA8 REGULATOR_QCOM_LABIBB REGULATOR_QCOM_REFGEN POWER_SEQUENCING_QCOM_WCN QCOM_Q6V5_MSS QCOM_Q6V5_PAS ATH10K_SNOC BT_HCIUART BT_HCIUART_QCA NFT_COMPAT NFT_MASQ
          QRTR QCOM_RMTFS_MEM OVERLAY_FS VETH BRIDGE"
  bad=0
  for o in $need_y; do grep -q "^CONFIG_$o=y" "$OUT/.config" || { echo "!! CONFIG_$o không phải y: $(grep "CONFIG_$o[= ]" "$OUT/.config" || echo unset)"; bad=1; }; done
  for o in $need_m; do grep -qE "^CONFIG_$o=(m|y)" "$OUT/.config" || { echo "!! CONFIG_$o chưa bật"; bad=1; }; done
  # Báo những dòng trong fragment không được giữ nguyên (thường do phụ thuộc)
  echo "== Option trong pixel3.config bị Kconfig đổi giá trị:"
  grep -E '^CONFIG_' /repo/kernel/pixel3.config | while IFS='=' read -r k v; do
    got=$(grep -E "^$k=" "$OUT/.config" | cut -d= -f2- || true)
    [[ "$got" == "$v" ]] || echo "   $k: muốn $v, được ${got:-<unset>}"
  done
  [[ $bad == 0 ]] || { echo "Config không đạt" >&2; exit 1; }

  time make -s O="$OUT" -j"$(nproc)" Image Image.gz modules qcom/sdm845-google-crosshatch.dtb
  rm -rf "$DIST"; mkdir -p "$DIST"
  make -s O="$OUT" INSTALL_MOD_PATH="$DIST/modules" INSTALL_MOD_STRIP=1 modules_install
  cp "$OUT/arch/arm64/boot/Image" "$OUT/arch/arm64/boot/Image.gz" "$DIST/"
  cp "$OUT/arch/arm64/boot/dts/qcom/sdm845-google-crosshatch.dtb" "$DIST/"
  cp "$OUT/.config" "$DIST/config"
  make -s O="$OUT" kernelrelease > "$DIST/kernel.release"
  git log --oneline "$BASE"..HEAD > "$DIST/patches.txt"
  # Kiểm tra header Image: text_offset (byte 8..15) phải là 0x80000
  python3 - "$DIST/Image" <<'PY'
import struct,sys
d=open(sys.argv[1],'rb').read(64)
to,sz,fl=struct.unpack_from('<QQQ',d,8); magic=d[56:60]
print(f"Image header: text_offset=0x{to:x} image_size=0x{sz:x} flags=0x{fl:x} magic={magic}")
assert magic==b'ARM\x64' and to==0x80000, "header Image sai"
PY
  echo "== Kernel $(cat "$DIST/kernel.release") ->"; ls -la "$DIST"; du -sh "$DIST/modules"
}

case "$STEP" in
  prepare) prepare ;;
  build)   build ;;
  all)     prepare; build ;;
  *) echo "bước không hợp lệ: $STEP" >&2; exit 1 ;;
esac
INNER
