# RUNBOOK — Ubuntu 24.04 native trên Google Pixel 3 XL (crosshatch)

Tài liệu vận hành: cách hệ thống được dựng, thao tác thường ngày, cách khôi phục, và **các lỗi đã gặp + cách tránh**.
Chi tiết từng linh kiện/phần mềm: [`docs/README.md`](README.md) (hardware/, software/, ARCHIVE.md, generated/).
Nhật ký chi tiết từng bước: `NOTES.md`. Luật an toàn: `CLAUDE.md` (bắt buộc đọc trước khi flash).
Cập nhật lần cuối: 2026-11-13 (giữa Pha 5).

---

## 1. Tổng quan kiến trúc

```
[ABL stock b1c1-0.4-7617406, đã unlock]
   └─ boot_b  : boot.img header v2 (kernel LZ4 + initramfs busybox + DTB crosshatch) + AVB footer (test key)
        └─ initramfs/init : dựng USB gadget (debug), tìm LABEL=pixelroot, switch_root /sbin/init
             └─ userdata (sda21, ~51 GB ext4 "pixelroot") : Ubuntu 24.04 noble arm64, systemd
```

| Thành phần | Giá trị |
|---|---|
| Kernel | mainline **v7.4-rc2** + series panel 3 XL **v3** (b4, 10 patch) + `kernel/patches/*.patch` (TEXT_OFFSET, touchscreen) |
| Config | arm64 `defconfig` + `kernel/pixel3.config` (merge) |
| DTB | `sdm845-google-crosshatch.dtb`, **board-id bị ghi đè 0x11505** khi đóng boot.img |
| Firmware riêng máy | trích từ factory image → `/lib/firmware/qcom/sdm845/Google/blueline/` (DTS dùng chung thư mục *blueline* cho cả 3 XL) |
| Firmware chung | linux-firmware tag `20261019` (board-2.bin có `Google_crosshatch`, a630, BT) |
| Slot | **b** (Android stock còn nguyên ở các phân vùng khác; slot b boot Ubuntu) |
| Workspace Mac | `/Volumes/pixelwork` = sparsebundle Case-sensitive APFS trên SSD exFAT `/Volumes/LIB/pixel-ubuntu/` |
| Build | Docker Desktop, image `pixel-build:noble` (arm64 native trên M4) |

---

## 2. Tra cứu nhanh

### Truy cập máy
| Cách | Lệnh | Ghi chú |
|---|---|---|
| SSH qua USB | `ssh -o UserKnownHostsFile=.ssh_known_hosts ubuntu@172.16.42.1` | Mac nhận 172.16.42.x qua DHCP (KHÔNG có gateway) |
| SSH qua Wi-Fi | `ssh ... ubuntu@192.168.1.17` | Wi-Fi nhà; MAC Wi-Fi do NM sinh ổn định |
| SSH dự phòng | `ssh ... ubuntu@fe80::ff:fe3a:2%en6` | IPv6 link-local, có kể cả khi NM hỏng |
| Serial USB | `/dev/cu.usbmodem*` | tự đăng nhập user ubuntu (cửa sau debug) |
| Desktop | Windows App → PC `192.168.1.17` | **xrdp**, session Xorg, user ubuntu |
| Khóa SSH | chỉ key từ `~/.ssh/*.pub` của Mac | đăng nhập SSH bằng mật khẩu bị tắt |

### Vào Wi-Fi mới (khi đi nơi khác)
- **Qua cáp USB (luôn được)**: cắm vào Mac → `scripts/wifi-add.sh` (hỏi SSID + mật khẩu ẩn, NM lưu lại).
- Hoặc Windows App → `172.16.42.1` (qua cáp) → Cài đặt Wi-Fi của GNOME (cả Wi-Fi có trang đăng nhập, khi đã có Firefox).
- Lưu sẵn hotspot iPhone để máy tự vào mạng ở bất cứ đâu (Tailscale tự lên theo).

### Giao diện cảm ứng (chi tiết: `software/touch-ui.md`)
- Bàn phím ảo / cờ Chrome / giữ-lâu: `scripts/97-chrome-osk.sh [host]`.
- Extension GNOME tự viết (tai thỏ + OSK cho Chrome): `scripts/98-gnome-shell-ext.sh [host] [px]` → **đăng xuất/đăng nhập lại** mới nạp code mới.
- Giữ lâu = chuột phải cho MỌI app: chưa có (cần kernel `CONFIG_INPUT_UINPUT`).

