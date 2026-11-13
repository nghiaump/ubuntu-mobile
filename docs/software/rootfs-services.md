# Rootfs, dịch vụ, giao diện

## Rootfs
| Mục | Giá trị |
|---|---|
| Hệ | Ubuntu **24.04 noble** arm64, debootstrap từ `ports.ubuntu.com/ubuntu-ports` (`scripts/50-rootfs.sh`) |
| Phân vùng | `userdata` (sda21), ext4 nhãn **`pixelroot`**, image 4 GiB → `pixel-firstboot` `resize2fs` lên ~51 GB |
| Người dùng | `ubuntu` (sudo NOPASSWD); SSH **chỉ key** (`PasswordAuthentication no`, `PermitRootLogin no`); mật khẩu Linux do người dùng đặt (dùng cho GNOME/xrdp, KHÔNG ghi ở đây) |
| Gói nền | systemd, openssh-server, network-manager, dnsmasq-base, wpasupplicant, iw, rfkill, wireless-regdb, bluez, **iptables, nftables**, qrtr-tools, rmtfs, tqftpserv (thay bằng v1.3), protection-domain-mapper (mask) |
| Cài thêm sau | `docker.io` 29.1.3, `ubuntu-desktop-minimal` (GNOME 46), `xrdp`+`xorgxrdp`, `tailscale` |
| Giờ | NTP (timesyncd) OK; RTC pm8xxx đứng 1970 (không ghi được) |

## File cấu hình (overlay `rootfs/overlay/` → áp lên máy)
| File | Mục đích |
|---|---|
| `etc/systemd/system/rmtfs.service`, `tqftpserv.service` | thay unit gói (bỏ `Requires=qrtr-ns`), `Before=NetworkManager wpa_supplicant` (chống treo shutdown), tqftpserv v1.3 |
| `etc/modules-load.d/pixel3.conf` | `qrtr`, `qcom_pd_mapper` nạp trước coldplug |
| `etc/systemd/system/usb-gadget.service` + `usr/local/sbin/usb-gadget.sh` | NCM+ACM, bật `usb0` (IPv6 link-local dự phòng) |
| `etc/NetworkManager/conf.d/10-globally-managed-devices.conf` (trống) | che file cùng tên của Ubuntu (bỏ qua ethernet khi không có netplan) |
| `etc/NetworkManager/conf.d/99-pixel-wifi.conf` | MAC Wi-Fi ổn định (tên 99- để nạp sau `no-mac-addr-change.conf`) |
| `etc/NetworkManager/dnsmasq-shared.d/10-usb0-no-gateway.conf` | DHCP usb0/AP **không cấp gateway/DNS** (cắm máy không làm Mac mất mạng) |
| `etc/udev/rules.d/86-pixel-usb-gadget-nm.rules` | NM quản lý gadget (`NM_UNMANAGED=0`) |
| `etc/udev/rules.d/90-pixel-backlight.rules` | độ sáng mặc định 40/1023 |
| `etc/systemd/system/pixel-sshkeys.service` | sinh SSH host key trước `sockets.target` |
| `etc/systemd/system/pixel-firstboot.service` | `resize2fs` lần đầu |
| `etc/systemd/system/serial-getty@ttyGS0.service.d/autologin.conf` | serial USB tự đăng nhập (cửa sau debug) |
| `etc/systemd/journald.conf.d/10-pixel.conf` | journal persistent; `ForwardToConsole=no` (bật lại `yes` khi cần debug boot không mạng) |
| `etc/apt/preferences.d/90-no-firefox-snap.pref` | chặn gói firefox (vỏ snap) — **bỏ** khi muốn cài Firefox (kernel đã có SQUASHFS_XZ) |
| `etc/systemd/system/pixel-powerkey.service` + `usr/local/sbin/pixel-powerkey.py` | nút nguồn = màn hình mềm |
| `etc/systemd/logind.conf.d/10-pixel-powerkey.conf` | `HandlePowerKey=ignore` |
| `etc/systemd/system/pixel-wifi-fallback.service` + `usr/local/sbin/pixel-wifi-fallback.sh` | AP dự phòng |
| `etc/systemd/system/pixel-sound.service` + `usr/local/sbin/pixel-sound.sh` | nạp card `snd-soc-sdm845` (thử lặp) + đặt mixer loa (xem `hardware/audio-camera-haptics.md`) |
| `etc/wireplumber/main.lua.d/51-pixel3-audio.lua` | loa: `api.alsa.use-acp=false`, S16LE, tên "Loa Pixel 3 XL" |
| `etc/systemd/system/qbootctl.service.d/10-pixel.conf` + symlink `multi-user.target.wants/qbootctl.service` | đánh dấu slot A/B thành công sau khi SSH/NM lên + 20 s (RUNBOOK §6.5). Gói `qbootctl` |
Kết nối NetworkManager do `nmcli` tạo được Ubuntu lưu dạng **netplan** `/etc/netplan/90-NM-*.yaml` (600 root), không phải `system-connections/`.

## Dịch vụ Qualcomm
`qrtr-ns`, `pd-mapper` userspace bị **mask** (đã có trong kernel). `rmtfs -r -P -s` (chỉ đọc EFS, tự start modem), `tqftpserv` v1.3 (`/usr/local/bin`).

## GNOME (Wayland trên panel) — RÀNG BUỘC CHỐNG RESET
Tắt màn hình (DPMS) = **reset máy**. Bắt buộc:
- GDM greeter: `/etc/gdm3/greeter.dconf-defaults` (profile gdm đọc `/var/lib/gdm3/greeter-dconf-defaults`, KHÔNG đọc `/etc/dconf/db/gdm.d`).
- Người dùng: `/etc/dconf/db/local.d/90-pixel-no-blank` + **`locks/90-pixel-no-blank`** (user không ghi đè được — sự cố idle-delay=60):
  `idle-delay=0`, `sleep-inactive-ac/battery-type='nothing'`, `idle-dim=false`, `power-button-action='nothing'`, `screensaver lock-enabled=false`,
  `ubuntu-lock-on-suspend=false`, **`lockdown disable-lock-screen=true`** — phiên KHOÁ thì gsd-power tắt màn hình sau ~30 s bất kể idle-delay → reset.
- Kiểm tra: `gsettings writable org.gnome.desktop.session idle-delay` → `false`.
- `scripts/91-xrdp.sh` áp tất cả các mục trên.

## Nút nguồn — "tắt màn hình mềm" (`pixel-powerkey.py`)
Bấm: lưu độ sáng → backlight 0 → cảm ứng `inhibited=1`. Bấm lại: mở cảm ứng → trả độ sáng. **Không khoá phiên** (xem trên).
Đọc trực tiếp `/dev/input/event*` tên `pm8941_pwrkey`, chống dội 0.4 s. Không tắt panel (xem trên).
