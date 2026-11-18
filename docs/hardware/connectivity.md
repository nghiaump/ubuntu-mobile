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
| Đo được | "QCA controller version 0x02140201", "QCA setup on UART is completed" |
| Trạng thái | ✅ (2026-11-15) — controller lên, BlueZ thấy (`Powered: yes`), quét thấy thiết bị xung quanh. Ghép đôi: dùng GNOME Settings → Bluetooth |

### Vấn đề "No default controller available" và cách sửa
- Mainline để WCN3990 ở trạng thái **Unconfigured controller — missing options: public-address** (`btmgmt config`): ABL không truyền
  địa chỉ BT (không có `androidboot.btmacaddr`, DT `local-bd-address` = 0). BlueZ bỏ qua controller unconfigured → GNOME không có Bluetooth.
- Địa chỉ gốc của máy nằm trong phân vùng `persist` của Android — **không đụng** (luật an toàn).
- Sửa: **`pixel-bt-addr.service`** (overlay) → `/usr/local/sbin/pixel-bt-addr.sh`: chờ `hci0`, nếu thiếu địa chỉ thì
  `btmgmt --index 0 public-addr <địa chỉ>`. Địa chỉ **ổn định, duy nhất theo máy**: `sha256("pixel3xl-bt-" + androidboot.serialno)` 6 byte đầu,
  bit locally-administered = 1, multicast = 0 (giống MAC Wi-Fi "stable"). Ghi đè: `BDADDR=…` trong `/etc/default/pixel-bt-addr`.
- Bẫy `btmgmt` (bluez 5.72, bt_shell) trong dịch vụ: stdin `/dev/null` → thoát ngay **trước khi** có phản hồi (không in gì, tưởng "đã cấu hình");
  không stdin → chờ mãi. Dùng `sleep 2 | timeout 5 btmgmt …`.
- **Race lúc boot (2026-11-15, phát hiện khi khởi động lại thật):** `hci0` có trong sysfs ở ~5.5 s nhưng btqca nạp firmware xong ở ~6.3 s;
  hỏi mgmt trong khoảng đó controller chưa nằm trong danh sách nào → bản đầu tưởng "đã có địa chỉ" và bỏ qua → Bluetooth không lên.
  Sửa: lặp tối đa 60 s tới khi controller là *Unconfigured* (gán) hoặc có trong `btmgmt info` (đã cấu hình). Tái hiện: `rmmod hci_uart && modprobe hci_uart && systemctl restart pixel-bt-addr` ngay lập tức → gán thành công.
- Kiểm chứng: `rmmod hci_uart && modprobe hci_uart` (controller về unconfigured) → `systemctl restart pixel-bt-addr` → "Set Public Address complete" → `Powered: yes`.
- Lựa chọn khác (chưa làm): đặt `local-bd-address` trong DT (cần build/flash DTB).

### Gửi/nhận file (OBEX) — 2026-11-15/18
- Triệu chứng: ghép đôi OK nhưng gửi file báo **"not sent"**. Hai nguyên nhân chồng nhau:
  1. **Kernel thiếu `CONFIG_BT_RFCOMM`** (OBEX chạy trên RFCOMM): bluetoothd log `RFCOMM server failed for Object Push: socket(STREAM, RFCOMM): Protocol not supported`.
     Cũng thiếu `BT_BNEP` (PAN) và `BT_LE` (BLE). Đã thêm vào `kernel/pixel3.config` (+ `need_m` trong `30-kernel.sh`); build #11.
  2. **GNOME 46 không có thành phần nhận file**: `obexd` (bluez-obexd) chỉ chạy khi được gọi, không có agent chấp nhận "push".
     → **`pixel-obex-agent`** (user service, `/usr/local/bin/`): đăng ký `org.bluez.obex.AgentManager1` (kích hoạt obexd), **chỉ nhận từ thiết bị đã ghép đôi**,
     lưu `~/Downloads/Bluetooth` (drop-in `obex.service` `-r Downloads/Bluetooth`), thông báo GNOME khi xong. Bật: `systemctl --global enable pixel-obex-agent`.
- Kiểm: `bluetoothctl show | grep "Object Push"` → `UUID: OBEX Object Push (00001105-…)`; log agent: `journalctl --user -u pixel-obex-agent`.

