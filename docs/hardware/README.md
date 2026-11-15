# Phần cứng — tổng hợp

## Định danh máy (đo trên máy / fastboot / stock DTB)
| Mục | Giá trị |
|---|---|
| Model / codename | Google Pixel 3 XL / `crosshatch` (bo **C1**; Pixel 3 = `blueline`, bo B1) |
| SKU / revision | G013D / MP1.0 (`androidboot.hardware.sku`, `ro.boot.hardware.revision`) |
| SoC | Qualcomm **SDM845** v2.1 — `qcom,msm-id = <0x141 0x20001>` |
| CPU | 4× Kryo-3XX-Gold (825–2650 MHz) + 4× Kryo-3XX-Silver (300–1766 MHz) |
| RAM | 4 GB LPDDR4X Micron (`MemTotal` 3.6 GB trong Linux) |
| Lưu trữ | UFS 64 GB Micron, 6 LUN `sda`…`sdf` |
| Board-id cho ABL | **`0x11505`** (C1 DVT1.1). Mainline DTS ghi `0x21505` (B1 DVT1.1) → ABL 3 XL từ chối |
| `cdt_hwid` | 0x05012801 |
| Bootloader / baseband | `b1c1-0.4-7617406` / `g845-00194-210812-B-7635520` |
| Hình dán dtbo ABL áp | `androidboot.dtbo_idx=13` (= entry id 0x115) |

Bảng 14 overlay trong `dtbo.img` gốc: `archive/*/stock/dtbo-index.txt` (B1 = 0x2xx, C1 = 0x1xx).

## Trạng thái từng khối (2026-11-13)
| Khối | Chip | Driver mainline | Trạng thái | Chi tiết |
|---|---|---|---|---|
| CPU/cpufreq/GPU clocks | SDM845 | `qcom-cpufreq-hw`, `gpucc-sdm845` | ✅ | [kernel](../software/kernel.md) |
| Lưu trữ | UFS Micron | `ufs-qcom` | ✅ | [storage-usb](storage-usb.md) |
| USB-C (thiết bị) | DWC3 + QUSB2 + QMP combo | `dwc3-qcom` | ✅ peripheral (NCM+ACM) | [storage-usb](storage-usb.md) |
| Màn hình | Samsung **AMB630QY01** (DDIC **S6E3HA8**) | `panel-samsung-s6e3ha8` + `msm` DSI | ✅ — ⚠️ **không được tắt panel** (reset) | [display](display-touch-gpu.md) |
| Cảm ứng | Samsung **S6SY761** | `s6sy761` | ✅ (patch DT riêng) | [display](display-touch-gpu.md) |
| GPU | Adreno 630 | `msm` (freedreno) | ✅ firmware nạp | [display](display-touch-gpu.md) |
| Wi-Fi | **WCN3990** (ath10k SNOC) | `ath10k_snoc` | ✅ | [connectivity](connectivity.md) |
| Bluetooth | WCN3990 (UART6) | `hci_uart`/`btqca` | ✅ (cần `pixel-bt-addr.service` gán địa chỉ) | [connectivity](connectivity.md) |
| Modem / DSP | MPSS, ADSP, CDSP | `qcom_q6v5_mss/pas` | ✅ chạy (chưa có dữ liệu di động) | [connectivity](connectivity.md) |
| Sạc | **PMI8998** (SMB2) | `qcom_smbx` + RRADC | ✅ `Charging` (500 mA từ cổng Mac) | [power](power-battery.md) |
| % pin | **Maxim MAX1720x** @0x36 | `max1720x_battery` | ✅ (patch 0003, kernel #7) — 99 %, pin còn ~85 % dung lượng | [power](power-battery.md) |
| Sạc không dây | IDT **P9221** @0x61 | — | ❌ không có driver mainline | [power](power-battery.md) |
| Loa | 2× Cirrus **CS35L36** @0x40/0x41 + WCD934x | `cs35l36`, `sdm845` | ❌ chưa làm | [audio](audio-camera-haptics.md) |
| Rung | Cirrus **CS40L20** @0x43 | — (không có; `cs40l50` là đời khác) | ❌ không có driver | [audio](audio-camera-haptics.md) |
| Camera sau | Sony **IMX363** | — | ❌ không có driver mainline | [audio](audio-camera-haptics.md) |
| Camera trước ×2 | Sony **IMX355** | `imx355` + CAMSS | ❌ chưa làm (khả thi, ảnh xấu) | [audio](audio-camera-haptics.md) |
| NFC | NXP **PN557** @0x28 | `nxp-nci-i2c` | ❓ node có trong DTS, chưa thử | [connectivity](connectivity.md) |
| Vân tay | FPC1075 (SPI, GPIO 81–84 reserved) | — | ❌ | — |
| Titan M (Citadel), Pixel Visual Core | SPI | — | ❌ (GPIO 0–3 reserved) | — |
| Nút | Power (PON), Vol+ (GPIO pm8998 6), Vol− (RESIN) | `pm8941-pwrkey`, `gpio-keys` | ✅ | [power](power-battery.md) |

Bản đồ đầy đủ node → driver → Kconfig: [`../generated/driver-map.md`](../generated/driver-map.md).
