# Dự án: Ubuntu 24.04 arm64 native trên Google Pixel 3 XL (crosshatch)

Trả lời người dùng bằng **tiếng Việt**. Ghi mọi bước (lệnh, kết quả, lỗi, quyết định) vào `NOTES.md`.
Mọi bước build/flash phải là script tái lập được trong `./scripts/`, không làm tay.

## Bối cảnh
- Thiết bị: Google Pixel 3 XL, codename `crosshatch`, SoC SDM845, 4 GB RAM. Cắm USB vào MacBook.
- Mục tiêu: Ubuntu 24.04 LTS arm64 chạy NATIVE (không chroot), kernel mainline.
- Mục tiêu cuối: systemd, SSH qua USB (NCM) và Wi-Fi, màn hình bằng driver panel thật, Docker chạy được.
  Desktop để sau.

### Thông tin được cung cấp (CHƯA kiểm chứng — phải tự xác minh)
- DTS `arch/arm64/boot/dts/qcom/sdm845-google-crosshatch.dts` được cho là đã vào mainline Linux 7.0
  (David Heidelberg). Hỗ trợ: debug UART, UFS, USB-C peripheral, simple-framebuffer, GPU, Wi-Fi, BT.
  Trên 3 XL, mdss/dispcc bị disable để simple-framebuffer tiếp tục chạy.
- Driver panel 3 XL: "[PATCH v2 00/11] Pixel 3 XL display panel support" (Samsung AMB630QY01,
  DDIC S6E3HA8), msg-id `20260924-crosshatch-panel-v2-0-08d5c7bf72fc@ixit.cz`.
  → Kiểm tra đã merge chưa / có bản mới hơn; nếu chưa thì áp bằng `b4`.
- Tree tham khảo: https://gitlab.com/sdm845/sdm845-next
- Cover letter "Add support for Pixel 3 and Pixel 3 XL" (v7), mục "Booting": yêu cầu bootloader
  (board/MSM ID, TEXT_OFFSET). Đọc kỹ trước khi làm boot.img.
- U-Boot có tài liệu cho Pixel 3/3 XL (qcom_defconfig + google-pixel.config).
- Ubuntu 24.04.5 HWE được cho là dùng kernel 7.0 + Mesa 26.

Không bịa thông tin phần cứng: dựa vào DTS, cover letter, log thực tế. Chưa chắc thì nói rõ.

## LUẬT AN TOÀN (BẮT BUỘC)
1. Hỏi và chờ người dùng trả lời **"đồng ý"** trước MỌI lệnh không hoàn tác: `fastboot flashing unlock`,
   `fastboot flash`/`erase` bất kỳ phân vùng nào, format, xoá dữ liệu trên máy.
2. Chỉ được đụng các phân vùng: `boot_a/boot_b`, `dtbo_a/dtbo_b`, `vbmeta_a/vbmeta_b`, `userdata`.
   TUYỆT ĐỐI không flash/erase xbl, abl, aop, modem, persist, devcfg hay bất kỳ phân vùng
   bootloader/firmware nào khác.
3. KHÔNG BAO GIỜ chạy `fastboot flashing lock` khi máy có image không phải stock (nguy cơ brick cứng).
4. Luôn thử bằng `fastboot boot` trước khi flash thật.
5. Thao tác vật lý (bật OEM unlocking, Vol Down + Power vào fastboot, xác nhận unlock bằng phím
   âm lượng): nhắc người dùng làm và chờ họ báo xong.
6. Nếu máy là bản Verizon hoặc OEM unlock bị cấm: DỪNG và báo người dùng.

## Các pha (dừng sau mỗi pha để báo cáo, chờ duyệt pha tiếp)
- Pha 0 – Khảo sát (chỉ đọc): Mac + điện thoại (getprop), cài android-platform-tools nếu thiếu.
- Pha 1 – Đường lui + firmware: tải factory image crosshatch mới nhất, kiểm checksum; trích firmware
  (adsp, cdsp, mba/modem, venus, a630 zap, BT...) theo `firmware-name` trong DTS; nhắc sao lưu dữ liệu.
