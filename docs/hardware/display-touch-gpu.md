# Màn hình, cảm ứng, GPU

## Panel — Samsung AMB630QY01 / DDIC S6E3HA8
| Mục | Giá trị | Nguồn |
|---|---|---|
| Kích thước / độ phân giải | 6.3", **1440×2960**, AMOLED, chế độ **command mode** DSC | mainline DTS, ABL cmdline `dsi_s6e3ha8_cmd_display` |
| Giao tiếp | MIPI DSI0, 4 lane (`data-lanes = <0 1 2 3>`), `qcom,te-source = "mdp_vsync_e"` | series panel v3 |
| Compatible | `samsung,s6e3ha8-amb630qy01` (fallback `samsung,s6e3ha8`) | series panel v3 |
| Driver | `drivers/gpu/drm/panel/panel-samsung-s6e3ha8.c` (`CONFIG_DRM_PANEL_SAMSUNG_S6E3HA8=m`) | |
| Reset | TLMM **GPIO 6**, active-low | series v3 |
| Nguồn | `vdd3` = L14 1.8 V, `vci` = L28 ~3.0 V, `vddpos` = **LAB**, `vddneg` = **IBB** (−/+4.6 V) | series v3 |
| Phụ thuộc thêm | `qcom-refgen-regulator` (ref DSI PHY @ff1000) + `qcom-labibb-regulator` → thiếu thì DSI/panel deferred | đo |
| Backlight | `/sys/class/backlight/ae94000.dsi.0`, raw, **max 1023** (mặc định 512, đang đặt 40 bằng udev) | đo |
| DRM | `card1-DSI-1`, fb `msmdrmfb`; display controller DPU rev 0x40000000 | dmesg |

⚠️ **KHÔNG ĐƯỢC TẮT PANEL** (DPMS off / GNOME blank / suspend): máy reset cứng sau đó (~300 s đúng mốc idle-delay).
DTS ghi: *"We can't properly bring the panel back if it gets turned off so keep it's regulators always on"*.
→ idle-delay=0 + khoá dconf; nút nguồn dùng backlight 0 thay cho tắt. Sửa tận gốc = sửa trình tự tắt/bật panel trong driver.

### Framebuffer từ bootloader (simple-framebuffer, trước khi `msm` nạp)
`chosen/framebuffer-0`: vùng nhớ `cont_splash_mem` **0x9d400000**, size 0x2400000, `a8r8g8b8`, 1440×2960, stride 5760.
Driver `drivers/gpu/drm/sysfb/simpledrm.c` (`CONFIG_DRM_SIMPLEDRM=y`). `msm` nạp sẽ chiếm phần cứng → simplefb tắt.

## Cảm ứng — Samsung S6SY761
| Mục | Giá trị | Nguồn |
|---|---|---|
| Chip | **S6SY761** (stock: `sec,sec_ts`, firmware `s6sy761.fw` nằm trong flash chip) | stock dtbo fragment@81 |
| ⚠️ Khác Pixel 3 | Pixel 3 (blueline) dùng **STM FTS5 @0x49** — patch sdm845-next KHÔNG áp cho 3 XL | sdm845-next `ca2ea3ca` |
| Bus | `qupv3_se2_i2c` = **`&i2c2`**, 400 kHz | stock |
| Địa chỉ | **0x48** | stock |
| IRQ | TLMM **GPIO 125**, `IRQ_TYPE_LEVEL_LOW` | stock |
| Reset | TLMM **GPIO 99**, giữ **mức cao** (stock `sec_ts_reset_active` output-high) → gpio-hog | stock |
| Chuyển bus I2C | TLMM **GPIO 136**, mức **cao = bus về AP** (theo patch blueline `GPIOD_OUT_HIGH`) → gpio-hog | stock + sdm845-next |
| Nguồn | `vdd` = L14 1.8 V (stock `pm8998_l14` dvdd), `avdd` = L19 3.3 V (`pm8998_l19`) | stock |
| Toạ độ | 1440×2960 (`sec,max_coords`) | stock |
| Driver | `drivers/input/touchscreen/s6sy761.c`, `samsung,s6sy761` (`CONFIG_TOUCHSCREEN_S6SY761=m`) | |
| Patch | `kernel/patches/0002-HACK-arm64-dts-qcom-crosshatch-add-s6sy761-touchscreen.patch` | repo |
| Kết quả | `input: s6sy761 … 2-0048/input/input3` (event3); cảnh báo "the axis have not been set" vô hại | dmesg |
| Khoá tạm thời | `/sys/class/input/event3/device/inhibited` = 1 (dùng khi tắt màn hình mềm) | |

## GPU — Adreno 630
| Mục | Giá trị |
|---|---|
| Driver | `drivers/gpu/drm/msm/` (`adreno/adreno_device.c`), `CONFIG_DRM_MSM=m` |
| Firmware | `qcom/a630_sqe.fw`, `qcom/a630_gmu.bin` (linux-firmware), **`qcom/sdm845/Google/blueline/a630_zap.mbn`** (riêng máy, ký Google) |
| Phụ thuộc | `gpucc-sdm845` **=y** (nếu =m: SMMU GPU `5040000.iommu` probe lỗi -110 sau 10 s deferred) |
| Userspace | Mesa freedreno (Ubuntu noble). GNOME trên panel = Wayland GPU; xrdp = Xorg phần mềm |
