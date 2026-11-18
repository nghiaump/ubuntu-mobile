# Nguồn, sạc, pin, nút

## PMIC (mainline DTS: `sdm845-google-common.dtsi`)
| PMIC | Vai trò | Ghi chú |
|---|---|---|
| **PM8998** (pmic-id "a") | PMIC chính: LDO/SMPS, PON (nút nguồn, reboot-mode), RESIN (Vol−), GPIO, ADC5 | `pm8998.dtsi` |
| **PMI8998** (pmic-id "b") | "Interface PMIC": **bộ sạc SMB2**, **RRADC**, **LAB/IBB** (nguồn bias AMOLED), BOB, WLED (không dùng) | `pmi8998.dtsi` |
| **PM8005** (pmic-id "c") | SMPS phụ (S3 0.6 V) | |

### Regulator quan trọng (mainline DTS, `apps_rsc` RPMh)
| Tên | Điện áp | Dùng cho |
|---|---|---|
| `vreg_l1a_0p875` | 0.88 V (boot-on) | USB/UFS/DSI PHY |
| `vreg_l5a_0p8` | 0.8 V | Wi-Fi CX/MX |
| `vreg_l12a_1p8` | 1.8 V | QUSB2 PLL |
| `vreg_l14a_1p8` | 1.8 V, **always-on** | panel `vdd3`, cảm ứng `vdd` (dvdd) |
| `vreg_l17a_1p3` | 1.304 V | WCN3990 RF |
| `vreg_l19a_3p3` | 3.3–3.312 V, chỉ HPM | **cảm ứng `avdd`** ("needs 3.3V… keep HPM to prevent brownouts") |
| `vreg_l20a_2p95` | 2.96 V | UFS `vcc` |
| `vreg_l24a_3p075` | 3.088 V | QUSB2 dp/dm |
| `vreg_l25a_3p3` | 3.3 V | WCN3990 ch0 |
| `vreg_l26a_1p2` | 1.2 V (boot-on) | PHY PLL |
| `vreg_l28a_3p0` | 2.856–3.008 V, **always-on**, LPM | panel `vci` |
| `vreg_bob` | 3.312–3.6 V | LDO cấp cho nhiều nhánh |
| `vph_pwr` | 3.7 V (fixed) | nguồn hệ thống |
| LAB / IBB (PMI8998) | IBB đo được 4.6 V | panel `vddpos` / `vddneg` |

## Bộ sạc — PMI8998 SMB2
| Mục | Giá trị |
|---|---|
| Node | `pmic@2/charger@1000`, `qcom,pmi8998-charger` |
| Driver | `drivers/power/supply/qcom_smbx.c` (`CONFIG_CHARGER_QCOM_SMB2=m`) |
| Phụ thuộc | kênh IIO `usbin_v`/`usbin_i` từ **RRADC**: `drivers/iio/adc/qcom-spmi-rradc.c` (`CONFIG_QCOM_SPMI_RRADC=m`). Thiếu → `deferred probe pending: Couldn't get usbin_v IIO channel` |
| sysfs | `/sys/class/power_supply/pmi8998-charger/` |
| Đo trên máy (cắm cổng USB Mac) | `online=1 status=Charging type=USB usb_type=SDP current_max=500000 current_now≈479 mA voltage_now≈5.06 V` |
| Lưu ý | Cổng Mac là SDP → tối đa 500 mA (sạc chậm). Củ sạc DCP sẽ cho dòng cao hơn (chưa thử). |

Cấu hình sạc gốc của Google (`google,charger`, stock dtbo — Android, không có trong mainline, tham khảo):
| Tham số | Giá trị |
|---|---|
| CV (điện áp sạc) theo nấc | 4.2 / 4.3 / **4.4 V** |
| Ngưỡng nhiệt bảng CC | 0 / 10 / 20 / 42 / 46 / 48 / 55 °C |
| "Battery Defender" | kích hoạt ở ≥ **4.27 V** khi ≥ **35 °C** kéo dài 6 h; xả về 80 %, sạc lại ở 79 % / 4.25 V; tiếp tục khi ≤ 29 °C hoặc 50 % |
| Dung lượng | 3430 mAh |

