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
