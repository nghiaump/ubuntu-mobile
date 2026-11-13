# Kernel

## Nguồn
| Mục | Giá trị |
|---|---|
| Base | mainline **v7.4-rc2** (`7475ea8b5`) — shallow clone torvalds + stable v7.3.4 |
| Vì sao không 7.3.y | series panel v3 xung đột ở patch 4 trên v7.3.4; áp sạch 10/10 trên v7.4-rc2 |
| Series panel | **v3** `20261108-crosshatch-panel-v3-0-87dd4ec4f7cc@ixit.cz` (David Heidelberg), 10 patch, lấy bằng `b4 am -c`; v2 (`20260924-…-v2-0-08d5c7bf72fc`) là bản người dùng nêu ban đầu |
| DTS Pixel 3/3 XL | đã có trong mainline từ 7.0: commit `a678adbf2d22` (series v7 `20251214-pixel-3-v7-0-b1c0cf6f224d@ixit.cz`) |
| Patch riêng | `kernel/patches/0001-HACK-arm64-advertise-TEXT_OFFSET-0x80000-in-Image-header.patch` — chỉ đổi header `.quad 0` → `0x80000` (kernel tự chịu lệch: `pi/map_kernel.c` `kaslr_offset = pa_base % MIN_KIMG_ALIGN`, cần `RELOCATABLE=y`) |
| | `kernel/patches/0002-HACK-arm64-dts-qcom-crosshatch-add-s6sy761-touchscreen.patch` |
| | `0003-HACK-…-add-max1720x-fuel-gauge.patch` (% pin) |
| | `0004-HACK-…-add-speaker-amps-and-sound-card.patch` (2× CS35L36 trên QUAT TDM + node `sound`; pinctrl IRQ **bias-pull-up** — thiếu thì bão IRQ) |
| | `0005-ASoC-qcom-q6asm-reset-playback-queue-state-on-re-prepare.patch` — **sửa lỗi thật** (ứng viên gửi upstream): prepare lại không reset `queue_ptr`/`dsp_buf`/`hw_ptr` → PipeWire phát 1 period rồi kẹt. Chỉ ảnh hưởng module `q6asm`, `q6asm-dai` |
| Bản đang chạy | `7.4.0-rc2-pixel3+ #8` (flash boot_b 2026-11-13 23:3x, `boot-install.img` sha256 `b810fea5…52d2`); module q6asm/q6asm-dai build lại có 0005 (kernel image không đổi) |
| Lưu trữ | `archive/*/kernel/linux-pixel3-<sha>.tar.xz` (toàn bộ source đã vá) + `patches/` + `config-*` |

## Config (`kernel/pixel3.config` merge lên `defconfig`)
| Nhóm | Option | Vì sao |
|---|---|---|
| Boot sớm (=y) | UFS QCOM, QMP UFS, `PHY_QCOM_QMP=y` (menu cha), `TYPEC=y` + `PHY_QCOM_QMP_COMBO=y`, DWC3 QCOM, QUSB2, USB gadget configfs NCM/ACM, `DRM=y` + `SIMPLEDRM=y`, fbcon, EXT4 | rootfs + mạng USB + hình ảnh trước khi có module |
| Supplier phải =y | `SDM_GPUCC_845`, `INTERCONNECT_QCOM_OSM_L3`, `QCOM_LLCC` | driver built-in chờ supplier module quá 10 s → hỏng (SMMU GPU -110, cpufreq) |
| Reboot-mode | `POWER_RESET_QCOM_PON=y` | `reboot bootloader` |
| Module | DRM_MSM, panel S6E3HA8, `REGULATOR_QCOM_LABIBB`, `REGULATOR_QCOM_REFGEN`, Q6V5 MSS/PAS, QRTR, RMTFS_MEM, `QCOM_PD_MAPPER`, ATH10K_SNOC, `POWER_SEQUENCING_QCOM_WCN`, BT HCIUART (+`BT_HCIUART_QCA=y`, `SERIAL_DEV_BUS=y`), IPA, Venus | |
| Sạc / cảm ứng | `CHARGER_QCOM_SMB2=m` + **`QCOM_SPMI_RRADC=m`**, **`TOUCHSCREEN_S6SY761=m`** | |
| Docker | namespaces/cgroups, overlayfs, veth, bridge, nftables + **`NETFILTER_XTABLES_LEGACY=y`** + `IP_NF_*`/`IP6_NF_*`, `NETFILTER_XT_NAT`… | Docker vẫn cần extension xtables (DNAT…) kể cả qua iptables-nft |
| Snap | `SQUASHFS_XZ/ZSTD/LZO/LZ4`, AppArmor (`LSM=…apparmor`) | snapd mount squashfs nén xz |
| Tiết kiệm | `DEBUG_INFO_NONE`, `LOCALVERSION="-pixel3"` | |
- Tên đổi ở 7.x: `SPMI_PMIC_ARB` → **`SPMI_MSM_PMIC_ARB`**; `BT_HCIUART_QCA` là bool.
- `scripts/30-kernel.sh` có danh sách `need_y` / `need_m` — build dừng nếu Kconfig hạ cấp option bắt buộc.
- Chưa bật (việc sau): `BATTERY_MAX1720X`, `SND_SOC_CS35L36`, `VIDEO_IMX355`.

## Build
- `scripts/30-kernel.sh build` trong container `pixel-build:noble`, `O=/work/kernel/build` (bind mount virtiofs).
- Thời gian: lần đầu ~35 phút; thay đổi nhỏ 3–10 phút; đổi option chạm `autoconf.h` (vd netfilter) ~22 phút.
- Output: `/Volumes/pixelwork/out/kernel/` (`Image`, `Image.gz`, dtb, `modules/`, `config`, `kernel.release`).
- Triển khai: `scripts/60-bootimg.sh install` → `scripts/80-deploy-kernel.sh` (RAM) → flash boot_b khi người dùng đồng ý.