### Khởi động lại / vào fastboot
| Mục đích | Lệnh |
|---|---|
| Khởi động lại thường | `sudo systemctl reboot` |
| Về fastboot từ Ubuntu | `sudo systemctl reboot --reboot-argument=bootloader` |
| Về fastboot từ initramfs debug | `rebootarg bootloader` |
| Máy treo / không truy cập được | **giữ Nguồn + Giảm âm lượng 10–15 s** (an toàn) |
| Bấm nhanh nút nguồn | tắt/bật màn hình **mềm** (backlight 0 + khoá cảm ứng + khoá GNOME) — không tắt máy |
| Boot thử, không ghi gì | `fastboot boot /Volumes/pixelwork/out/boot/boot-install.img` |

### Script (chạy theo thứ tự khi dựng từ đầu)
| Script | Việc | Thời gian |
|---|---|---|
| `00-workspace.sh [detach]` | mount/tháo sparsebundle | giây |
| `10-factory-image.sh <URL> <SHA256>` | tải + kiểm factory image, tách modem.img (FBPK) | ~7 phút |
| `11-extract-firmware.sh` | trích + gộp `.mdt→.mbn` | ~1 phút |
| `12-upstream-firmware.sh` | linux-firmware ghim tag | giây |
| `20-build-env.sh build\|run\|priv` | image Docker / chạy lệnh trong container | |
| `30-kernel.sh [prepare\|build\|all]` | áp patch + build kernel/module/DTB | **3–35 phút** (xem §5) |
| `40-initramfs.sh` | đóng initramfs | giây |
| `50-rootfs.sh` (`FINALIZE=1` chỉ bước cuối) | debootstrap noble → rootfs.img/.simg | ~10–15 phút |
| `55-tqftpserv.sh` | build tqftpserv **v1.3** | ~1 phút |
| `60-bootimg.sh smoke\|install` | boot.img (board-id 0x11505 + AVB footer) | giây |
| `70-smoke-payload.sh [serve]` | payload thử nghiệm trong RAM | |
| `75-overlay-patch.sh` | đóng `rootfs/overlay` thành overlay.tar để vá tại chỗ | giây |
| `80-deploy-kernel.sh [host]` | đẩy module qua SSH → fastboot → `fastboot boot` | ~2 phút |
| `90-gnome-rdp.sh` | (cũ) GNOME Remote Login — **không dùng với Windows App** | |
| `91-xrdp.sh [host]` | xrdp + phiên GNOME + chống tắt màn hình (dconf + **locks**) | ~2 phút |
| `92-tailscale.sh [host]` | Tailscale (kho apt chính thức), in URL đăng nhập | ~1 phút |
| `93-wifi-fallback.sh [host]` | AP dự phòng `pixel3xl-setup` (mật khẩu ngẫu nhiên in 1 lần) | giây |
| `95-archive.sh` (`ONLY=device`) | lưu trữ phụ thuộc vào `archive/<ngày>/` (xem `docs/ARCHIVE.md`) | ~7 phút |
| `96-hw-facts.sh` | sinh `docs/generated/` (driver map, DT gốc/đang chạy giải mã) | lâu (virtiofs) |
| `wifi-add.sh ["SSID"] [host]` | thêm Wi-Fi mới qua cáp USB (mật khẩu gõ ẩn) | giây |

---

## 3. Quy trình chuẩn (SOP)

### 3.1 Cập nhật kernel
1. Sửa `kernel/pixel3.config` hoặc thêm `kernel/patches/NNNN-*.patch`.
2. `scripts/30-kernel.sh build` — kiểm dòng `!!` / "muốn … được …" (option bị Kconfig đổi) và `text_offset=0x80000`.
3. `scripts/60-bootimg.sh install`.
4. `scripts/80-deploy-kernel.sh` → máy chạy kernel mới **trong RAM**. Kiểm `uname -v`, `systemctl --failed`.
5. Chỉ khi ổn: hỏi người dùng **"đồng ý"** → vào fastboot → `fastboot flash boot_b out/boot/boot-install.img` → `fastboot reboot`.