- Pha 2 – Môi trường build: container/VM Linux arm64 trên Mac (đề xuất, chờ duyệt trước khi cài lớn).
  Kernel mainline 7.x + series panel; built-in: UFS QCOM, USB gadget configfs + NCM, simpledrm;
  module: DRM_MSM, panel S6E3HA8, remoteproc, ath10k_snoc, BT QCA... Rootfs noble arm64 với
  openssh-server (key từ ~/.ssh), network-manager, bluez, qrtr/rmtfs/pd-mapper/tqftpserv,
  service USB NCM gadget IP tĩnh. Tất cả trong `./scripts/`.
- Pha 3 – Smoke test không phá dữ liệu: hỏi trước khi unlock; boot.img + initramfs tối giản;
  CHỈ `fastboot boot`. Kiểm tra kernel, mạng USB, màn hình, firmware Wi-Fi.
- Pha 4 – Cài thật: rootfs → userdata, boot.img → boot slot đang dùng, dtbo/vbmeta theo series.
  Mỗi lệnh flash đều hỏi. First boot: resize FS, SSH, Wi-Fi, systemd, Docker.
- Pha 5 – Để sau: U-Boot chainload + extlinux, desktop, cảm ứng, pin/ngưỡng sạc.

## Môi trường Mac (từ Pha 0)
- Apple M4, 16 GB RAM, macOS 26.6.2, Homebrew 7.0.9. Ổ đĩa chỉ còn ~15 GB trống (cần dọn/ổ ngoài).
- adb/fastboot: Homebrew cask android-platform-tools (37.0.1). Docker Desktop đã cài (daemon chưa chạy).
- Workspace lớn: `/Volumes/pixelwork` (sparsebundle Case-sensitive APFS trên SSD exFAT `/Volumes/LIB/pixel-ubuntu/`), mount bằng `scripts/00-workspace.sh`. Repo này (scripts, notes) vẫn ở `~/Desktop/pixel`.

## Trạng thái (cập nhật 2026-11-13, hết Pha 4)
- Ubuntu 24.04 chạy từ **boot_b** (kernel 7.4-rc2 **#10** + DTB 0013, panel v3 + patch 0001–0014: TEXT_OFFSET, cảm ứng, pin, loa, q6asm, max1720x, giới hạn/sạc nhanh, DT camera+micro, **USB PD 9 V**) và **userdata** (ext4 LABEL=pixelroot). Micro: thu ra toàn 0 (chưa xong); camera: IMX355 trước ở 0x10, chưa có ảnh.
- A/B: Ubuntu phải đánh dấu slot thành công (`qbootctl.service`), nếu không sau 3 lần boot ABL rơi về Android ("Cannot load Android system" — KHÔNG factory reset; `fastboot --set-active=b`). RUNBOOK §6.5.
- Truy cập: `ssh -o UserKnownHostsFile=.ssh_known_hosts ubuntu@172.16.42.1` (USB) hoặc qua Wi-Fi; dự phòng IPv6
  `fe80::ff:fe3a:2%enX`; serial USB tự đăng nhập (`/dev/cu.usbmodem*`, cửa sau debug).
- boot.img BẮT BUỘC: board-id 0x11505 (mặc định trong scripts/60-bootimg.sh) + AVB footer; ABL thay console= bằng null.
- Mạng USB KHÔNG được cấp gateway/DNS cho Mac (dnsmasq-shared.d) — nếu không Mac mất Internet.
- Về fastboot từ Ubuntu: `sudo sync; sudo systemctl reboot -ff --reboot-argument=bootloader` (reboot thường đang treo).
- Build kernel chậm (virtiofs): đổi option netfilter/autoconf → build lại ~22 phút.
- Đã chọn cho Pha 5: GNOME, điều khiển bằng Remote Desktop từ Mac.

**Tài liệu: `docs/README.md` (mục lục) → `docs/RUNBOOK.md` (vận hành + bảng lỗi), `docs/hardware/`, `docs/software/`, `docs/ARCHIVE.md`.** Đọc RUNBOOK trước khi làm.