## Pin + fuel gauge — Maxim MAX1720x (CHƯA làm)
| Mục | Giá trị (stock dtbo, fragment@62, bus `qupv3_se12_i2c` = **i2c12**) |
|---|---|
| Chip | `maxim,max1720x` (họ MAX17201/MAX17205) |
| Địa chỉ I2C | `0x36` (m5db) + `0x0b` (nvram) |
| IRQ | TLMM **GPIO 62**, level-low (`fg,irq-gpio`) |
| Dung lượng thiết kế | `maxim,capacity-design = 0xd66` = **3430 mAh** |
| Battery ID | qua RRADC `rradc_batt_id` |
| Mainline DTS | `&battery`: `charge-full-design-microamp-hours = 3480000` (≠ 3430 mAh của fuel gauge — nên dùng 3430), `voltage-min/max-design 3.6 / 4.4 V` |
| Driver mainline | `drivers/power/supply/max1720x_battery.c`, compatible **`maxim,max17201`** (`CONFIG_BATTERY_MAX1720X`) |
| Việc cần làm | node `fuel-gauge@36` trên `&i2c12` (+ `reg` phụ 0x0b nvmem), IRQ GPIO 62; tham khảo commit sdm845-next `c779a4ee0ee2 "arm64: dts: qcom: sdm845-google: Enable fuel gauge"` (archive) |

## Sạc không dây — IDT P9221 (không có driver mainline)
`idt,p9221` @**0x61** (stock dtbo fragment@44): IRQ GPIO 124, det GPIO 36, `qien` GPIO 122, `slct` GPIO 37.

## Nút & reboot-mode
| Nút | Phần cứng | Driver | Input |
|---|---|---|---|
| Nguồn | PM8998 PON | `pm8941-pwrkey` | `pm8941_pwrkey` (event0) |
| Vol− | PM8998 RESIN | `pm8941-pwrkey` (resin) | `pm8941_resin` |
| Vol+ | PM8998 GPIO 6 | `gpio-keys` | "Volume keys" |

- Reboot-mode: `pm8998_pon` `mode-bootloader = <2>`, `mode-recovery = <1>` → `qcom-pon.c` (`CONFIG_POWER_RESET_QCOM_PON=y`).
  `systemctl reboot --reboot-argument=bootloader` / `rebootarg bootloader` → fastboot.
- **Nút nguồn trong Ubuntu**: `pixel-powerkey.service` (bấm = màn hình mềm tắt/bật, xem [rootfs-services](../software/rootfs-services.md)).
  GNOME `power-button-action='nothing'` (khoá), logind `HandlePowerKey=ignore`. Giữ ~10 s = reset cứng phần cứng.

## Tiêu thụ đo thực tế (2026-11-13, kernel #8, chạy pin, Wi-Fi + Tailscale bật)
| Trạng thái | Dòng | Công suất | Thời lượng ước tính (3093 mAh) |
|---|---|---|---|
| Màn sáng, độ sáng 10/1023, rảnh | ~300 mA | ~1.3 W | ~10 h |
| Tắt màn hình mềm (nút nguồn: backlight 0, cảm ứng tắt) | ~165 mA | ~0.7 W | ~18–19 h |
| + tắt 4 nhân lớn, nhân nhỏ ≤ 1 GHz | ~160 mA | ~0.69 W | lợi ~5% → không áp dụng |
Sàn ~130 mA là phần cứng (panel vẫn quét ở độ sáng 0, MDSS/DSI, modem cho Wi-Fi). Muốn giảm mạnh cần suspend → cần sửa tắt/bật panel (RUNBOOK §6.3).
Đo: `current_now` của `max1720x` (µA, âm = xả), lấy trung bình ≥ 60 s; lần đo 40 s đầu tiên cho số vô lý (5 mA) — luôn đo lặp B→C→B.

