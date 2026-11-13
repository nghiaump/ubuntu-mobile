# Kết nối: Wi-Fi, Bluetooth, modem/DSP, NFC

## Kiến trúc (quan trọng để hiểu lỗi)
Firmware **Wi-Fi WCN3990 chạy BÊN TRONG modem (MPSS)**. Chuỗi phụ thuộc:
```
qrtr (ns trong kernel) ─┬─ qcom_q6v5_mss (MBA → MPSS) ── rmtfs (EFS) ── tqftpserv (cấp wlanmdsp.mbn cho modem)
                        └─ qcom_pd_mapper                                   │
pwrseq-qcom-wcn (WCN3990 PMU) ── ath10k_snoc ── chờ dịch vụ QMI "WLFW" của modem ┘ → wlan0
```
- Modem chết/dừng trước Wi-Fi → mọi lệnh WMI timeout `-110` → shutdown treo. Vì vậy rmtfs/tqftpserv `Before=NetworkManager wpa_supplicant`.
- Dừng/khởi động modem bằng tay nhiều lần (log `port failed halt`) từng đi kèm 2 lần reset ở Pha 3 (chưa chứng minh nhân quả).

## Wi-Fi — Qualcomm WCN3990 (ath10k SNOC)
| Mục | Giá trị |
|---|---|
| Node | `wifi@18800000`, `qcom,wcn3990-wifi`, `qcom,calibration-variant = "Google_crosshatch"` |
| Driver | `drivers/net/wireless/ath/ath10k/snoc.c` (`CONFIG_ATH10K_SNOC=m`) |
| Nguồn | `vdd-0.8-cx-mx` = L5 0.8 V; xo/rf/ch0 từ `wcn3990-pmu` (`pwrseq-qcom-wcn.c`, `CONFIG_POWER_SEQUENCING_QCOM_WCN=m`) |
| Chip đo được | `chip_id 0x30214`, `board_id 0xff`, `soc_id 0x40030001`, fw `WLAN.HL.2.2.3-00526-QCAHLSWMTPLZ-1` (2021-07-06) |
| Firmware | `ath10k/WCN3990/hw1.0/board-2.bin` (có variant **Google_crosshatch**, linux-firmware ≥ tag 20261019), `firmware-5.bin` (60 byte, chỉ feature flags), **`qcom/sdm845/Google/blueline/wlanmdsp.mbn`** (từ vendor, modem nạp qua TFTP) |
| MAC | ath10k không đọc được ("invalid MAC address; choosing random") → NM `wifi.cloned-mac-address=stable` (`99-pixel-wifi.conf`) |
| Regdomain | EEPROM regdomain 0x0 → "US" (`ath: Country alpha2 being used: US`); `regulatory.db` từ gói `wireless-regdb` |
| Chế độ AP | Hỗ trợ ("driver supports Access Point (AP) mode") → AP dự phòng `pixel3xl-setup` |

## Bluetooth — WCN3990 qua UART6
| Mục | Giá trị |
|---|---|
| Node | `&uart6` → `bluetooth { compatible = "qcom,wcn3990-bt"; max-speed = <3200000>; }` |
| Driver | `drivers/bluetooth/hci_qca.c` + `btqca.c` (`CONFIG_BT_HCIUART=m`, `BT_HCIUART_QCA=y`, cần `SERIAL_DEV_BUS=y`) |
| Firmware | `qca/crbtfw21.tlv`, `qca/crnv21.bin` (linux-firmware; bản riêng máy lưu ở `firmware/device-extra/` để so sánh) |
| Đo được | "QCA controller version 0x02140201", "QCA setup on UART is completed"; `hci0` BD `39:90:21:64:07:00` (địa chỉ mặc định, chưa cấu hình) |
| Trạng thái | Firmware OK; chưa thử ghép đôi thiết bị |

## Modem & DSP (remoteproc)
| Lõi | Node | Driver | Firmware (`qcom/sdm845/Google/blueline/`) | Vùng nhớ |
|---|---|---|---|---|
| MPSS (modem) | `remoteproc@4080000` | `qcom_q6v5_mss.c` | `mba.mbn` + `modem.mbn` (67 MB, 30 segment) | `mpss_region` 0x8e000000 (152 MB), `mba` 0x98500000 |
| ADSP (âm thanh/cảm biến) | `remoteproc-adsp` | `qcom_q6v5_pas.c` | `adsp.mbn` (13 MB) | |
| CDSP (tính toán) | `remoteproc-cdsp` | `qcom_q6v5_pas.c` | `cdsp.mbn` | `cdsp_mem` 0x97d00000 |
| IPA (mạng modem) | `ipa@1e40000` | `drivers/net/ipa/` | `ipa_fws.mbn` | |
| Venus (video) | `video-codec` | `venus/core.c` | `venus.mbn` | `venus_mem` 0x97800000 |
- Phụ thuộc MSS: `reset-qcom-pdc` (pdc reset), `qcom_aoss` (QMP), `rmtfs_mem` (vùng **0xf2700000**, size 0x202000, guard page 1 kB hai bên — XPU), `qcom_sysmon`, `qrtr`.
- `rmtfs -r -P -s`: **-r = chỉ đọc** phân vùng EFS `modemst1/modemst2/fsg/fsc` (ghi giữ trong RAM), -P dùng phân vùng, -s tự start/stop modem.
  Log "request for unknown partition /boot/modem_fsg_oem_1/2, rejecting" là bình thường.
- `tqftpserv` **v1.3** (tự build) — bản 1.0 noble từ chối `/readonly/vendor/firmware{,_mnt/image}/wlanmdsp.mbn`. Cần `StateDirectory=tqftpserv`.
  Log "unable to open /readonly/vendor/mbn/mcfg_hw/... reject" là bình thường (cấu hình MBN của modem, không cần cho Wi-Fi).
- Dữ liệu di động (4G): modem chạy, QRTR thấy dịch vụ WDS/NAS/UIM… nhưng **chưa cấu hình** (cần ModemManager + qmi/rmnet). Chưa làm.

## NFC — NXP PN557 (chưa thử)
`&i2c3` `nfc@28`, `nxp,pn557`/`nxp,nxp-nci-i2c`, IRQ GPIO 63, enable GPIO 25, firmware GPIO 79 (+ eSE power GPIO 23 trong stock).
Driver `drivers/nfc/nxp-nci/i2c.c` (`CONFIG_NFC_NXP_NCI_I2C=m`).