### Thay nóng module Bluetooth (không flash, không reboot)
Toàn bộ Bluetooth là module, lõi kernel không đổi khi chỉ đổi option `BT_*` → build module mới rồi thay trên máy:
1. Chép `net/bluetooth`, `drivers/bluetooth` từ `out/kernel/modules/lib/modules/<krel>/kernel/` vào `/lib/modules/<krel>/kernel/`, `depmod -a`
   (bản cũ sao lưu `/var/backups/bt-modules-k10/`).
2. **Bẫy:** `systemctl stop bluetooth` bị huỷ ("Job canceled") vì có thành phần kéo nó chạy lại, bluetoothd giữ socket RFCOMM, và `bnep` tự nạp
   → `rmmod bluetooth` thất bại → **bluetooth.ko CŨ chạy cùng rfcomm/bnep/hci_uart MỚI** (lệch cấu trúc vì khác `BT_LE`, nguy cơ lỗi bộ nhớ).
3. Đúng: `systemctl mask --runtime bluetooth` → `stop` → `modprobe -r rfcomm bnep hidp hci_uart; modprobe -r btqca btbcm; modprobe -r bluetooth`
   → `modprobe hci_uart` → `unmask --runtime` → `systemctl restart pixel-bt-addr` → `start bluetooth` → `systemctl --user start obex pixel-obex-agent`.
4. Kiểm đồng bộ: `cat /sys/module/<m>/srcversion` phải bằng `modinfo -F srcversion <m>` cho bluetooth, rfcomm, bnep, hci_uart.
- Trạng thái 2026-11-18: module Bluetooth = build #11, Image ở boot_b vẫn #10 (lõi giống nhau). Lần flash kernel sau dùng build ≥ #11.

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

### "Connection failed — Activation of network connection failed" khi bấm Bluetooth (2026-11-19)
- Không phải lỗi Bluetooth: Quick Settings GNOME 46 có **hai** nút — "Bluetooth" (bật/tắt radio) và **"Bluetooth Tethers"/"Tether"**
  (`NMBluetoothToggle` trong `ui/status/network.js`, hiện khi NetworkManager thấy thiết bị đã ghép đôi có NAP, vd. Legion Tab Y700).
  Bấm nút Tether = gnome-shell gọi NM kích hoạt `Legion Tab Y700 Network` (Bluetooth PAN, dùng Internet của máy kia).
- Log: NM `audit: op="connection-activate" name="Legion Tab Y700 Network" pid=<gnome-shell>`; bluetoothd `connect to …: Host is down (112)`
  (máy kia tắt/ngoài tầm) hoặc `bnep0 connected` rồi `bnep0 disconnected` ngay (máy kia **chưa bật "Chia sẻ Internet qua Bluetooth"**).
- Bluetooth vẫn bình thường (`bluetoothctl show` → Powered: yes). Muốn dùng Internet qua máy kia: bật Bluetooth tethering trên máy đó rồi mới bấm Tether.
- Nhận file qua Bluetooth KHÔNG cần nút này (chỉ cần ghép đôi + OBEX agent, mục trên).
- **Đã ẩn nút Tether** (2026-11-19): `/etc/NetworkManager/conf.d/98-pixel-no-bt-tether.conf` (`[device-…] match-device=type:bt managed=0`).
  `nmcli general reload conf` KHÔNG áp dụng cho thiết bị BT đã có → chỉ có hiệu lực khi NM tạo lại thiết bị (restart bluetooth.service hoặc reboot).
  Kiểm chứng: sau restart bluetooth, `nmcli dev` → `0C:7D:… unmanaged`. Muốn dùng lại tethering: xoá file + restart bluetooth.

### Nhận file OBEX — kiểm chứng (2026-11-19)
- ✅ Legion Tab Y700 → Pixel: `logo_512.png` 19729 byte vào `~/Downloads/Bluetooth` (agent log: "nhận … từ Legion Tab Y700" → "đã nhận xong").
- ⚠️ Chưa rõ nguyên nhân các lần "not sent" trước đó trong cùng lần boot: không có log nào ở agent/obexd/bluetoothd (không có yêu cầu nào tới).
  Thành công ngay sau khi `bluetooth.service` được khởi động lại (01:20). Giả thuyết CHƯA kiểm chứng: (1) race lúc boot — obexd (user, 9.5 s)
  chạy trước bluetoothd (16.4 s); (2) phía Tab (lúc đó NAP còn báo `Host is down`). Lần sau nếu lại "not sent" ngay sau reboot:
  `sudo btmon` trong lúc gửi; `bluetoothctl show | grep OBEX`; thử `systemctl --user restart obex pixel-obex-agent` (không đụng bluetoothd) để phân biệt.