## Giới hạn sạc (2026-11-14) ✅ — đang dùng **STOP=60 / START=55** (từ 2026-11-18; trước đó 90/85)
**Khuyến nghị cho server cắm sạc 24/7 (tải nhẹ):** khi cắm, `inhibit-charge` giữ pin **đứng yên** (0 mA, USB cấp điện) → tuổi thọ phụ thuộc
chủ yếu vào **mức pin nằm chờ (STOP)** và nhiệt độ; START chỉ có tác dụng sau khi mất điện (đặt quá thấp, vd. 30 %, chỉ làm mất dự phòng cho lần mất
điện sau, không lợi gì cho pin; cố tình xả vòng 80→30 thì tạo thêm chu kỳ = hại). Bảng chọn:
| Mục tiêu | STOP/START | Điện áp nghỉ ≈ | Dự phòng mất điện (~165 mA) |
|---|---|---|---|
| Bền nhất (đang dùng) | 60/55 | ~3.95 V | ~11 h |
| Cân bằng | 80/75 | ~4.16 V | ~15 h |
| Nhiều dự phòng | 90/85 | ~4.27–4.30 V | ~17 h |
- Pin cao hơn STOP (vừa hạ STOP, hoặc cắm lúc pin đầy): inhibit chỉ dừng nạp nên pin **đứng yên** → dùng **tự xả về trần** (`DRAIN=1`, mặc định, mục dưới).
- Với STOP=60, Defender (ngưỡng 80 %) không còn kích hoạt — mức 60 % đã an toàn với nhiệt.

- Mặc định trong script nếu thiếu file cấu hình: 80/75. 80 % ≈ 4.16 V; 90 % ≈ 4.27–4.30 V lúc nghỉ (pin tối đa 4.4 V).
- Lưu ý: Battery Defender của Google (bảng trên) coi ≥ 4.27 V + ≥ 35 °C kéo dài 6 h là có hại → nếu pin hay nóng ≥ 35 °C, quay về 80/75.
- Dự phòng khi mất điện (tải server ~165 mA, màn tắt): từ 80 % ≈ 15 h, từ 90 % ≈ 17 h (charge_full 3135 mAh, 2026-11-15).

- Kernel: patch 0008 thêm `charge_behaviour` cho `pmi8998-charger` (bit `CHARGING_ENABLE_CMD` 0x42 của SMB2). `inhibit-charge` = ngừng nạp pin, **USB vẫn cấp điện cho máy**
  (khác `status` ghi được sẵn có — cái đó suspend cả USBIN, máy chạy bằng pin).
- Userspace: `pixel-charge-limit.service` → `/usr/local/sbin/pixel-charge-limit.sh`, kiểm mỗi 60 s: ≥ STOP → inhibit, ≤ START → auto.
  Cấu hình `/etc/default/pixel-charge-limit` (`ENABLE=1 STOP=80 START=75`), đổi xong `sudo systemctl restart pixel-charge-limit`.
- Kiểm chứng (cắm USB Mac, pin 97%): inhibit → dòng pin 0 mA, `status=Not charging`; auto → nạp ~440 mA, `Charging`.
- `pmi8998-charger` `current_now`/`voltage_now` (kênh IIO USBIN) đọc 0 — chưa dùng được để đo dòng vào.
- Xem nhanh: lệnh `pin` (hiện "giới hạn: NGỪNG NẠP").

## Tự xả về trần — DRAIN (2026-11-19) ✅
- Vấn đề: hạ STOP 90→60 lúc pin 89 % → `inhibit-charge` giữ nguyên 89 % mãi (USB cấp điện thẳng cho máy).
- `DRAIN=1` (mặc định): pin > `STOP + DRAIN_MARGIN` (60+2) % khi đang cắm → **ngắt nguồn USB vào** (cùng cơ chế Defender, `status=Unknown` → `USBIN_SUSPEND`)
  → máy chạy pin về `STOP` rồi cấp lại; từ đó inhibit giữ pin đứng yên. Biên 2 % tránh bật/tắt liên tục khi pin dao động quanh STOP.
- Đang xả: file `/run/pixel-charge-draining` (nội dung = mức đích), lệnh `pin` hiện "ngắt nguồn USB, tự xả về 60%"; log `journalctl -u pixel-charge-limit | grep "TỰ XẢ\|cấp lại"`.
- An toàn: chỉ ngắt khi pin > trần; cấp lại khi ≤ trần; dịch vụ khởi động/dừng luôn ghi `Charging`. Mạng USB (gadget) vẫn chạy khi ngắt nguồn vào.
- Kiểm chứng 2026-11-19: "TỰ XẢ: ngắt nguồn USB vào, xả từ 89% về 60%", pin xả ~360 mA (server game chạy), `online=0`, SSH USB vẫn OK.
  89→60 % ≈ 1000 mAh ≈ 2.5–3 h.
