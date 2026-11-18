# Lưu trữ UFS và USB

## UFS (Micron 64 GB)
| Mục | Giá trị |
|---|---|
| Node | `ufshc@1d84000` (`androidboot.boot_devices=soc/1d84000.ufshc`), PHY `phy@1d87000` |
| Driver | `drivers/ufs/host/ufs-qcom.c` + `phy-qcom-qmp-ufs.c` (đều **=y**: rootfs nằm trên UFS) |
| Reset / nguồn | GPIO 150 (active-low), `vcc` = L20 2.96 V, PHY: L1 0.88 V + L26 1.2 V |

### Bảng phân vùng (đo trên máy, `lsblk`) — ⚠️ = KHÔNG BAO GIỜ ghi
| LUN | Phân vùng |
|---|---|
| `sda` | ssd, misc, keystore, frp, system_a/b (2.8 G), product_a/b, vendor_a/b, **boot_a (sda11) / boot_b (sda12)** 64 M, modem_a/b ⚠️, apdp, msadp, klog, metadata, **userdata (sda21) 51.6 G** ← Ubuntu |
| `sdb` / `sdc` | ⚠️ xbl_a, xbl_config_a / ⚠️ xbl_b, xbl_config_b |
| `sdd` | ⚠️ cdt, ddr, modemcal, uefivar, sec |
| `sde` | ⚠️ aop, tz, hyp, abl, keymaster, cmnlib(64), devcfg, qupfw, storsec (×a/b); **vbmeta_a (sde10)/vbmeta_b (sde22)**, **dtbo_a (sde11)/dtbo_b (sde23)** |
| `sdf` | ⚠️ **persist**, **modemst1/modemst2/fsg/fsc** (EFS modem — rmtfs chỉ đọc), devinfo, dip, spunvm, limits, logfs, splash… |

Được phép ghi (CLAUDE.md luật 2): **boot_a/b, dtbo_a/b, vbmeta_a/b, userdata**. Hiện chỉ dùng **boot_b + userdata**.

## USB-C — DWC3 (chế độ thiết bị)
| Mục | Giá trị |
|---|---|
| Node | `&usb_1` + `&usb_1_dwc3 { dr_mode = "peripheral"; }` (UDC đo được: `a600000.usb`) |
| Driver | `dwc3-qcom` + `dwc3` (=y), PHY HS `phy-qcom-qusb2.c` (=y), PHY SS/DP `phy-qcom-qmp-combo.c` (**=y, cần `TYPEC=y`**) |
| QUSB2 tinh chỉnh | `imp-res-offset 8`, `hstx-trim 21.6 mA`, `preemphasis 5 %`, width half-bit |
| Hệ quả | Chỉ làm **thiết bị** (không cắm được chuột/bàn phím USB). Host/OTG cần dr_mode khác + vai trò Type-C (chưa làm) |

### Lỗi: dwc3 kẹt sau khi rút/cắm cáp (2026-11-18)
- Triệu chứng: PD vẫn thương lượng (máy vẫn sạc, `usb_type` CDP), nhưng `/sys/class/udc/a600000.usb/state` = `not attached`, Mac không thấy thiết bị;
  `dmesg`: `dwc3 a600000.usb: failed to enable ep0out`. `soft_connect` disconnect/connect và gắn lại UDC configfs **không** ăn.
- Sửa: unbind/bind driver của `a6f8800.usb` (**`dwc3-qcom-legacy`**) → UDC `configured` (high-speed). Sau đó Mac chỉ có `169.254.x.x` vì
  dnsmasq của NetworkManager báo `failed to create listening socket for 172.16.42.1: Address already in use` → `nmcli con down usb0; nmcli con up usb0`.
- Gói lại: **`/usr/local/sbin/pixel-usb-reset`** (overlay). Chạy qua Tailscale/Wi-Fi. Trong lúc USB IPv4 hỏng, IPv6 link-local `fe80::ff:fe3a:2%enX` vẫn SSH được.
- Nguyên nhân gốc chưa rõ: driver dwc3-qcom-legacy không có role switch/extcon; từ khi có driver Type-C/PD (patch 0012) TCPM gọi
  "Requesting mux state…, usb-role 2" nhưng không có role switch nào nhận. Hướng sửa sau: nối `connector` ↔ `usb-role-switch` của dwc3 trong DT.

### Gadget (configfs, `usb-gadget.sh`)
| Mục | Giá trị |
|---|---|
| VID:PID | 0x1d6b:0x0104 (Linux Foundation, Multifunction Composite) |
| Chức năng | **NCM** (mạng, `usb0`) + **ACM** (serial `ttyGS0`, tự đăng nhập user ubuntu) |
| MAC | host `02:00:00:3a:00:01` (Mac), device `02:00:00:3a:00:02` (máy) → IPv6 link-local máy `fe80::ff:fe3a:2` |
| IP | máy `172.16.42.1/24`; Mac nhận `172.16.42.x` từ dnsmasq của NM (**không gateway/DNS**) |
| Lưu ý | initramfs phải **gỡ hẳn** gadget trước switch_root (nếu không: `-EBUSY` khi ghi `*_addr`). NM bỏ qua gadget mặc định (`85-nm-unmanaged.rules`) → rule `86-pixel-usb-gadget-nm.rules` |
| Sạc qua cổng này | `usb_type=SDP`, 500 mA (xem [power-battery](power-battery.md)) |