### 3.2 Sửa cấu hình rootfs
- **Luôn** sửa file trong `rootfs/overlay/` (để lần dựng sau có), rồi áp lên máy đang chạy qua `scp` + `sudo install`.
- Thêm gói: thêm vào `PKGS` trong `50-rootfs.sh` **và** `apt install` trên máy.
- Cấu hình do gói cài sau (GNOME, xrdp…) không nằm trong overlay → đưa vào script tương ứng (`91-xrdp.sh`).

### 3.3 Máy không vào được mạng (cứu hộ không flash)
1. Nguồn + Giảm âm lượng → fastboot.
2. `fastboot boot out/boot/boot-smoke.img` (initramfs debug, không switch_root) → `telnet` qua `scripts/lib/tsh.py`.
3. Mount `LABEL=pixelroot`, đọc log: `chroot /mnt/root /bin/sh -c "journalctl --list-boots; journalctl -b 0 ..."`.
4. Vá bằng `overlay.tar` / `.deb` (xem `scripts/phone/fix-rootfs.sh`).
5. `rebootarg bootloader` → `fastboot boot boot-install.img`.

### 3.4 Quay về Android
`fastboot flash boot_b /Volumes/pixelwork/factory/crosshatch-sp1a.210812.016.c2/img/boot.img` (cần "đồng ý").
Android sẽ format lại userdata (mất Ubuntu). Khôi phục toàn bộ: `flash-all.sh` của factory image (ghi cả bootloader/radio —
chỉ khi thật cần, hỏi người dùng). **Không bao giờ `fastboot flashing lock`** khi còn image không phải stock.

---

## 4. Lỗi đã gặp → nguyên nhân → cách xử lý (đọc trước khi làm lại)

### Boot / bootloader
| Triệu chứng | Nguyên nhân | Xử lý |
|---|---|---|
| ABL không boot kernel mainline | ABL mới cần `text_offset` ≠ 0 (cover letter v7 "Booting") | patch `0001`: header Image `text_offset=0x80000`; kernel tự chịu lệch (`kaslr_offset = pa_base % 2M`). Log "Kernel image misaligned" là bình thường |
| `fastboot boot` → *Error verifying the received boot.img: Invalid Parameter* | DTB board-id `0x21505` (= Pixel 3 B1). 3 XL cần **`0x11505`** (C1 DVT1.1) | `60-bootimg.sh` ghi đè mặc định; boot.img giữ AVB footer 64 MiB như stock |
| Không thấy log kernel trên màn hình | ABL thay `console=` bằng `console=null`; arm64 không có CMDLINE_EXTEND | initramfs đọc `/dev/kmsg` ra tty1; journald ForwardToConsole khi cần debug |
| ABL chèn `root=…` Android | cmdline do ABL ghép | dùng tham số riêng `pixel.root=` |
| `fastboot boot` báo `usb_read failed e00002eb` | máy ngắt USB trước khi trả lời | vô hại, máy vẫn boot |
| `verifiedbootstate=orange` | đã unlock, vbmeta stock không khớp boot | bình thường, không cần đụng vbmeta/dtbo |

### Kernel / phần cứng
| Triệu chứng | Nguyên nhân | Xử lý |
|---|---|---|
| SMMU GPU `-110`, cpufreq thiếu icc | driver built-in chờ supplier là module > 10 s | `SDM_GPUCC_845`, `INTERCONNECT_QCOM_OSM_L3`, `QCOM_LLCC` = y |
| USB gadget không lên ở initramfs | PHY QMP COMBO bị `TYPEC=m` kéo xuống m | `TYPEC=y`, `PHY_QCOM_QMP=y` |
| Panel không lên | thiếu `REGULATOR_QCOM_LABIBB` (+ refgen) | bật =m |
| Modem `failed to acquire pdc reset` / Wi-Fi chờ supplier | module không được nạp (initramfs không udev) | trên rootfs udev lo; `pwrseq-qcom-wcn` cho WCN3990 |
| Modem xin `wlanmdsp.mbn` bị *invalid path, rejecting* | tqftpserv 1.0 (noble) không hiểu `/readonly/vendor/firmware{,_mnt/image}/` | **tqftpserv v1.3** (`55-tqftpserv.sh`) |
| remoteproc `failed to initialize qmi handle` | qrtr chưa nạp lúc probe | `/etc/modules-load.d/pixel3.conf`: qrtr, qcom_pd_mapper |
| rmtfs/tqftpserv chết theo qrtr-ns | unit gói `Requires=qrtr-ns` (ns đã nằm trong kernel) | unit riêng trong overlay, mask qrtr-ns + pd-mapper |
| rmtfs có ghi phân vùng modem không? | — | **`-r` = chỉ đọc** (storage.c), ghi giữ trong RAM |
| Docker `-p`: *Extension DNAT revision 0 not supported* | kernel 7.x đặt bảng iptables legacy sau `NETFILTER_XTABLES_LEGACY` | bật legacy + `IP_NF_*`, `NETFILTER_XT_NAT`… theo `check-config.sh` |
| snap: *Filesystem uses xz compression. This is not supported* | thiếu `SQUASHFS_XZ` | đã thêm (cùng AppArmor); firefox bị pin chặn tới khi có kernel mới |
| Sạc: `qcom-smbx-charger … Couldn't get usbin_v IIO channel` | thiếu `QCOM_SPMI_RRADC` | đã thêm; % pin cần fuel gauge (sdm845-next) |
| Cảm ứng | 3 XL = **Samsung S6SY761** @0x48 (KHÁC Pixel 3 STM FTS5) | patch `0002` + `TOUCHSCREEN_S6SY761` (đang thử) |