- Lỗi phụ đã sửa cùng lúc: lúc boot dịch vụ chạy trước khi module `qcom_smbx` tạo `pmi8998-charger` → `cannot create …/status: Directory nonexistent`
  (lệnh cấp lại nguồn lúc khởi động bị mất). Nay chờ tối đa 120 s cho `…/status` xuất hiện.

## USB PD 9 V (2026-11-14) ✅
- Type-C của PMI8998 nằm trong khối USBIN (0x1300) của SMB2 — mainline không có driver; PD PHY (0x1700) cùng IP PM8150B.
- Patch 0012 (backend `qcom_pmic_typec_port_smb2.c`) + 0013 (DT `typec@1300`) + 0014 (qcom_smbx không ghi đè ICL khi > 6 V).
- Sink PDO: 5 V/3 A, **9 V/2 A** (18 W). Adapter allowance `USBIN_ADAPTER_ALLOW_CFG`=5V_TO_9V (bootloader đã đặt sẵn 0x08).
- Kiểm chứng: cục PD (5/9/12/15/20 V + PPS) → `Requesting PDO 1: 9000 mV, 2000 mA` → SNK_READY, USBIN 8.98 V. Cổng Mac: PD 3.0 5V/3A.
- Xem: `cat /sys/class/typec/port0/power_operation_mode` (usb_power_delivery), log TCPM: `sudo sh -c 'cat /sys/kernel/debug/usb/tcpm-*/log'`,
  điện áp/dòng vào: `/sys/class/power_supply/pmi8998-charger/{voltage_now,current_now}` (chỉ khi đang sạc).
- Hạn chế: hợp đồng PD 5 V (Mac 3 A) vẫn bị work 1.5 s của qcom_smbx hạ về Rp (1.5 A) — an toàn nhưng chưa tối ưu. Chưa thử PD hard reset/PPS.

## Defender — tự hạ về 80 % khi pin nóng (2026-11-15) ✅
Giống "Battery Defender" của Google (stock: ≥ 4.27 V + ≥ 35 °C kéo dài 6 h → xả về 80 %), trong `pixel-charge-limit.sh`:
| Bước | Điều kiện (mặc định, `/etc/default/pixel-charge-limit`) | Hành động |
|---|---|---|
| Bật | pin ≥ `DEFEND_STOP` (80) % **và** ≥ `DEFEND_TEMP` (35) °C **liên tục** `DEFEND_MINUTES` (60) phút | giới hạn chuyển `DEFEND_START`–`DEFEND_STOP` (75–80) |
| Xả | đang Defender, pin > 80 %, có nguồn USB | **ngắt nguồn USB vào** (`echo Unknown > …/pmi8998-charger/status` → `USBIN_SUSPEND`, bit 0 của `USBIN_CMD_IL` 0x1340) → máy chạy pin |
| Cấp lại | pin ≤ 80 % hoặc thoát Defender | `echo Charging > …/status` |
| Tắt | nguội ≤ `DEFEND_RELEASE_TEMP` (32) °C liên tục `DEFEND_RELEASE_MINUTES` (30) phút, hoặc rút sạc | về giới hạn thường (90/85) |
- Ngưỡng thời gian để **không phản ứng với nhiệt do sạc nhanh** (pin lên 38–42 °C vài chục phút khi nạp 85→90 %). Google dùng 6 giờ.
- Trạng thái lưu `/run/pixel-charge-defend` (giữ qua restart dịch vụ, mất khi reboot). `DEFEND=0` để tắt.
- **An toàn:** không bao giờ ngắt nguồn vào khi pin ≤ 80 %; dịch vụ khởi động luôn ghi `Charging`; `ExecStopPost` cấp lại nguồn vào khi dịch vụ dừng/crash.
- Khi đang ngắt nguồn vào: `online=0`, `status=Discharging`; mạng USB (gadget) vẫn chạy.
- Kiểm chứng 2026-11-15 (ngưỡng thử 30 °C/1 phút): "DEFENDER BẬT" → "ngắt nguồn USB vào, xả từ 82 % về 80 %" (pin xả 146 mA) → trả cấu hình thật → nạp lại ~1 A.
- Log: `journalctl -u pixel-charge-limit | grep DEFENDER`; cột `behaviour`/`usb_online` trong `/var/log/pixel-power.csv`.
