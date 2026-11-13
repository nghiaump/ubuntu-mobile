# Truy cập từ xa

| Đường | Địa chỉ | Cần gì | Ghi chú |
|---|---|---|---|
| USB NCM | `ssh ubuntu@172.16.42.1` | cáp USB | Mac nhận 172.16.42.x (không gateway). Luôn dùng được, kể cả không có Wi-Fi |
| USB IPv6 dự phòng | `ssh ubuntu@fe80::ff:fe3a:2%enX` | cáp | khi NM hỏng (usb-gadget.sh tự `ip link set usb0 up`) |
| Serial USB | `/dev/cu.usbmodem*` 115200 | cáp | tự đăng nhập `ubuntu` |
| Wi-Fi LAN | `ssh ubuntu@<IP wlan0>` (nhà: 192.168.1.17) | cùng mạng | |
| **Tailscale** | `ssh ubuntu@100.71.99.38` / `pixel3xl` (MagicDNS khi bật "Use Tailscale DNS" trên Mac) | Tailscale cùng tài khoản | máy phải có Internet (Wi-Fi/hotspot; **chưa có 4G**). KeyExpiry 2027-05-12 → nên "Disable key expiry" |
| Desktop | Windows App → `100.71.99.38` / `172.16.42.1` / IP LAN | user ubuntu + mật khẩu | **xrdp** (phiên Xorg riêng, KHÔNG phải màn hình điện thoại) |

## Vì sao xrdp mà không phải GNOME Remote Login
GNOME Remote Login (system RDP) dùng *server redirection* + thông tin đăng nhập một lần. **Windows App (macOS) không dùng
credential đó** (hiện hộp username lạ như `<>!s6…`) → NTLM "MIC verification failed" ở daemon handover. xrdp không redirect.
Cấu hình: `scripts/91-xrdp.sh` (tắt grd system RDP, `~/.xsessionrc`, `~/.xsession` = `gnome-session --session=ubuntu`, polkit colord).
Hạn chế: cùng user `ubuntu` vừa đăng nhập trên máy vừa qua xrdp → 2 phiên GNOME song song, có thể lỗi.
Hướng "tablet" sau này: chia sẻ chính phiên trên máy (GNOME Desktop Sharing, không redirection).

## Wi-Fi
| Kết nối (NM) | Ưu tiên | Ghi chú |
|---|---|---|
| `VN2007` (nhà) | 10 | |
| `iPhone-NghiaND` (hotspot) | −10, `metered=yes`, route-metric 700 | bật Personal Hotspot là máy tự vào |
| `pixel3xl-setup` (AP) | autoconnect=no | **AP dự phòng**: không có mạng quen 2 phút → phát; IP máy `10.42.0.1`; cứ 10 phút tắt ~60 s thử lại mạng quen. Mật khẩu AP chỉ đưa cho người dùng (không ghi ở đây) |
- Thêm Wi-Fi mới: cắm cáp → `scripts/wifi-add.sh` (hoặc qua AP: `scripts/wifi-add.sh "<SSID>" 10.42.0.1`).
- Lưu trữ kết nối: netplan `/etc/netplan/90-NM-*.yaml` (600 root).
