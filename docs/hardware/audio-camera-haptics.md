# Âm thanh, camera, rung (loa ✅ 2026-11-13; camera, rung chưa)

## Loa — 2× Cirrus Logic CS35L36 (smart amp) + codec Qualcomm WCD934x
| Mục | Giá trị (stock dtbo fragment@96, bus `qupv3_se12_i2c` = **i2c12**) |
|---|---|
| Loa dưới (phải) | `cs35l36@40`: reset **GPIO 112**, IRQ **GPIO 115** (level-low) |
| Loa trên (trái) | `cs35l36@41` (DTS mainline có placeholder "Top spkr (left) CS35L36 @ 41"; GPIO xem `generated/stock-c1-overlay.dts`) |
| Boost | cuộn `1000 nH`, `boost-ctl-select 1`, áp **10 V** (`0x2710` mV), dòng đỉnh **3.7 A** (`0xe74` mA) |
| Khác | `amp-gain-zc`, `multi-amp-mode`, LDM (pdm enter/exit), weak-FET delay 4 / thld 1, IRQ cấu hình output enable |
| Codec | WCD9340 (SLIMbus) — `sound/soc/codecs/wcd934x.c` (`CONFIG_SND_SOC_WCD934X=m`) |
| Máy chủ âm thanh | ADSP (q6afe/q6asm/q6adm/q6routing) + machine driver `sound/soc/qcom/sdm845.c` (`CONFIG_SND_SOC_SDM845=m`) |
| Driver amp | `sound/soc/codecs/cs35l36.c` — `CONFIG_SND_SOC_CS35L36=m` |
| Trạng thái | ✅ **Loa chạy** (ALSA + PipeWire + GNOME, phím âm lượng). Micro, tai nghe USB-C: chưa |

### Đường âm thanh đang chạy
`PipeWire → hw:0,0 (MultiMedia1, q6asm-dai) → q6routing → QUAT_TDM_RX_0 → 2× CS35L36 (Left=@0x41 trên, Right=@0x40 dưới)`
| Thông số | Giá trị / lý do |
|---|---|
| Định dạng | **S16_LE** 48 kHz 2 kênh (DSP từ chối S24/S32 ở đường này) |
| Buffer | ADSP từ chối buffer playback ≥ ~522 KB (`q6asm DSP returned error`, `Memory_map_regions failed`); PipeWire dùng period 480 × 4 — ổn |
| Mixer (`/usr/local/sbin/pixel-sound.sh`, `pixel-sound.service`) | `QUAT_TDM_RX_0 Audio Mixer MultiMedia1`=on; `Left/Right Channel Mux`=RX1; `Left/Right Digital PCM Volume`=768 (−6 dB; thang 0..912 = −102..+12 dB, 816 = 0 dB); `AMP Enable`, `BOOST Enable`=on |
| Nạp card | `snd-soc-sdm845` để trong `modules-load.d` → EINVAL; service thử `modprobe` lặp tới khi `/proc/asound/cards` có "Pixel 3 XL" |
| WirePlumber | `/etc/wireplumber/main.lua.d/51-pixel3-audio.lua`: **`api.alsa.use-acp=false`** (ACP làm profile về "off", sink không thành mặc định), S16LE, tên "Loa Pixel 3 XL" |
| Kernel | patch 0004 (DT) + **0005** (q6asm re-prepare — thiếu thì PipeWire phát vài ms rồi kẹt RUNNING, `hw_ptr` đứng) |
| Phím âm lượng | Vol+ = `gpio-keys` "Volume keys" (KEY_VOLUMEUP), Vol− = `pm8941_resin` (KEY_VOLUMEDOWN) → GNOME `gsd-media-keys`, bước 6% |
| Thử nhanh | `pw-play /usr/share/sounds/freedesktop/stereo/complete.oga`; ALSA trần: dừng PipeWire rồi `aplay -D hw:0,0 x.wav` (S16_LE 48 kHz) |
| Bẫy | `speaker-test -b` tính bằng **µs** (`-b 20000` = 20 ms, quá nhỏ); tháo/nạp lại `q6asm` khi đang chạy làm APR mất service 7 → phải reboot |

## Rung — Cirrus CS40L20 (không có driver mainline)
`cs40l20@43`: reset **GPIO 87**, boost 1000 nH / 4 µF / 4.5 A, `f0-default 0x265c50`, `redc-default 0x50030`.

## Camera (CAMSS + CCI)
| Vị trí | Cảm biến | Stock (fragment@7) | Driver mainline |
|---|---|---|---|
| Sau (`cam-sensor@0`, yaw 180°) | Sony **IMX363** 12.2 MP (theo thông số công khai; DT không ghi tên) | csiphy 0, `cci-master 0`, có actuator (AF) + eeprom, MCLK 24 MHz, `vdig` 1.352 V, `vana` ~3.3 V | **không có** (phải viết driver) |
| Trước (`cam-sensor@1`) | Sony **IMX355** 8 MP | csiphy 2, `cci-master 1`, có actuator + eeprom, `cam_vaf` | `drivers/media/i2c/imx355.c` (**`VIDEO_IMX355` chưa bật**) |
| Trước góc rộng (`cam-sensor@2`) | Sony IMX355 (chưa kiểm chứng — DT không ghi tên cảm biến) | csiphy 1, `cci-master 1`, eeprom, không actuator | như trên |
- DTS mainline: `&cci` okay; `&cci_i2c1` có placeholder *actuator @0c, front camera imx355 @1a, eeprom @50*.
- Khung: `drivers/media/platform/qcom/camss/` (`CONFIG_VIDEO_QCOM_CAMSS=m`), `i2c-qcom-cci.c` (`=m`).
- SDM845 mainline **chưa có ISP phần cứng** → libcamera *Software ISP*: ảnh mờ/màu chưa chuẩn, chậm.
- sdm845-next có nhiều commit camera (CCI, C-PHY, actuator LC898217XC) — xem `archive/*/sources/sdm845-next-commits.txt`.
- PMIC camera: Samsung `s2mpb04` (stock fragment@35) — cần cho nguồn camera (chưa xác minh trong mainline).