### Mạng / dịch vụ
| Triệu chứng | Nguyên nhân | Xử lý |
|---|---|---|
| **Cắm điện thoại → Mac mất Internet** | NM `method=shared` cấp gateway + DNS qua DHCP | `dnsmasq-shared.d/10-usb0-no-gateway.conf` + `never-default`. Sau mọi thay đổi mạng: `route -n get default` trên Mac phải là en0 |
| usb0 *unmanaged* | `85-nm-unmanaged.rules`: gadget bị bỏ qua; `10-globally-managed-devices.conf`; thiếu iptables | udev rule `86-pixel-usb-gadget-nm.rules`; file trống che conf; cài iptables/nftables |
| usb-gadget.service hỏng sau switch_root | initramfs chỉ tháo UDC → ghi `*_addr` bị `-EBUSY` | initramfs gỡ hẳn gadget |
| SSH *Connection refused* lần đầu | firstboot `Before=ssh.socket` → vòng thứ tự | `pixel-sshkeys.service` chạy trước `sockets.target` |
| MAC Wi-Fi đổi mỗi lần boot | ath10k không đọc được MAC; `no-mac-addr-change.conf` đè cấu hình | `99-pixel-wifi.conf` (nạp sau cùng), cloned-mac=stable |
| **`systemctl reboot` treo** sau "wlan0: CTRL-EVENT-TERMINATING" | rmtfs (modem chứa firmware Wi-Fi) dừng trước Wi-Fi → WMI timeout | rmtfs/tqftpserv `Before=NetworkManager wpa_supplicant` |

### GNOME / remote desktop
| Triệu chứng | Nguyên nhân | Xử lý |
|---|---|---|
| **Máy reset mỗi ~300 s sau khi có GDM** | GNOME tắt màn hình → panel tắt → reset (DTS: không bật lại được panel) | idle-delay=0, không ngủ, không dim — GDM: `/etc/gdm3/greeter.dconf-defaults`; user: dconf `local.d` |
| Cấu hình GDM qua `/etc/dconf/db/gdm.d` không ăn | profile gdm của Ubuntu = `/var/lib/gdm3/greeter-dconf-defaults` | sửa `/etc/gdm3/greeter.dconf-defaults`, kiểm bằng `sudo -u gdm env DCONF_PROFILE=gdm gsettings get …` |
| Màn hình sáng liên tục tốn pin | không được tắt panel | hạ backlight (`/sys/class/backlight/ae94000.dsi.0`, udev rule = 40/1023) |
| **Reset lại sau khi đăng nhập GNOME trên máy** | cấu hình của user (idle-delay=60) ghi đè mặc định hệ thống | dconf **locks** `/etc/dconf/db/local.d/locks/90-pixel-no-blank`; kiểm `gsettings writable … idle-delay` = false |
| **Reset `bootreason=watchdog` khi đang ở màn khoá GNOME** | phiên bị khoá → `gsd-power` tự tắt màn hình sau ~30 s không thao tác (bỏ qua idle-delay) → panel tắt → máy treo cứng → watchdog | không bao giờ khoá phiên: pixel-powerkey bỏ `lock-session`; dconf `lockdown/disable-lock-screen=true` (khoá) |
| Biết lý do máy khởi động lại | ABL ghi vào cmdline | `tr ' ' '\\n' < /proc/cmdline \| grep bootreason` (`watchdog`, `reboot`, `reboot,bootloader`, `reboot,longkey…`) |
| Bấm nút nguồn (kiểu điện thoại) | GNOME/logind sẽ ngủ/tắt máy → tắt panel → reset | `power-button-action='nothing'` (khoá), logind `HandlePowerKey=ignore`, `pixel-powerkey.service` làm màn hình mềm |
| GNOME Remote Login + Windows App: hỏi username lạ, "sai mật khẩu" | Windows App (Mac) không dùng credential một lần của server redirection (NTLM MIC lỗi ở handover) | dùng **xrdp** (`91-xrdp.sh`) |
| grd system không mở 3389 | khởi động trước GDM | drop-in `After=gdm.service` (nay đã tắt grd) |
| Màn điện thoại chỉ có màn đăng nhập khi dùng xrdp | xrdp = phiên ảo riêng | đúng thiết kế; "tablet" cần cảm ứng + autologin + desktop sharing |

### Bẫy công cụ (đã tốn thời gian)
- **Build kernel chậm**: bind mount virtiofs; đổi option chạm `autoconf.h` (vd netfilter) → build lại ~22–35 phút. Gộp nhiều thay đổi config vào một lần build.
- git trên virtiofs báo file bị sửa sau `git am` → `core.checkStat minimal`, `core.trustctime false`.
- bash 3.2 (macOS) + `set -u` + mảng rỗng → `${arr[@]+"${arr[@]}"}`; `docker run` cần `-i` để nhận script qua stdin.
- Gói `mkbootimg` noble thiếu module `gki` → dùng mkbootimg/avbtool AOSP (ghim tag trong Dockerfile).
- `strings | grep -q` + `pipefail` → SIGPIPE báo lỗi giả. `grep '…$MNT…'` → `$` là neo regex.
- Heredoc: một dòng `EOF` trong code lồng bên trong cắt heredoc ngoài → dùng ký hiệu khác (`PYEND`).
- **Không** vừa pipe vừa heredoc vào stdin của `ssh` (heredoc thắng). Script qua tham số, dữ liệu qua stdin.
- busybox-static (standalone shell) ưu tiên applet (dpkg, tar…) kể cả trong chroot → `chroot $R /bin/sh -c '…'`, glob để bên trong.
- busybox `dmesg` không có `-w` → `cat /dev/kmsg`. Tiến trình nền qua telnet phải `setsid` + chờ 1 s (SIGHUP).
- `tar` của macOS chép `._*` (AppleDouble) → `COPYFILE_DISABLE=1 tar --no-xattrs --no-mac-metadata`.
- macOS không còn `telnet`; Python 3.13 bỏ `telnetlib` → `scripts/lib/tsh.py` / `tstream.py`.
- Chờ trạng thái unit: `systemd-run` mặc định Type=simple → `active`, không phải `activating`.
- GNU `tar`: `--exclude` phải đứng **trước** đường dẫn (đặt sau → "has no effect", exit 2).
- `tr … </dev/urandom | head -c N` + `pipefail` → SIGPIPE, exit 141 → thêm `|| true`.
- Ubuntu 24.04: `nmcli` lưu kết nối thành **netplan** `/etc/netplan/90-NM-*.yaml` (không phải `system-connections/`);
  file `.nmconnection` trong overlay bị chuyển sang netplan khi sửa bằng `nmcli`.
- lore.kernel.org chặn fetch tự động → dùng `b4`. Trang factory image cần người dùng tự bấm Acknowledge (đưa URL + SHA-256).

---

## 5. Trạng thái & việc còn mở (cập nhật 2026-11-13 tối)
- ✅ Pha 0–4 xong: systemd, SSH USB/Wi-Fi, Wi-Fi, panel MSM, Docker, boot từ boot_b.
- ✅ Pha 5: hết treo reboot, hết reset ~300 s, GNOME + xrdp qua Windows App.
- ✅ Kernel #6 (boot_b): **cảm ứng S6SY761**, **sạc** (`Charging`), SQUASHFS_XZ + AppArmor. Tailscale, AP dự phòng, hotspot iPhone, nút nguồn mềm.
- ✅ Archive đầy đủ trong `archive/20261113/` (2.7 GB, có factory image).
- ⏳ "Tablet": scale giao diện, bàn phím ảo, chia sẻ chính màn hình qua RDP (thay xrdp).
- ✅ Kernel #8 (boot_b, 2026-11-13 ~23:35): **% pin** (MAX1720x), **loa** (2× CS35L36, PipeWire, phím âm lượng — patch 0004 + 0005). **qbootctl** đánh dấu slot b mỗi lần boot (§6.5).
- ✅ 2026-11-15: **Bluetooth** (`pixel-bt-addr.service` gán địa chỉ), **Defender** sạc (35 °C/60 phút → 80 %).
- ✅ 2026-11-15: giới hạn sạc nâng lên **90/85** (`/etc/default/pixel-charge-limit`); pin còn 3135/3456 mAh (~91 %).
- ✅ 2026-11-14: `health=Dead` sửa (patch 0006, module); **giới hạn sạc 75–80%** (patch 0008 module + `pixel-charge-limit`); lệnh `pin`; Termius qua Tailscale; chặn fwupd/udisks mount phân vùng Android.
- ⏳ Camera trước (IMX355) + micro (patch 0007 đã viết, build #9 có, CHƯA thử; libcamera cần người dùng tự chạy `scripts/56-libcamera.sh`). Ngủ thật (suspend) cần sửa bật lại panel.
- ✅ 2026-11-14: flash **kernel #10 + DTB 0011** (đủ patch 0001–0011) — module trên máy khớp kernel. Sạc nhanh 5 V tới 3 A (theo Rp Type-C + bảng Google); PD 9 V chưa có (mainline thiếu Type-C/PD cho PMI8998).
- ✅ 2026-11-14 chiều: **USB PD 9 V** (patch 0012–0014, flash boot_b `f4edbb1b…`). Sạc từ cục PD: 9 V/2 A.
- 🔴 Micro: WCD9340 + SLIMbus lên, thu được nhưng dữ liệu = 0 (xem NOTES 2026-11-14). 🟡 Camera: IMX355 trước ở 0x10; sửa DT (bỏ node 0x1a / pinctrl MCLK) + libcamera. Firefox: bỏ pin apt rồi `snap install firefox`.
- ❓→✅ "Boot vào Android" ở Pha 3: nhiều khả năng do hết lượt thử slot A/B (§6.5), đã phòng bằng qbootctl.

---

## 6. Sự cố khởi động lại / reset — bài học (đọc kỹ trước khi đụng tới màn hình, nguồn, GNOME)

### 6.1 Cách chẩn đoán một lần khởi động lại (làm theo thứ tự)
1. **Lý do do bootloader ghi** (lần boot hiện tại cho biết vì sao lần trước kết thúc):
   `tr ' ' '\n' < /proc/cmdline | grep bootreason`
   | Giá trị | Nghĩa |
   |---|---|
   | `reboot` / `reboot,bootloader` | khởi động lại có chủ đích (lệnh reboot, `--reboot-argument=bootloader`, `fastboot reboot`) |
   | `watchdog` | **máy treo cứng**, watchdog phần cứng reset — log thường KHÔNG kịp ghi |
   | `reboot,longkey,…` | người dùng giữ nút nguồn (reset cứng) |
   Các lần trước: `journalctl -b -N -k -o cat | grep -o 'androidboot.bootreason=[^ ]*'`.
2. **Lịch sử boot**: `journalctl --list-boots` — nhiều boot sát nhau = đang reset lặp.
3. **Cách lần trước kết thúc**: `journalctl -b -1 -o short-monotonic | tail -30`
   - có `systemd-shutdown … Journal stopped` → tắt bình thường;
   - dừng giữa chừng, không dòng tắt → reset/treo. Ghi lại **uptime lúc dừng** (mốc ~300 s, ~60 s, ~30 s sau khi khoá → nghi GNOME tắt màn hình).
4. Tự hỏi: **lúc đó tôi (Claude) có gửi lệnh reboot/deploy không?** (`80-deploy-kernel.sh`, flash, `systemctl reboot`) — phân biệt với reset ngoài ý muốn trước khi kết luận.
5. Kiểm GNOME: `gsettings get/writable org.gnome.desktop.session idle-delay` trong phiên người dùng (lấy `DBUS_SESSION_BUS_ADDRESS` từ `/proc/<gnome-shell>/environ`).

### 6.2 Dòng thời gian các sự cố (2026-11-13)
| # | Bối cảnh | Triệu chứng | Nguyên nhân | Cách sửa | Trạng thái |
|---|---|---|---|---|---|
| 1 | Pha 3, initramfs, coldplug toàn bộ module sau khi dừng/khởi động modem bằng tay nhiều lần | máy reset, boot vào Android stock | **chưa xác định** (nghi modem ở trạng thái dở `port failed halt` + IPA/module khác) | khởi động theo thứ tự sạch (module → modem) thì ổn; tránh stop/start modem bằng tay liên tục. **Khả năng cao là cơ chế A/B ở #6** (hết lượt thử slot b) | giải thích bởi #6 |
| 2 | `systemctl reboot` | **treo** (không reset) sau `wlan0: CTRL-EVENT-TERMINATING` | rmtfs (dừng modem, nơi chạy firmware Wi-Fi) dừng trước NM/wpa → WMI timeout | rmtfs/tqftpserv `Before=NetworkManager wpa_supplicant` | ✅ |
| 3 | Sau khi cài GNOME, ở màn đăng nhập GDM | reset mỗi **~300 s** | GDM greeter `idle-delay=300` tắt màn hình → panel tắt → treo → watchdog | `/etc/gdm3/greeter.dconf-defaults` idle-delay=0, không ngủ/dim | ✅ |
| 4 | Người dùng đăng nhập GNOME trên máy | reset sau vài phút (`watchdog`) | cấu hình **của user** (`idle-delay=60`) ghi đè mặc định hệ thống | dconf `local.d` + **locks** (user không ghi đè được) | ✅ |
| 5 | Nút nguồn "tắt màn hình mềm" (bản đầu có khoá phiên) → màn khoá, bàn phím ảo không có số | reset `watchdog` khi ngừng thao tác | **phiên bị khoá → `gsd-power` tắt màn hình sau ~30 s, BỎ QUA idle-delay** | bỏ khoá phiên; `lockdown/disable-lock-screen=true` (khoá) | ✅ |
| 6 | Deploy kernel (`80-deploy-kernel.sh`) rồi `fastboot boot`/`fastboot reboot` | `fastboot boot` quay lại fastboot sau ~8 s; `fastboot reboot` → **"Cannot load Android system. Your data may be corrupt…"** (recovery Android slot a) | **Slot b `unbootable`**: Ubuntu không bao giờ báo "boot thành công" (`slot-successful:b:no`) → mỗi lần boot từ boot_b ABL trừ `slot-retry-count`; về 0 ⇒ slot b `unbootable` ⇒ ABL chuyển **slot a = Android stock**, Android không đọc được userdata ext4 ⇒ màn recovery. Đây cũng là lời giải cho sự cố #1 "boot vào Android" | Vol Down+Power vào fastboot → `fastboot getvar all \| grep -E 'slot\|unbootable\|retry'` → **`fastboot --set-active=b`** (chỉ sửa cờ slot, retry về 3) → lâu dài: `qbootctl.service` (`qbootctl -m`) đánh dấu slot thành công mỗi lần boot | ✅ (xem §6.5) |
| — | Deploy kernel / flash boot_b | khởi động lại | **có chủ đích** (Claude) | báo người dùng trước khi làm | — |

### 6.3 Gốc rễ chung
**Tắt panel S6E3HA8 (DPMS off) ⇒ máy treo cứng ⇒ watchdog reset.** DTS mainline đã cảnh báo: *"We can't properly bring the panel back if it gets turned off"*.
Mọi đường dẫn tới "tắt màn hình" đều nguy hiểm: idle-delay (GDM, user), màn khoá (gsd-power 30 s), suspend/ngủ, nút nguồn (GNOME/logind),
`xset dpms force off`, `wlr-randr --off`, đổi chế độ hiển thị, … Sửa tận gốc = sửa trình tự tắt/bật panel trong driver (chưa làm).

### 6.4 Quy tắc phòng tránh
- KHÔNG đổi các khoá dconf trong `/etc/dconf/db/local.d/locks/90-pixel-no-blank` và `/etc/gdm3/greeter.dconf-defaults` (mục pixel3).
- KHÔNG bật khoá màn hình, suspend, "Blank Screen" trong Settings; nút nguồn chỉ dùng `pixel-powerkey` (backlight 0).
- Muốn "tắt màn hình" → `backlight=0` (AMOLED đen gần như không tốn điện), không DPMS.
- **Không để gì tự mount phân vùng Android**: `80-pixel-udisks-ignore.rules` + fwupd bị mask (2026-11-14 fwupd dò ESP đã mount `modem_b` qua udisks). Gói mới kéo theo dịch vụ dò ổ đĩa → kiểm `journalctl | grep udisksd.*Mounted`.
- **Máy làm server 24/7 (từ 2026-11-15)**: máy từng **chết vì cạn pin 2 lần dù được cho là đang cắm sạc** (14/11 20:03, 15/11 06:58; log đã mất do journal đầy).
  Điều tra: `column -s, -t < /var/log/pixel-power.csv | tail` (cap, batt_mA âm = xả, usb_online, icl_eff_mA, chg_state 7=disable/inhibit, typec_mode) và `/var/log/pixel-tcpm.log`.
  SSH lặp lại từ `<ip-tailscale-máy-deploy>` = máy Mac deploy server game (bình thường).
- Pin cạn (5%): `/etc/UPower/UPower.conf` `CriticalPowerAction=PowerOff` (mặc định `HybridSleep` = ngủ = tắt panel = treo). Áp bởi `scripts/91-xrdp.sh`.
- Sau khi cài/đổi gói GNOME hoặc thêm user mới: kiểm `gsettings writable … idle-delay` = false và `disable-lock-screen` = true.
- Thử thay đổi rủi ro: theo dõi uptime ≥ 11 phút (vượt các mốc 30 s/60 s/300 s) trước khi coi là ổn.
- Mọi lần khởi động lại do Claude gây ra phải báo trước cho người dùng; nếu người dùng hỏi "sao tự khởi động lại", làm §6.1.

### 6.5 Cơ chế A/B của ABL — vì sao máy "tự về Android" (sự cố #6)
- Cờ slot nằm trong **thuộc tính GPT** của `boot_a`/`boot_b` (LUN0 `sda11`/`sda12`): active, retry-count (3 lượt sau `set-active`), successful, unbootable.
- Android đánh dấu `successful` bằng HAL boot_control; **Ubuntu không có** ⇒ sau 3 lần boot slot b (kể cả reset/watchdog) ⇒ `unbootable` ⇒ ABL boot slot a (Android stock) ⇒ Android thấy userdata ext4 ⇒ "Cannot load Android system…".
- **TUYỆT ĐỐI không chọn "Factory data reset"** trên màn đó — xoá sạch Ubuntu trên userdata. Chỉ cần vào fastboot (Vol Down + Power).
- Chẩn đoán: `fastboot getvar all 2>&1 | grep -E 'current-slot|:b:'` → thấy `slot-unbootable:b:yes`, `slot-retry-count:b:0`.
- Cứu: `fastboot --set-active=b` (không ghi dữ liệu, hoàn tác được) → `fastboot reboot` hoặc `fastboot boot …`.
- Phòng (đã áp 2026-11-13): gói `qbootctl` 0.1.2 (Ubuntu noble, linux-msm); unit là *static* nên gắn bằng symlink
  `/etc/systemd/system/multi-user.target.wants/qbootctl.service` → `qbootctl -m` sau `boot-complete.target` đánh dấu slot đang chạy (lấy từ `androidboot.slot_suffix`).
  Đánh dấu tay: `sudo qbootctl -m b` (tham số là `b`, không phải `_b`).
  Xem nhanh: `sudo qbootctl` (Active/Successful/Bootable từng slot).
- Lưu ý: khi `fastboot boot` (RAM), cmdline ABL ghi `androidboot.slot_suffix=_a` dù slot active là b ⇒ `qbootctl -m` lúc đó đánh dấu nhầm slot a (vô hại); chỉ boot thật từ boot_b mới đánh dấu b.
- Khi slot b đang `unbootable`, `fastboot boot` cũng có thể quay lại fastboot sau vài giây → `set-active=b` trước.
- Reboot bằng `systemctl reboot -ff` qua SSH: lệnh `ssh` treo đến khi TCP timeout (máy đã reboot, kết nối không đóng) — `80-deploy-kernel.sh` cần `ConnectTimeout`/`ServerAliveInterval` hoặc chạy nền.

