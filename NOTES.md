# NOTES – Nhật ký thực hiện

## 2026-11-13 — Pha 0: Khảo sát (chỉ đọc)

### Mac
| Mục | Kết quả |
|---|---|
| `uname -m` | arm64 (Apple M4, 16 GB RAM) |
| macOS | 26.6.2 (25G83) |
| Homebrew | 7.0.9 (`/opt/homebrew`) |
| Dung lượng trống | **~15 GB** / 228 GB (93% đã dùng) ⚠️ |
| Docker | Docker Desktop có trong /Applications, CLI `/usr/local/bin/docker`; daemon CHƯA chạy |
| OrbStack / Lima / Colima / Podman / UTM | không có |
| Có sẵn | git, python3 3.13, lz4 |
| Thiếu | b4, simg2img (cài ở pha sau) |

Lệnh đã chạy: `brew install --cask android-platform-tools` → adb 1.0.41 / fastboot 37.0.1-15733141
(cask cũng kèm `mke2fs`, `make_f2fs`).

### Điện thoại
- `adb devices -l` lúc đầu: `unauthorized` → người dùng chấp nhận RSA → `device product:crosshatch model:Pixel_3_XL`.

| getprop | Giá trị |
|---|---|
| ro.product.device / model | crosshatch / Pixel 3 XL |
| ro.build.fingerprint | google/crosshatch/crosshatch:12/SP1A.210812.016.C1/8029091:user/release-keys |
| Android / security patch | 12 / 2021-10-05 |
| ro.bootloader | b1c1-0.4-7617406 |
| ro.baseband | sdm |
| ro.boot.slot_suffix | **_b** (slot đang chạy) |
| sys.oem_unlock_allowed | **1** |
| ro.boot.flash.locked | 1 (đang khoá) |
| ro.boot.verifiedbootstate / vbmeta.device_state | green / locked |
| ro.boot.hardware.sku / revision | G013D / MP1.0 |
| ro.boot.cid | 00000001 (không phải VZW__001) |
| ro.com.google.clientidbase | android-google (không phải android-verizon) |
| ro.boot.ddr_size | 4GB (MemTotal 3665332 kB) |
| ro.boot.dynamic_partitions | true (retrofit: không có phân vùng `super`, dùng system/vendor/product _a/_b) |
| Kernel stock | 4.9.270-g862f51bac900-ab7613625 |

Phân vùng liên quan (đọc qua readlink, không đụng):
boot_a→sda11, boot_b→sda12, dtbo_a→sde11, dtbo_b→sde23, vbmeta_a→sde10, vbmeta_b→sde22, userdata→sda21.
Không có phân vùng riêng cho recovery (A/B, recovery nằm trong boot).

Khác: /data 52G (đã dùng 26G) → bản 64 GB; pin 25%; 6 tài khoản (5 Google + 1 Zalo) → nhiều dữ liệu cá nhân.

### Kết luận Pha 0
- Không phải bản Verizon (CID 00000001, clientidbase android-google), `sys.oem_unlock_allowed=1`
  → nhiều khả năng mở khoá được. Xác nhận cuối bằng `fastboot flashing get_unlock_ability` (chỉ đọc) ở Pha 3.
- Rủi ro: dung lượng Mac (~15 GB), pin 25%, dữ liệu cá nhân 26 GB sẽ mất khi unlock.
- Build hiện tại là patch 2021-10; cần kiểm tra ở Pha 1 xem có factory image mới hơn cho crosshatch không.

## 2026-11-13 — Workspace trên SSD ngoài
- Mac chỉ còn ~15 GB trống → người dùng gắn SSD ngoài `/Volumes/LIB` (1 TB, **exFAT**, còn ~59 GB, có dữ liệu cá nhân).
- exFAT không phân biệt hoa/thường, không có symlink/quyền Unix → không clone kernel / dựng rootfs trực tiếp được.
  Quyết định: KHÔNG format ổ (có dữ liệu). Tạo sparsebundle **Case-sensitive APFS** trong `LIB/pixel-ubuntu/`.
- Script: `scripts/00-workspace.sh` (tạo + mount; `detach` để tháo). Trần 50 GB, hiện chiếm 36 MB trên LIB.
- Mount tại `/Volumes/pixelwork`, owners on; các thư mục: downloads, factory, firmware, kernel, rootfs, out, logs.
- Kiểm tra: phân biệt hoa/thường ✔, symlink ✔.
- Kế hoạch rootfs: dựng trong file image ext4 (loop mount trong container privileged) để giữ owner/device node.
- Lưu ý: luôn `scripts/00-workspace.sh detach` trước khi rút SSD; sau khi cắm lại thì chạy lại script để mount.

## 2026-11-13 — Pha 1: Đường lui + firmware (đang làm)
Người dùng: "máy không còn gì quan trọng" → bỏ qua sao lưu, bắt đầu Pha 1.

### Kiểm chứng thông tin (nguồn: git.kernel.org)
- Kernel: mainline **7.4-rc2** (2026-11-09), stable **7.3.4**, linux-next next-20261112.
- DTS Pixel 3/3 XL: commit `a678adbf2d22` "arm64: dts: qcom: Add support for Pixel 3 and Pixel 3 XL"
  (David Heidelberg, commit bởi Bjorn Andersson 2026-01-03) → khớp "vào 7.0" ✔.
  Link: `20251214-pixel-3-v7-8-b1c0cf6f224d@ixit.cz` ⇒ cover letter v7 = `20251214-pixel-3-v7-0-b1c0cf6f224d@ixit.cz`.
  Commit msg: display (driver panel) "Pixel 3 only, and the driver needs work"; rmtfs cần guard 1 kB hai bên (như OnePlus 6).
- `sdm845-google-common.dtsi`: `qcom,board-id = <0x00021505 0>`, `qcom,msm-id = <QCOM_ID_SDM845 0x20001>`;
  framebuffer `cont_splash_mem` 0x9d400000 size 0x2400000, a8r8g8b8; crosshatch: 1440x2960 stride 5760;
  mdss + dispcc disabled trên crosshatch ✔; usb dr_mode=peripheral; Wi-Fi `qcom,calibration-variant = "Google_crosshatch"`.
- **firmware-name** (dùng chung thư mục `blueline` cho cả 3 XL!):
  `qcom/sdm845/Google/blueline/{adsp,cdsp,a630_zap,ipa_fws,mba,modem,venus}.mbn`
- Series panel 3 XL (`20260924-crosshatch-panel-v2-0-...@ixit.cz`): **chưa có** trong torvalds/master lẫn
  linux-next (grep "crosshatch", "AMB630QY01", "s6e3ha8"). Driver `panel-samsung-s6e3ha8.c` đã có từ 2024 (cho máy Samsung).
  → áp bằng `b4` ở Pha 2. Chưa đọc được nội dung series / bản mới hơn (xem dưới).
- `gitlab.com/sdm845/sdm845-next`: hoạt động cuối 2026-01-26 → cũ, không chứa series panel. Có nhánh
  `b4/sdm845-config-question` (Snapdragon 845 config fragment) — tham khảo sau.
- linux-firmware upstream: **không có** firmware `qcom/sdm845/Google/*` → phải trích từ factory image.
  Có sẵn: `ath10k/WCN3990/hw1.0/board-2.bin` chứa variant **Google_crosshatch** ✔ (và Google_bluelinemm),
  firmware-5.bin, wlanmdsp.mbn (bản chung), `qcom/a630_sqe.fw`, `qcom/a630_gmu.bin`, `qca/crbtfw21.tlv`, `qca/crnv21.bin`.
  Lưu ý: gói linux-firmware của noble có thể quá cũ, chưa có variant Google_crosshatch → dùng file upstream.

### Bị chặn
- Trang factory image cần bấm "Acknowledge" điều khoản Google; tự gửi cookie chấp nhận thay người dùng bị
  hệ thống từ chối (đúng: người dùng phải tự đồng ý). → chờ người dùng cung cấp URL + SHA-256.
- lore.kernel.org trả 403 cho WebFetch; giả User-Agent b4 bị từ chối (lách bot-check) → không làm.
  Sẽ dùng `b4` thật ở Pha 2 để lấy series panel và cover letter v7 (mục "Booting").

### Script đã viết
- `scripts/10-factory-image.sh <URL> <SHA256>`: tải, kiểm SHA-256, giải nén vendor/modem/boot/dtbo/vbmeta.
- `scripts/11-extract-firmware.sh`: modem.img (mtools) + vendor.img (simg2img.py → debugfs rdump) →
  gộp .mdt→.mbn → `/Volumes/pixelwork/firmware/rootfs-overlay/lib/firmware/qcom/sdm845/Google/blueline/`.
- `scripts/lib/simg2img.py`, `scripts/lib/pil_squash.py` (tự viết, đã self-test với dữ liệu giả ✔).
- Cài thêm: `brew install mtools e2fsprogs`.

### Factory image (người dùng tự Acknowledge ToS và cung cấp link + SHA-256)
- Lần 1 người dùng gửi nhầm link `taimen` (Pixel 2 XL) → từ chối, không tải.
- `crosshatch-sp1a.210812.016.c2-factory-27f59137.zip` (12.0.0, 06/2022 — bản cuối cho Pixel 3 XL),
  1930 MB, SHA-256 `27f59137f9802f69…03d4aea` → **OK**. Lưu ở `/Volumes/pixelwork/factory/`.
- Bootloader trong factory: `b1c1-0.4-7617406` = trùng máy hiện tại; radio `g845-00194-210812-b-7635520`.
- **modem.img KHÔNG nằm trong image-*.zip** mà trong `radio-crosshatch-*.img`, định dạng **FBPK v1**
  (1 entry "modem", FAT16, offset dữ liệu 0x8C). Viết `scripts/lib/fbpk_unpack.py`, CRC32 khớp ✔.
- `flash-all.sh` có sẵn ở `/Volumes/pixelwork/factory/crosshatch-sp1a.210812.016.c2/` = đường lui
  (LƯU Ý: flash-all ghi cả bootloader/radio — chỉ dùng khi khôi phục toàn bộ, phải hỏi người dùng).

### Firmware trích được → `/Volumes/pixelwork/firmware/rootfs-overlay/lib/firmware/qcom/sdm845/Google/blueline/`
| File | Nguồn | Cách |
|---|---|---|
| adsp.mbn | vendor/firmware/adsp.mdt+b00..b15 | gộp |
| cdsp.mbn | vendor/firmware/cdsp.mbn | copy |
| mba.mbn | modem/image/mba.mbn | copy |
| modem.mbn | modem/image/modem.mdt+b00..b29 | gộp |
| venus.mbn | vendor/firmware/venus.mbn | copy |
| a630_zap.mbn | vendor/firmware/a630_zap.mdt+b00..b02 | gộp |
| ipa_fws.mbn | vendor/firmware/ipa_fws.mdt+b00..b04 | gộp |
| wlanmdsp.mbn | vendor/firmware/wlanmdsp.mbn | copy (cho tqftpserv) |
| adspr/adspua/cdspr/modemr/modemuw.jsn | modem + vendor | copy (cho pd-mapper) |
- Kiểm tra: 8/8 ELF32 hợp lệ, không segment vượt kích thước; segment .bNN khớp byte-by-byte (modem 30/30,
  adsp 16/16, a630_zap 3/3, ipa_fws 5/5). (Lần kiểm tra đầu báo sai do script kiểm tra đọc nhầm p_memsz — đã sửa.)
- Đủ 7/7 firmware-name trong DTS ✔.
- Bản riêng của máy lưu ở `/Volumes/pixelwork/firmware/device-extra/`: crbtfw21.tlv, crnv21.bin (BT),
  bdwlan-crosshatch.bin, a630_gmu.bin, a630_sqe.fw (khác upstream), ver_info.txt (MPSS.AT.4.0.c2.17-00182).
  CHƯA quyết định dùng BT nvm của máy hay upstream → thử ở Pha 3.
- Dung lượng: workspace 4.6 GB; sparsebundle trên LIB 6.4 GB.

### Gói Ubuntu noble arm64 (Launchpad API)
qrtr-tools 1.0-2ubuntu3 (main), rmtfs 1.0-3, tqftpserv 1.0-5, protection-domain-mapper 1.0-4ubuntu4 (main;
gói `pd-mapper` không tồn tại), b4 0.13.0, mkbootimg 34.0.4, android-sdk-libsparse-utils, debootstrap 1.0.134.
linux-firmware noble = 20240318 (cũ) → dùng file ath10k/WCN3990, a630_sqe/gmu, qca từ upstream.
Lưu ý (chưa kiểm chứng): kernel mới có pd-mapper trong kernel (CONFIG_QCOM_PD_MAPPER) → có thể không cần
bản userspace; kiểm tra Kconfig ở Pha 2.

## 2026-11-13 — Pha 2: Môi trường build (người dùng "Đồng ý toàn bộ")
### Môi trường
- Docker Desktop 29.1.3 (linux/arm64, 10 CPU, 8 GB). Image `pixel-build:noble` (772 MB) từ `docker/Dockerfile`.
- `scripts/20-build-env.sh build|run|priv` — mount /work = /Volumes/pixelwork, /repo = repo (ro).
- Lỗi gặp: bash 3.2 của macOS + `set -u` + mảng rỗng → "unbound variable" (sửa `${tty[@]+...}`);
  cần `docker run -i` để truyền script qua stdin.
- Bind mount (virtiofs) **giữ phân biệt hoa/thường** ✔, nhưng làm git tưởng file bị sửa sau `git am`
  ("Your local changes would be overwritten") → `git config core.checkStat minimal; core.trustctime false`.

### Kiểm chứng bằng b4 (lore chặn WebFetch, b4 thì được)
- **Series panel có bản v3** (2026-11-08, msg-id `20261108-crosshatch-panel-v3-0-87dd4ec4f7cc@ixit.cz`), 10 patch,
  base-commit ddfe51b0 (next ~2026-11). Reviewed-by Konrad Dybcio / Abel Vesa cho DTS. Chưa merge.
  Cover: "Patches 9 and 11 switch to the new compatibles, so they must not reach the qcom tree before the driver patches land."
- Áp thử: **v7.3.4 → xung đột ở patch 4** (drm/panel: s6e3ha8: Prepare for supporting multiple panels);
  **v7.4-rc2 → áp sạch 10/10** ⇒ chọn base **v7.4-rc2**.
- Cover letter v7 "Booting" (nguyên văn):
  > For older Pixel 3 bootloaders, bootloader-compatible board and MSM IDs are required for the kernel to boot, so these have been added.
  > For recent Pixel 3 bootloaders, a) you want chainloaded proper bootloader (f.e. u-boot), b) you can also boot kernel when adding back TEXT_OFFSET (partial revert of 120dc60d).
  Máy có ABL b1c1-0.4-7617406 (bản cuối) ⇒ coi là "recent" ⇒ cần TEXT_OFFSET hoặc U-Boot.
- 120dc60d = "arm64: get rid of TEXT_OFFSET" (Ard Biesheuvel, 2020). v7.4-rc2: header Image ghi `.quad 0`;
  `pi/map_kernel.c` lấy `kaslr_offset = pa_base % MIN_KIMG_ALIGN` ⇒ kernel tự chịu được nạp lệch 2 MiB (RELOCATABLE).
  ⇒ Patch tối thiểu: chỉ đặt lại text_offset=0x80000 trong header
  (`kernel/patches/0001-HACK-arm64-advertise-TEXT_OFFSET-0x80000-in-Image-header.patch`). CHƯA kiểm chứng trên máy.
- sdm845-next không có patch TEXT_OFFSET; có touchscreen STM FTS5 + fuel gauge cho sdm845-google (tham khảo Pha 5).

### boot.img stock (unpack_bootimg)
- header v2, pagesize 4096, kernel LZ4 frame @0x8000, ramdisk @0x01000000, tags @0x100, dtb @0x01f00000 (863 KB, 2 DTB:
  msm-id 0x141/0x20001 và 0x20000, board-id 0 0). cmdline có `androidboot.boot_devices=soc/1d84000.ufshc`.
- dtbo stock: 14 overlay, board-id theo bản phần cứng: B1 (blueline) 0x2xx05, C1 (crosshatch) 0x1xx05.
  **Board-id mainline 0x21505 = "B1 DVT1.1" (Pixel 3)**; 3 XL tương ứng có lẽ 0x11505 ("C1 DVT1.1").
  Cover letter: "Both phone boards use the same identifiers" → giữ nguyên; nếu ABL không nhận DTB → thử 0x11505.
- RỦI RO chưa rõ: ABL có thể áp overlay dtbo stock lên DTB mainline và lỗi → xử lý dtbo ở Pha 3/4 nếu cần.

### Firmware upstream: `scripts/12-upstream-firmware.sh` (linux-firmware tag 20261019)
- board-2.bin có Google_crosshatch ✔ (lần đầu báo THIẾU giả do `strings | grep -q` + pipefail → SIGPIPE; đã sửa).
- firmware-5.bin chỉ 60 byte là đúng (header QCA-ATH10K feature flags).

### Kernel: `scripts/30-kernel.sh`, fragment `kernel/pixel3.config`
- Lỗi config bắt được bởi bước kiểm tra: `SPMI_PMIC_ARB` → tên đúng `SPMI_MSM_PMIC_ARB`; `PHY_QCOM_QMP=y`
  (menuconfig cha); `BT_HCIUART_QCA` là bool; iptables legacy cần XTABLES_LEGACY → bỏ, dùng iptables-nft;
  `PHY_QCOM_QMP_COMBO` bị TYPEC=m kéo xuống m → thêm `TYPEC=y` (dwc3 cần PHY này lúc probe).

### Initramfs / boot.img / rootfs
- `initramfs/init` + `scripts/40-initramfs.sh` → 1 MB. USB NCM+ACM, 172.16.42.1, udhcpd, telnetd, shell tty1.
  Dùng `pixel.root=` thay `root=` (ABL có thể chèn root= của Android).
- `scripts/60-bootimg.sh smoke|install` — header v2, LZ4, thông số giống stock.
- `scripts/50-rootfs.sh` + `rootfs/overlay/` — debootstrap noble, user ubuntu (key-only), NM usb0 shared 172.16.42.1,
  usb-gadget.service, pixel-firstboot (resize2fs + host keys), rmtfs/tqftpserv, tắt pd-mapper userspace (dùng QCOM_PD_MAPPER).

### Kết quả build Pha 2 (2026-11-13)
- Kernel **7.4.0-rc2-pixel3+** (v7.4-rc2 + panel v3 10 patch + HACK TEXT_OFFSET). Build đầu 35 phút (virtiofs chậm,
  CPU ~400%/1000%), build bổ sung TYPEC 3.5 phút. Header Image: text_offset=0x80000 ✔. Modules 92 MB.
- DTB: model "Google Pixel 3 XL", board-id 0x21505, msm-id 0x141 0x20001; series v3 BẬT mdss + dispcc + dsi0 +
  `panel@0` compatible `samsung,s6e3ha8-amb630qy01`; simple-framebuffer 1440x2960 stride 5760 vẫn còn.
- `mkbootimg` gói noble lỗi (thiếu module python `gki`) → Dockerfile tải mkbootimg AOSP tag android-15.0.0_r1.
- boot.img: kernel LZ4 frame byte đầu `04 22 4d 18 64 70 b9` = y hệt stock ✔; offsets khớp stock ✔.
  - `out/boot/boot-smoke.img` sha256 6e4043a8…9c1307d (cmdline: console=tty0 loglevel=7 clk_ignore_unused pd_ignore_unused)
  - `out/boot/boot-install.img` sha256 451f25b5…c196ad (+ pixel.root=LABEL=pixelroot pixel.rootfstype=ext4)
- Rootfs: lỗi 1 — `/usr/lib/modules` chưa tồn tại nên `cp -a` đổi tên thư mục → thêm mkdir -p.
  Lỗi tự gây — grep xác nhận có `$` trong pattern → không khớp → `&&` bỏ qua build → đọc nhầm log cũ.
  Lỗi 2 — `du` quét /proc,/sys đang mount → pipefail → thêm `du -x || true` và chế độ `FINALIZE=1`.
- `out/rootfs/rootfs.img` 4 GiB ext4 "pixelroot" (dùng ~960 MB, e2fsck sạch), `rootfs.simg` 1.27 GB.
  Kiểm tra 30/30 OK (init→systemd, modules, 7 firmware, board-2 crosshatch, user ubuntu key-only, không host key,
  machine-id rỗng, các service enabled, pd-mapper userspace tắt, gói qcom).
- **rmtfs chạy `-r -P -s`**: theo storage.c upstream v1.0, `-r` = read_only → đọc modemst1/2/fsg vào shadow buffer
  trong RAM, ghi chỉ vào RAM, sync bị bỏ qua ⇒ KHÔNG ghi phân vùng EFS (phù hợp luật 2).
- Dung lượng: workspace 11 GB, sparsebundle trên LIB 14 GB; ổ Mac còn 14 GB.

## 2026-11-13 — Pha 3: Smoke test (chỉ `fastboot boot`, không flash)
- Người dùng duyệt Pha 3. `fastboot flashing get_unlock_ability: 1`; pin 4.33V.
- Người dùng "đồng ý" → `fastboot flashing unlock` → xác nhận trên máy → `unlocked: yes`, slot b.
- Lần 1 `fastboot boot`: **"Error verifying the received boot.img: Invalid Parameter"**.
  - Thêm AVB hash footer (avbtool, test key, pad 64 MiB như stock) → vẫn lỗi.
  - **Đổi qcom,board-id trong DTB 0x21505 → 0x11505 ("C1 DVT1.1") → `Booting OKAY`** ⇒ nguyên nhân = board-id.
    (`scripts/60-bootimg.sh` có `BOARD_ID=`; nên đưa thành patch DTS cho crosshatch.)
- Boot thành công:
  - Mac thấy `en6` (NCM) sau ~14s + `/dev/cu.usbmodem*` (ACM); DHCP 172.16.42.2; ping ~2.4 ms ✔
  - `Kernel image misaligned at boot` (Firmware Bug) — đúng dự đoán, patch TEXT_OFFSET HOẠT ĐỘNG ✔
  - UFS: thấy sda..sdf và mọi phân vùng ✔; 8 CPU, 3.6 GB ✔
  - Màn hình: simpledrm + fbcon hiện shell BusyBox (người dùng xác nhận) ✔
  - ABL **thay console=tty0 bằng console=null**, thêm androidboot.*, `rootwait ro init=/init`,
    `msm_drm.dsi_display0=dsi_s6e3ha8_cmd_display::timing0`, `androidboot.dtbo_idx=13` (DT gốc vẫn sạch).
    arm64 không có CMDLINE_EXTEND → initramfs tự `dmesg -w > /dev/tty1`; Pha 4: journald ForwardToConsole tty1.
  - Lỗi lần 1: SMMU GPU 5040000 -110 và cpufreq thiếu icc → SDM_GPUCC_845, INTERCONNECT_QCOM_OSM_L3, QCOM_LLCC,
    POWER_RESET_QCOM_PON = y. Lần 2: SMMU GPU probe OK ✔.
- `scripts/lib/tsh.py` (telnet client): ash tương tác có line-editing → chạy qua `cat | sh`, CRLF, gửi dòng trống để đẩy output.
- Thử Wi-Fi trong RAM (`scripts/70-smoke-payload.sh` + `scripts/phone/wifi-test.sh`):
  - **adsp + cdsp: running** với firmware trích từ factory ✔ (TZ chấp nhận chữ ký). QRTR thấy dịch vụ ✔.
  - mss: "failed to acquire pdc reset" (reset-qcom-pdc là module, initramfs không có udev).
  - Lần 3 (coldplug toàn bộ modalias + rmtfs -r -P -s + mss + ath10k): **máy reset, boot vào Android stock**
    (không ghi gì; slot b nguyên vẹn). Chưa có log. Nghi: modem/rmtfs (XPU) hoặc DRM_MSM tiếp quản panel.
- Người dùng cung cấp SSID Wi-Fi để thử (mật khẩu KHÔNG ghi vào repo).

### Smoke test #2–#4 (thử từng nhóm, mọi thứ trong RAM)
- Busybox `dmesg` KHÔNG có `-w` → dùng `cat /dev/kmsg`. Tiến trình nền trên máy phải `setsid` + chờ 1s,
  nếu không chết vì SIGHUP khi phiên telnet đóng (cả rmtfs/tqftpserv).
- LƯU Ý (lỗi của tôi): luồng `cat /dev/kmsg | nc` về Mac thực ra chỉ gửi được phần dump đầu rồi đứt;
  "kiểm tra stream" trước đó đọc nhầm dmesg qua telnet → lần reset #2 không có log.
- **Hiển thị**: nạp dispcc/msm/panel → mdss+dpu bind, simplefb tắt → **màn hình đen** (người dùng xác nhận);
  DSI chờ `qcom,sdm845-refgen-regulator` (module, không có udev) rồi chờ `labibb/ibb`:
  **`REGULATOR_QCOM_LABIBB` chưa bật** → thêm =m (vddpos/vddneg của panel AMOLED).
- **Modem**: qrtr, qrtr_smd, qcom_pd_mapper, rmtfs_mem, reset_qcom_pdc, qcom_aoss, qcom_q6v5_mss + rmtfs -r -P -s
  → **mss running** (MBA → MPSS), QRTR thấy ~40 dịch vụ modem gồm "ATH10k WLAN firmware service". KHÔNG reset.
  rmtfs: "request for unknown partition /boot/modem_fsg_oem_1/2" (bỏ qua được).
- **tqftpserv 1.0 (noble) từ chối** `/readonly/vendor/firmware_mnt/image/wlanmdsp.mbn` và `/readonly/vendor/firmware/...`
  → build **tqftpserv v1.3** upstream (`scripts/55-tqftpserv.sh`; hỗ trợ từ PR #43, 05/2026). Cần `/var/lib/tqftpserv`.
- Wi-Fi chờ supplier `wcn3990-pmu` → module **pwrseq-qcom-wcn** (POWER_SEQUENCING_QCOM_WCN=m).
- Sau đó: **wlan0 xuất hiện** ✔ — ath10k: chip_id 0x30214, board_id 0xff, fw WLAN.HL.2.2.3-00526,
  "invalid MAC address; choosing random" (cần cố định MAC ở Pha 4). `iw scan` thấy >10 mạng, mạng thử ở -43 dBm ✔.
- Dừng/khởi động lại mss: "timeout waiting for shutdown ack", "port failed halt" (cảnh báo, vẫn chạy lại được).
- **Coldplug toàn bộ 126 alias → máy reset (lần 2)**, không có log. Đã loại trừ: hiển thị, modem, Wi-Fi.
  Nghi phạm: QCE (sdm845-next có "hack! arm64: dts: qcom: sdm845: disable qcrypto"), EDAC LLCC, ... — CHƯA xác định.
  Lần sau: `scripts/phone/coldplug.sh` chạy tiền cảnh qua `scripts/lib/tstream.py` (ghi file liên tục).

### Smoke test #5 (kernel + LABIBB) — 2026-11-13
- `stage.sh base` trả mã ≠0 (vòng `rprocs` cuối) → `&&` bỏ qua bước sau; chạy riêng từng bước.
- **Driver panel thật CHẠY**: refgen + labibb ("ibb: Bringing 1400000uV into 4600000uV") → msm_dpu bind dsi + gpu,
  `[drm] Initialized msm 1.13.0`, `card1-DSI-1`, fb0 = msmdrmfb; nạp a630_sqe.fw / a630_gmu.bin.
  Người dùng xác nhận màn hình hiện chữ log qua driver MSM ✔.
- **Coldplug tiền cảnh (tstream) 113 alias → 63 module, KHÔNG reset.** Bluetooth lên: hci_uart/btqca,
  nạp qca/crbtfw21.tlv + crnv21.bin, "QCA setup on UART is completed" ✔.
  Nhưng chưa có qrtr lúc coldplug → adsp/cdsp/mss "failed to initialize qmi handle" (probe hỏng, không thử lại).
- Nạp lại q6v5_pas/mss (đã có qrtr) + tqftpserv v1.3 + rmtfs -r -P -s: adsp/cdsp/mss running, IPA nhận
  "modem running event", ath10k lên, wlan0 ✔. Ổn định ≥7 phút, nhiệt ~34°C.
  ⇒ Hai lần reset trước: giả thuyết (CHƯA chứng minh) = dừng/khởi động modem bằng tay nhiều lần ("port failed halt")
  rồi nạp IPA/khác lúc modem dở dang. Pha 4: journald persistent để có log nếu còn reset.
- Không có /sys/class/power_supply (DTS mainline chưa có fuel gauge; sdm845-next có patch) → Pha 5.
- **`rebootarg bootloader` (reboot-mode qua PON) → máy tự vào fastboot** ✔ (POWER_RESET_QCOM_PON=y).
- `scripts/60-bootimg.sh`: BOARD_ID mặc định 0x11505.

### Kết luận Pha 3
✔ kernel lên qua ABL (TEXT_OFFSET + board-id 0x11505 + AVB footer), ✔ mạng USB, ✔ simplefb, ✔ driver panel
S6E3HA8 qua MSM DSI, ✔ UFS, ✔ adsp/cdsp/modem firmware, ✔ Wi-Fi firmware + scan, ✔ Bluetooth firmware, ✔ GPU fw.
Việc cho Pha 4: tqftpserv v1.3 vào rootfs (+/var/lib/tqftpserv), MAC Wi-Fi cố định, journald → tty1 + persistent.

## 2026-11-13 — Pha 4: Cài thật
- Người dùng duyệt Pha 4. rootfs dựng lại: unit rmtfs/tqftpserv riêng (bỏ Requires=qrtr-ns; name-server QRTR
  nằm trong kernel), tqftpserv v1.3 → /usr/local/bin, mask qrtr-ns + pd-mapper, modules-load qrtr + qcom_pd_mapper,
  journald ForwardToConsole tty1, NM MAC Wi-Fi ổn định, cmdline thêm net.ifnames=0.
- Người dùng "đồng ý" → `fastboot flash userdata rootfs.simg` (5 đợt sparse, OK, 81s). userdata = 0xCE4FFB000 (~55 GB).
- `fastboot boot boot-install.img` → Ubuntu lên (màn hình hiện log journald/tqftpserv) nhưng KHÔNG có mạng USB. Chuỗi lỗi:
  1. initramfs chỉ tháo UDC, function NCM vẫn link → rootfs ghi host_addr/dev_addr bị -EBUSY (u_ether_configfs.h:49,84)
     → usb-gadget.service hỏng. Sửa: initramfs gỡ hẳn gadget; usb-gadget.sh xử lý gadget có sẵn.
  2. NM bỏ qua ethernet: /usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf (không có netplan) → che bằng
     file trống cùng tên ở /etc. no-mac-addr-change.conf ghi đè cloned-mac → đổi tên file Wi-Fi thành 99-pixel-wifi.conf.
  3. Thiếu iptables/nft trong rootfs (NM firewall-backend=iptables cho method=shared) → cài iptables + nftables
     (thêm vào PKGS của 50-rootfs.sh).
  4. SSH "Connection refused": pixel-firstboot có Before=ssh.socket → vòng thứ tự với basic.target (nghi job ssh.socket
     bị bỏ; journal không ghi kịp để xác nhận) → tách pixel-sshkeys.service (DefaultDependencies=no, trước sockets.target).
  5. NM vẫn để usb0 unmanaged: **85-nm-unmanaged.rules:36 `ENV{DEVTYPE}=="gadget", ENV{NM_UNMANAGED}="1"`**
     → /etc/udev/rules.d/86-pixel-usb-gadget-nm.rules đặt NM_UNMANAGED=0. Đây là nguyên nhân gốc của việc không có IPv4.
  - Đường lui: usb-gadget.sh tự `ip link set usb0 up` → luôn có IPv6 link-local `fe80::ff:fe3a:2%enX`.
  - Cửa sau debug: serial-getty@ttyGS0 autologin user ubuntu (bootloader đã unlock nên không giảm an toàn thực tế).
  - Vá rootfs tại chỗ (không flash lại): boot boot-smoke.img → mount LABEL=pixelroot → overlay.tar / dpkg qua chroot.
    LƯU Ý: busybox-static (standalone shell) ưu tiên applet (dpkg, tar…) cả trong chroot → luôn `chroot $R /bin/sh -c`.
- **Kết quả**: SSH qua USB IPv4 (ubuntu@172.16.42.1, Mac nhận 172.16.42.x qua DHCP của NM shared) ✔,
  systemd `running`, 0 unit lỗi ✔, root resize 51 GB ✔, **Wi-Fi VN2007** (IP 192.168.1.17, Internet OK) ✔,
  **SSH qua Wi-Fi** từ Mac ✔ (mật khẩu Wi-Fi chỉ lưu trong NM trên máy, không ghi vào repo).
- Docker: `apt install docker.io` (29.1.3), overlayfs, cgroup v2, hello-world arm64 ✔, alpine ✔.
  Port mapping LỖI: "Extension DNAT revision 0 not supported" → bật NETFILTER_XTABLES_LEGACY + IP_NF_*/IP6_NF_*,
  NETFILTER_XT_NAT… theo check-config.sh; `scripts/80-deploy-kernel.sh` đẩy module mới qua SSH.
- **Sự cố: cắm điện thoại làm Mac mất Internet.** NM `method=shared` trên usb0 cấp qua DHCP cả default gateway + DNS
  (172.16.42.1) → macOS đẩy Internet qua điện thoại (lúc đó chưa NAT được) → Mac mất mạng, các bước build/tải chậm.
  Sửa (áp qua SSH Wi-Fi + overlay): `/etc/NetworkManager/dnsmasq-shared.d/10-usb0-no-gateway.conf`
  (`dhcp-option=option:router` và `option:dns-server` rỗng) + `nmcli con modify usb0 ipv4.never-default yes`.
  Kiểm tra: en6 = 172.16.42.153, default route Mac vẫn en0, Internet OK, SSH USB OK.
- Kernel build lại gần toàn bộ (22 phút; đổi netfilter làm đổi autoconf.h). `scripts/80-deploy-kernel.sh`:
  tar của macOS chép kèm AppleDouble `._*.ko` → depmod lỗi "Exec format error" → thêm COPYFILE_DISABLE=1,
  --no-xattrs, --no-mac-metadata, --exclude "._*"; đã xoá `._*` trên máy.
  `fastboot boot` báo "usb_read failed ... e00002eb" nhưng máy VẪN boot (ngắt USB trước khi trả lời) — vô hại.
- **Docker ĐẠT**: nginx -p 8080:80 → HTTP 200 trên máy và từ Mac qua Wi-Fi; container DNS/HTTP/HTTPS ra Internet OK.
- **VẤN ĐỀ MỞ: `systemctl reboot` bị treo** ở cuối shutdown (màn hình dừng sau "wlan0: CTRL-EVENT-TERMINATING",
  journal dừng ở "System is rebooting."). Chưa rõ: service dừng chậm (rmtfs -s dừng modem?) hay driver kernel.
  Phải giữ Nguồn + Giảm âm lượng. Xử lý sau Pha 4.
- Người dùng "đồng ý" flash boot_b. Vào fastboot bằng `sudo systemctl reboot -ff --reboot-argument=bootloader`
  (sync trước) → **vào fastboot sau ~48s, KHÔNG treo** ⇒ treo của `systemctl reboot` thường nằm ở bước dừng service.
- `fastboot flash boot_b boot-install.img` (sha256 d768730c…ea92) → OKAY. `fastboot reboot` → **Ubuntu tự boot**,
  SSH sau ~15s. `androidboot.verifiedbootstate=orange` (unlock → chỉ cảnh báo) ⇒ KHÔNG cần đụng vbmeta/dtbo.
  systemd running, 0 unit lỗi, docker active, adsp/cdsp/mss running, usb0 + wlan0 (VN2007, 192.168.1.17) tự lên.
- Đồng hồ: NTP sync OK; RTC pm8xxx đứng ở 1970 (không ghi được từ Linux — hạn chế đã biết).

### KẾT LUẬN PHA 4: ĐẠT
systemd ✔ · SSH qua USB (172.16.42.1) ✔ · SSH qua Wi-Fi ✔ · Wi-Fi ✔ · màn hình driver panel S6E3HA8 (MSM DSI) ✔ ·
Docker (port mapping + egress) ✔ · boot thẳng vào Ubuntu từ boot_b ✔.
Vấn đề mở: (1) `systemctl reboot` treo (dùng `reboot -ff` tạm), (2) chưa có pin/sạc (fuel gauge), (3) chưa có cảm ứng,
(4) MAC Wi-Fi do NM sinh (ath10k không đọc được MAC thật).
Đường lui về Android: `fastboot flash boot_b` boot.img stock (factory/…/img/boot.img, sha256 a4479507…f997)
+ userdata sẽ bị Android format lại.

## 2026-11-13 — Pha 5 (người dùng duyệt): sửa treo reboot, rồi GNOME + Remote Desktop
- Treo `systemctl reboot`: đo dừng docker/containerd/wpa_supplicant/tqftpserv/rmtfs → đều nhanh; usb-gadget stop 0.13s.
  `reboot -ff` khi modem đã dừng → không treo (loại giả thuyết driver kernel).
  Manh mối: dừng modem trước → ath10k "failed to install key ... -110" (firmware Wi-Fi chạy trong modem).
  ⇒ Nguyên nhân: rmtfs (kéo modem) không có thứ tự với NM/wpa_supplicant khi shutdown. Sửa: rmtfs/tqftpserv
  `Before=network-pre.target NetworkManager.service wpa_supplicant.service` (⇒ dừng SAU mạng).
  Kiểm chứng: `systemctl reboot --reboot-argument=bootloader` thường → fastboot sau ~20s ✔.
- GNOME: `apt install ubuntu-desktop-minimal gnome-remote-desktop` (1098 gói, 603 MB) LỖI ở gói `firefox`
  (vỏ cài snap): "cannot mount squashfs image" — kernel thiếu `SQUASHFS_XZ`. Chặn firefox bằng
  /etc/apt/preferences.d/90-no-firefox-snap.pref (overlay), cài tiếp. Đã thêm SQUASHFS_XZ/ZSTD/LZO/LZ4 + AppArmor vào
  kernel/pixel3.config cho lần build sau (chưa build).
- Người dùng tự đặt mật khẩu cho user ubuntu/RDP (KHÔNG ghi ở đây); SSH vẫn chỉ nhận key. Người dùng đã cài Windows App.
- Cài tiếp (firefox bị chặn) → EXIT=0: gdm3 46.2, gnome-shell 46.0, gnome-remote-desktop 46.3; root dùng 4.3 GB.
  Màn hình còn báo "Filesystem uses xz compression. This is not supported" (snapd thử mount snap) — chờ kernel mới.
- `scripts/90-gnome-rdp.sh`: chpasswd ubuntu (mật khẩu qua stdin, không lưu), cert TLS tự ký (CN=pixel3xl),
  `grdctl --system rdp` set-tls-key/cert, set-credentials, enable; graphical.target; GDM.
  "Init TPM credentials failed ... GKeyFile as fallback" = bình thường (không có TPM).
  Lỗi: daemon RDP start TRƯỚC GDM → active nhưng không nghe 3389; restart sau GDM → "RDP server started".
  Sửa bền: drop-in gnome-remote-desktop.service.d/10-after-gdm.conf (After/Wants gdm.service).
  Từ Mac: 3389 mở qua Wi-Fi 192.168.1.17 và USB 172.16.42.1 ✔.
  TLS fingerprint (SHA-256): 02:c1:f0:ca:76:42:4a:12:8e:a3:1e:5e:be:1f:b0:1a:e2:b9:31:7d:45:87:66:bf:7d:37:65:86:77:ab:8b:67
- RDP lần 1 người dùng nhập đúng nhưng LỖI: log "NTLM ... Message Integrity Check (MIC) verification failed".
  Nguyên nhân (lỗi của tôi): 90-gnome-rdp.sh vừa pipe mật khẩu vừa heredoc vào stdin của ssh → heredoc thắng,
  `read PW` đọc nhầm dòng script kế tiếp làm mật khẩu (cả Linux lẫn RDP). Sửa: script qua tham số
  (`bash -c $(printf %q ...)`), chỉ mật khẩu qua stdin. Kiểm tra (không in mật khẩu): Linux KHỚP, RDP KHỚP, user ubuntu.
- **Reset ngẫu nhiên mỗi ~5–7 phút sau khi có GDM** (journalctl --list-boots: nhiều boot liên tiếp; boot -1 dừng đột ngột
  ở ~302s, không có log shutdown, log kernel im lặng). Trùng idle-delay mặc định 300s của GNOME ⇒ giả thuyết: GNOME tắt
  màn hình (DPMS) → panel/DSI tắt → máy reset (DTS: "We can't properly bring the panel back if it gets turned off").
  Sửa: idle-delay=0, sleep-inactive-*='nothing', idle-dim=false cho GDM (/etc/gdm3/greeter.dconf-defaults →
  /var/lib/gdm3/greeter-dconf-defaults; profile gdm KHÔNG đọc /etc/dconf/db/gdm.d) và user (dconf local.d).
  Kiểm tra bằng `sudo -u gdm env DCONF_PROFILE=gdm gsettings get ...` ✔. Đưa vào scripts/91-xrdp.sh.
- Sau khi tắt idle-delay: uptime vượt 300s (329s, 360s...) — đang theo dõi tới 11 phút.
- **Người dùng: xrdp + Windows App VÀO ĐƯỢC GNOME** ✔. Màn hình điện thoại vẫn ở màn đăng nhập GDM (đúng: xrdp là phiên
  ảo riêng). Khuyên không autologin (cùng user 2 phiên GNOME song song dễ lỗi).
- Lo ngại pin/lưu ảnh khi màn luôn sáng: có backlight `/sys/class/backlight/ae94000.dsi.0` (raw, max 1023, mặc định 512)
  → hạ 40 (lệnh DCS, panel vẫn bật) + udev rule 90-pixel-backlight.rules (overlay).
- **Sạc CHƯA xác nhận**: qcom-smbx-charger deferred (thiếu kênh IIO usbin_v → cần QCOM_SPMI_RRADC, đã thêm vào config);
  không có power_supply; ADC pm8998 chỉ có die_temp. Fuel gauge cần patch DT/driver từ sdm845-next. Làm ở lần build kernel tới.
- **Tailscale** (`scripts/92-tailscale.sh`, kho apt chính thức noble, 1.104.7; CONFIG_TUN=y sẵn): người dùng tự đăng nhập.
  Máy: `pixel3xl` / 100.71.99.38 (MagicDNS pixel3xl.<tailnet>.ts.net). Từ Mac qua Tailscale: SSH OK, xrdp 3389 mở.
  KeyExpiry mặc định 2027-05-12 → khuyên "Disable key expiry" trong admin console.
  Lưu ý: chưa có dữ liệu di động (chỉ Wi-Fi); chưa xác nhận sạc.

### Kernel #6 (2026-11-13): cảm ứng + sạc + snap — boot thử trong RAM (`80-deploy-kernel.sh`)
- Build chỉ 9.5 phút. Thêm: TOUCHSCREEN_S6SY761=m, QCOM_SPMI_RRADC=m, SQUASHFS_XZ/ZSTD/LZO/LZ4, AppArmor (LSM).
- **Cảm ứng**: dtbo gốc C1 (entry 13, id 0x115) cho thấy 3 XL dùng **Samsung S6SY761** ("sec,sec_ts" @0x48,
  qupv3_se2_i2c 400 kHz, irq GPIO125, reset GPIO99 output-high, switch GPIO136, dvdd L14, avdd L19, 1440x2960)
  — KHÁC Pixel 3 (STM FTS5 @0x49 trong sdm845-next). Patch `kernel/patches/0002-…` (driver mainline s6sy761 +
  gpio-hog 136/99 high — mức 136 theo patch blueline của sdm845-next: GPIOD_OUT_HIGH = bus về AP).
  Kết quả: `input: s6sy761 … 2-0048/input/input3` (cảnh báo "the axis have not been set" vô hại),
  10 điểm chạm X 273..1314, Y 137..1767; **người dùng đăng nhập GNOME bằng cảm ứng trên máy** ✔.
- **Sạc**: `pmi8998-charger: online=1 status=Charging type=USB` ✔ (máy CÓ sạc khi cắm USB Mac).
- AppArmor enabled (129 profile), snapd active.
- Người dùng "đồng ý" → flash boot_b kernel #6 (sha256 7e616623…aa4c7) → boot OK: running, s6sy761, Charging.
- Lưu hotspot iPhone (SSID NghiaND) vào NM: con-name iPhone-NghiaND, autoconnect-priority -10 (VN2007 = 10), metered=yes,
  route-metric 700. File chỉ root đọc (600). Mật khẩu KHÔNG ghi ở đây.
- **Reset lại (boot -1 dừng ~302s, + 1 lần nữa) sau khi người dùng đăng nhập GNOME tại máy**: phiên user có
  idle-delay=60 (cấu hình user ghi đè mặc định hệ thống). Sửa: dconf `local.d` + **locks** (idle-delay=0,
  sleep-inactive-*=nothing, idle-dim=false, power-button-action=nothing, lock-enabled=false) → `gsettings writable` = false.
  GDM greeter cũng power-button-action=nothing. (update-notifier-download ~300s đã loại trừ.)
- **Reset `bootreason=watchdog`** (đọc `androidboot.bootreason` trong cmdline lần boot sau): 3 lần reset gần nhất đều là
  watchdog (treo cứng, không kịp log). Lần mới nhất: pixel-powerkey khoá phiên → người dùng ở màn khoá, bàn phím ảo
  không có phím số ("Need keyval or commitString"), ngừng thao tác → gsd-power tắt màn hình sau ~30 s khi phiên khoá
  (bỏ qua idle-delay) → treo → watchdog. Sửa: bỏ `lock-session` khỏi pixel-powerkey (người dùng muốn bỏ khoá),
  dconf `lockdown/disable-lock-screen=true` + `ubuntu-lock-on-suspend=false` (khoá). Đưa vào 91-xrdp.sh + docs.
- GDM autologin user ubuntu (/etc/gdm3/custom.conf, bản gốc .orig) — người dùng yêu cầu; hiệu lực từ boot sau. Thêm vào 91-xrdp.sh.
  Lưu ý: sudo của ubuntu đang NOPASSWD (90-ubuntu, cho tự động hoá qua SSH).
- RUNBOOK §6: tổng hợp sự cố khởi động lại/reset (chẩn đoán bằng bootreason, dòng thời gian, gốc rễ DPMS, quy tắc) — theo yêu cầu người dùng.

### Kernel #7 (2026-11-13): % pin — boot thử trong RAM
- Patch `0003` (MAX1720x @i2c12 0x36/0x0b, IRQ GPIO62 pull-up) + `BATTERY_MAX1720X=m` (+ bật sẵn `SND_SOC_CS35L36`,
  `VIDEO_IMX355` cho bước sau). Build 16.5 phút (đã dừng driver-map đang tranh I/O; 96-hw-facts.sh sửa thành 1 lượt git grep).
- Kết quả: `/sys/class/power_supply/max1720x` type=Battery, **capacity=99**, voltage 4.305 V, temp 30.7 °C,
  charge_full_design 3456 mAh (chip), **charge_full 2943 mAh (~85 % — pin chai ~15 %)**; UPower `battery_max1720x`
  99 % fully-charged ✔. `health=Dead` — nghi driver đọc sai (số đo khác hợp lý), chưa tìm hiểu.
- Tự đăng nhập GDM có hiệu lực (phiên seat0 tự mở) ✔.
- Nghiên cứu cho bước sau (từ archive/stock): loa = 2× CS35L36 trên **QUAT TDM** (12.288 MHz), VA = pm8998_s4,
  amp#2 @0x41 reset GPIO75 irq GPIO40; trở kháng hiệu chuẩn top 0x2bb5 / bottom 0x2526.
  Camera trước (cam-sensor@1): MCLK1 GPIO15, reset GPIO21, VANA-en GPIO8, cci-master 1, csiphy 2;
  nguồn vio=pm8998_lvs1, vana=pmi8998_bob, vdig=pm8998_s3 (KHÔNG cần s2mpb04).
- Người dùng "đồng ý" → flash boot_b kernel #7 (sha256 cb1c9f32…3eca) → boot OK (bootreason=reboot), pin 99 %, autologin.

### Âm thanh (2026-11-13 tối) — ĐANG LÀM, chỉ boot trong RAM (boot_b vẫn là #7 không có audio DT)
- Patch `0004`: 2× CS35L36 (@0x40 "Right"/bottom reset GPIO112 irq GPIO115; @0x41 "Left"/top reset GPIO75 irq GPIO40;
  VA=vreg_s4a_1p8, VP=vph_pwr; boost 1000 nH/10 V/3.7 A), q6afedai `QUATERNARY_TDM_RX_0` (sync-mode 0, src 1,
  data-out 0, invert 0, delay 1, align 0), q6asmdai MM1, `&sound` qcom,sdm845-sndcard "Pixel 3 XL".
  `sdm845.c` mainline đã hỗ trợ QUAT TDM + CS35L36 Left/Right (TDM slot, sysclk 6.144 MHz "codecs like cs35l36").
- Amps probe OK: "Cirrus Logic CS35L36, Revision: B0" ×2. Card "Pixel 3 XL" + "Headset Jack".
- **Sự cố: GNOME/Settings đứng hình** → BÃO NGẮT: irq GPIO115/40 = 100001 lần, "irq 194: nobody cared".
  Nguyên nhân: thiếu `bias-pull-up` trên chân IRQ (open-drain) — stock có. Sửa: pinctrl spkr_{right,left}_default
  (irq pull-up, reset bias-disable) → 0 ngắt ✔. (Máy KHÔNG reboot; kernel tự tắt IRQ.)
- `snd-soc-sdm845` trong modules-load.d → "Invalid argument" (nạp quá sớm) → bỏ; udev tự nạp được.
- journald.conf.d: chú thích cùng dòng `ForwardToConsole=no  # ...` → "Failed to parse boolean" → tách dòng.
- Phát thử (amixer: QUAT_TDM_RX_0 Audio Mixer MultiMedia1 on; Left/Right Channel Mux RX1, AMP/BOOST on,
  Digital PCM Volume 624 = −24 dB (thang 0..912 = −102..+12 dB, 816 = 0 dB)):
  - buffer mặc định 130560 frame → "q6asm DSP returned error[1] / Memory_map_regions failed" (DSP không map nổi ~520 KB);
  - buffer 20000 → map OK nhưng ghi "Input/output error", PCM `closed` sau ~2 s. CHƯA có tiếng.
  - Kernel không bật DYNAMIC_DEBUG → không thấy lý do. Bước sau: bật dyndbg, thử TDM long-sync/invert (stock base
    dtb quat-rx: sync-mode 1, invert-sync 1, clk 1.536 MHz; overlay C1: sync-mode 0, invert 0, clk 12.288 MHz).
- Nút âm lượng: Vol+ = gpio-keys KEY_VOLUMEUP, Vol− = PM8998 RESIN KEY_VOLUMEDOWN → GNOME tự map khi có sink âm thanh.

### 2026-11-13 ~23:10–23:45 — PipeWire + sự cố slot A/B
- WirePlumber 0.4 + ACP: profile về "off", sink không thành mặc định ("no target node available"). Sửa: `51-pixel3-audio.lua` đặt
  `api.alsa.use-acp=false` cho `alsa_card.platform-sound` → node `alsa_output.platform-sound.playback.0.0` S16LE, mặc định (*).
- pw-play vẫn treo: `/proc/asound/card0/pcm0p/sub0/status` RUNNING nhưng `hw_ptr` đứng ở 1 period. `aplay` (cả `-M`) chạy tốt.
  Gốc: `q6asm_dai_prepare()` khi prepare lại (PipeWire làm mỗi lần suspend/resume node) đóng/mở lại stream DSP nhưng KHÔNG reset
  `prtd->queue_ptr` (appl_ptr về 0 → `q6asm_dai_ack` tính số period âm, không đẩy buffer), cũng không reset `dsp_buf`/`hw_ptr` (chỉ FLUSH mới reset).
  → patch `kernel/patches/0005-ASoC-qcom-q6asm-reset-playback-queue-state-on-re-prepare.patch` (chỉ module q6asm, q6asm-dai).
- Build riêng module: `make O=/work/kernel/build <file>.ko` lỗi modpost; `M=` không ghi ra build dir; dùng `make modules` tăng dần (~3 phút).
- Nạp nóng (rmmod/insmod q6asm) KHÔNG được: APR "service is not registered (7)", CMD 10d92 timeout → phải boot lại.
- Deploy: `systemctl reboot -ff` qua SSH làm lệnh ssh treo (đã thêm ServerAlive vào 80-deploy-kernel.sh).
- `fastboot boot` quay về fastboot sau ~8 s; `fastboot reboot` → "Cannot load Android system" (recovery slot a).
  `fastboot getvar all`: `slot-unbootable:b:yes`, `slot-retry-count:b:0`, `slot-successful:b:no`, current-slot a.
  Gốc: Ubuntu chưa từng đánh dấu slot thành công → hết 3 lượt thử → ABL về Android. `fastboot --set-active=b` → retry 3, unbootable no.
  RAM-boot lại OK (net sau 15 s). Lưu ý cmdline khi `fastboot boot`: `androidboot.slot_suffix=_a`.
- Kết quả với patch 0005: `pw-play complete.oga` rc=0, ~1.3 s (trước: treo tới timeout).
- Cài `qbootctl` 0.1.2 (Ubuntu noble). `sudo qbootctl`: _a Active0/Successful1, _b Active1/Successful0/Bootable1. Chưa ghi (chờ đồng ý).
- 50-rootfs.sh thêm gói + enable qbootctl. RUNBOOK §6.2 #6 + §6.5.

### 2026-11-13 ~23:40–00:00 — pin, camera/micro (tạm dừng), dùng độc lập
- `health=Dead`: bug driver `max1720x` (dùng `regmap_set_bits` để "xoá" cờ cảnh báo → bật luôn VMN/VMX/TMN/TMX, Status 0x3380).
  Patch 0006 (`regmap_clear_bits`), nạp nóng module → `Good`, Status 0x0080. Module đã chép vào out/kernel/modules + máy.
- Camera trước + micro: patch 0007 (DT IMX355 CCI1/CSIPHY2; WCD9340 SLIMbus + SLIM Capture → MultiMedia2), thêm `SLIM_QCOM_NGD_CTRL` + nhóm CAMSS/WCD
  vào pixel3.config; build #9 chạy nền — **CHƯA thử, chưa flash**. libcamera v0.8.0 (`scripts/56-libcamera.sh`): auto-mode chặn
  "code from external" — người dùng cần tự chạy. Người dùng bảo tạm dừng camera.
- Còn thiếu cho micro: `audio-routing` DMIC0/3/4 ← MIC BIAS1/3/4 trong &sound, mixer (AIF1_CAP Mixer SLIM TX0, SLIM TX0 MUX=DEC0, ADC MUX0=DMIC, DMIC MUX0=DMIC0, MultiMedia2 Mixer SLIMBUS_0_TX).
- UPower `CriticalPowerAction=PowerOff` (thay HybridSleep).
- Build #9 xong (~4 phút, chỉ DT + module mới). **`out/kernel/` giờ là #9 CHƯA THỬ** (camera/micro DT); `out/boot/boot-install.img` vẫn là #8 đang flash.
  Đừng chạy `80-deploy-kernel.sh` (đẩy module #9) trước khi tạo boot.img #9 và thử bằng `fastboot boot`.

### 2026-11-13 ~23:50 — đo điện năng khi chạy pin (max1720x current_now, mẫu 0.5 s, kernel #8)
- Lần 1: A màn sáng (độ sáng 10) 315 mA/1.33 W; B tắt màn hình mềm 70 mA; C (B + offline cpu4-7 + nhân nhỏ ≤1056 MHz) 5 mA — **không tin được** (min âm, lệch thứ tự).
- Lần 2 (60 s mỗi mục): B1 175 mA/746 mW; C 161 mA/685 mW; B2 163 mA/695 mW → tắt nhân lớn chỉ tiết kiệm ~5% (CPU đã 99% idle, psci_idle 3 mức).
- Sàn ~130 mA khi màn tối: phần cứng (panel vẫn quét 60 Hz ở độ sáng 0 + MDSS/DSI, modem cho Wi-Fi, …). Chỉ suspend/tắt panel thật mới giảm mạnh — bị chặn bởi lỗi bật lại panel.
- Ước lượng (charge_full 3093 mAh): màn sáng thấp ~10 h; tắt màn hình mềm ~18–19 h. KHÔNG thêm "ngủ nhẹ" CPU (lợi ích không đáng).

### 2026-11-14 — Termius (iPhone) qua Tailscale
- iPhone (tailnet 100.67.254.13) tới được sshd; lỗi "Too many authentication failures" vì Termius chỉ có public key. Server đã có sẵn cả 3 public key của Mac.
- Người dùng import private key ed25519 của Mac vào Termius → vào được. (Khuyến nghị dài hạn: khoá riêng cho iPhone.)

### 2026-11-14 ~00:10–00:25 — giới hạn sạc + sự cố fwupd mount modem_b
- qcom_smbx chỉ có `status` (ghi = suspend USBIN → chạy pin) và `current_max`. Patch 0008: `charge_behaviour` auto/inhibit-charge qua `CHARGING_ENABLE_CMD` (0x42 bit0).
  Build module (~3 phút), nạp nóng (máy đang chạy pin). `pixel-charge-limit.service` (75–80%).
- Kiểm chứng cắm USB Mac: inhibit → pin 0 mA, Not charging; auto → ~440 mA Charging; trả về inhibit. `pmi8998-charger current_now/voltage_now` = 0 (IIO chưa chạy).
- dmesg: `FAT-fs (sda14): Volume was not properly unmounted` — `udisksd` mount `/dev/sda14` = **modem_b** "on behalf of uid 0" lúc fwupd-refresh khởi động fwupd (dò ESP), unmount ngay.
  Xử lý: mask fwupd(+refresh timer), `80-pixel-udisks-ignore.rules` (UDISKS_IGNORE mọi sd* trừ userdata). Kiểm: sda14 UDISKS_IGNORE=1, sda21 không.
- 50-rootfs.sh enable pixel-charge-limit; 91-xrdp.sh mask fwupd. Module qcom_smbx.ko chép vào out/kernel (bản #9).

### 2026-11-14 — tháo SSD
- Chép boot-install.img #8 (đang ở boot_b) + 4 module thay nóng vào `archive/20261113/kernel/running-20261114/`. `hdiutil detach /Volumes/pixelwork`, `diskutil eject /Volumes/LIB`. Lần sau: cắm SSD rồi `scripts/00-workspace.sh`.

### 2026-11-14 — sạc nhanh, micro, camera (kernel #10 + DTB 0011, chỉ fastboot boot)
- Sạc: mainline qcom_smbx khoá FCC 1 A ("fire hazard") + ICL theo BC1.2 (SDP 0.5/CDP,DCP 1.5 A); không có Type-C/PD cho PMI8998
  (mainline chỉ pm8150b/pmi632). Patch 0009: ICL theo Rp (TYPE_C_STATUS_1: 0x40=1.5 A, 0x20=3 A), `constant_charge_current` ghi được
  (trần = battery constant-charge-current-max, DT 0010 = 3 A, khởi động 1 A). pixel-charge-limit.sh áp bảng google,chg-cc-limits
  (temp 0/10/20/42/46/48/55 °C × CV 4.2/4.3/4.4 V, % của 3430 mAh). Cổng Mac: Type-C 0x40 → ICL 1.5 A, FCC 3 A, nạp ~1.15 A. CHƯA thử với cục PD.
- Micro: WCD9340 nhận (chip id 0x108), SLIMbus NGD chạy, card có pcm2c (MultiMedia2). Mixer = UCM Ubuntu (AIF1_CAP Mixer SLIM TX0,
  CDC_IF TX0 MUX=DEC0, ADC MUX0, DMIC MUX0/AMIC MUX0, MultiMedia2 Mixer SLIMBUS_0_TX). Ghi được nhưng **toàn 0** với mọi DMIC0-5 và ADC1-4.
  Tìm ra: MCLK (ln_bb_clk2) không bật khi thu — supply "MCLK" chỉ nối qua route → 0011 thêm "AIF1 CAP","MCLK" → clk count 1, vẫn 0.
  Codec regs lúc thu: MCLK_CFG 9.6 MHz, MCLK_CONTROL 1, FS_CNT 0x0d, ROUTER_TX_MUX 0x02 (DEC0), DMIC0_CTL 0x05, TX0_PATH_CTL 0x24; ifd TX_PORT_CFG(0)=0x05.
  Chưa rõ: dữ liệu SLIM ch128 có tới AFE không (không có ftrace trong kernel). Cảnh báo `wcd934x_enable_efuse_sensing` lúc probe (vô hại?).
- Camera: probe imx355 @0x1a (gpio21) = -ENXIO. 0011 khai báo cả 2 cảm biến: **camera gpio21/CSIPHY2 trả lời ở 0x10** (imx355 bind 17-0010);
  node 0x1a (gpio9/gpio14, CSIPHY1) lỗi pinctrl vì 2 node cùng xin gpio15 (MCLK2) → camss chưa tạo subdev. Cần: bỏ node thứ 2 hoặc dời pinctrl MCLK.
- Trạng thái máy: RAM-boot #10 + DTB 0011; boot_b vẫn #8; /lib/modules = bản #10 (bản #8 lưu ở 7.4.0-rc2-pixel3+.bak-k8).
- Người dùng chọn (c) + "đồng ý": flash boot_b = boot-install.img #10+DTB0011 (sha bcedf902…). fastboot reboot → slot_suffix _b, qbootctl Successful 1,
  system running, loa OK (pw-play rc 0), Tailscale OK, nạp ~1.1–1.2 A từ Mac (ICL 1.5 A, FCC 3 A). Image lưu archive/20261113/kernel/running-20261114-k10/.

### 2026-11-14 — USB PD 9 V (driver mới, chỉ fastboot boot)
- Mainline không có Type-C cho PMI8998 (Type-C nằm trong USBIN 0x1300 của SMB2); PD PHY 0x1700 cùng IP với PM8150B (stock qcom,qpnp-pdphy, 7 irq, vdd L24).
- Patch 0012: backend port `qcom_pmic_typec_port_smb2.c` (sink): get_cc từ TYPE_C_STATUS_1/4 (Rp + orientation), get_vbus STATUS_4 bit6,
  set_polarity = VCONN_EN_ORIENTATION + TYPEC_SPARE_CFG (như vendor khi pd_active), EXIT_SNK_BASED_ON_CC (hard reset), set_current_limit → ICL +
  ADAPTER_ALLOW 5V_TO_9V; irq type-c-change (USBIN irq 7, không trùng qcom_smbx). Glue qcom_pmic_typec.c: compatible "qcom,pmi8998-typec".
  Thanh ghi lấy từ vendor smb-reg.h/smb-lib.c (LineageOS android_kernel_google_msm-4.9, chỉ đọc tham khảo).
- Patch 0013 (DT): typec@1300 reg <0x1300>,<0x1700>, sink-pdos 5V/3A + 9V/2A. 0014: qcom_smbx bỏ qua đặt ICL theo Rp khi USBIN > 6 V
  (work 1.5 s sau cắm từng ghi đè 3 A lên hợp đồng 9V/2A).
- Thử với cổng Mac: PD 3.0, Mac chỉ chào PDO 5V/3A → SNK_READY, ICL 3 A.
- Thử với cục PD: chào 5/9/12/15V 3A, 20V 5A, PPS → "Requesting PDO 1: 9000 mV, 2000 mA" → PS_RDY → SNK_READY. USBIN đo 8.98 V.
  Dòng nạp ~1.0–1.25 A vì pin 74–78% đang TAPER (BATTERY_CHARGER_STATUS_1 0x1006=0x04), không phải giới hạn PD. pmi8998-charger current_now/voltage_now
  chạy (rradc) khi đang sạc.
- Lưu ý: depmod phải chạy sau khi thay module (alias mới không tự nạp).
- "đồng ý" → flash boot_b f4edbb1b… (Image #10 + DTB 0013). Boot OK, slot _b Successful, PD 3.0 với Mac tự lên lúc boot.
  `systemd-backlight@backlight:ae94000.dsi.0` failed 1 lần (chạy sớm khi panel chưa sẵn sàng) → restart OK → system running. Theo dõi.

### 2026-11-15 — kiểm tra máy chạy server game 24/7
- Nhiệt: SoC 37–38 °C, pin 29.6 °C (ngừng nạp), lúc nạp pin tới ~42 °C (bảng Google tự giảm dòng). CPU không bị hạ xung. Load ~0.4, RAM khả dụng 1.7 GB, không swap, kswapd chạy.
- PD 9V/2A ổn định suốt boot hiện tại (2h40). Pin 80% inhibit, USB cấp điện.
- 🔴 2 lần chết vì cạn pin (boot -2 kết thúc 14/11 20:03, boot -1 kết thúc 15/11 06:58, ngay sau "Running on LOW Battery"; không có chuỗi tắt máy);
  log hệ thống mất vì journal chạm 200M (nhiều log sshd do Mac deploy qua SSH). Nguyên nhân chưa xác định.
- Người dùng đồng ý (1) logger điện năng + (2) journal 1G: pixel-power-log.timer (2 phút) → /var/log/pixel-power.csv + /var/log/pixel-tcpm.log; SystemMaxUse=1G.
  Lần đầu bị auto-mode chặn (đổi máy đang chạy server khi người dùng chỉ hỏi kiểm tra) → hỏi lại → đồng ý. zram, giảm SSH: không làm.

### 2026-11-15 — Chrome không hiện bàn phím ảo
- google-chrome-stable 157 (arm64), phiên GNOME Wayland. GNOME chỉ hiện OSK khi app dùng text-input-v3; Chrome mặc định không.
- `scripts/97-chrome-osk.sh`: ghi đè ~/.local/share/applications/{google-chrome,com.google.Chrome}.desktop thêm
  `--ozone-platform=wayland --enable-wayland-ime --wayland-text-input-version=3` (undo: `scripts/97-chrome-osk.sh <host> undo`). Cần thoát hẳn Chrome rồi mở lại.
- Sau khi mở lại: Chrome chạy đúng `--ozone-platform=wayland ... text-input-version=3` nhưng OSK vẫn không hiện. Touchscreen được udev nhận đúng (ID_INPUT_TOUCHSCREEN=1, INPUT_PROP_DIRECT).
  Bật gsettings (97-chrome-osk.sh): a11y screen-keyboard-enabled=true, a11y mouse secondary-click-enabled=true (0.8 s). Chờ người dùng thử.
  Lưu ý: secondary-click của GNOME áp cho sự kiện con trỏ; app Wayland nhận cảm ứng gốc tự xử lý đè lâu (Chrome có sẵn trên trang web).

### 2026-11-15 — tai thỏ (notch)
- Panel 1440x2960 (DSI-1), scale 2. GNOME 46 không hỗ trợ display cutout. Cắt ở driver panel = đổi mode/tắt-bật panel → nguy cơ treo (RUNBOOK §6) → không làm.
- Viết extension riêng `rootfs/gnome-extensions/pixel-notch@pixel3xl` (chrome đen affectsStruts + dời panelBox xuống; chỉ khi màn chính là 1440x2960 vật lý;
  độ cao px vật lý trong ~/.config/pixel-notch-px, mặc định 172 — ƯỚC LƯỢNG, chưa có số đo chuẩn). Cài: `scripts/98-gnome-notch.sh [host] [px]`, gỡ: `... undo`.
- Đã chép + thêm vào enabled-extensions; GNOME Wayland chỉ nạp extension mới sau khi phiên khởi động lại (chưa làm — chờ người dùng đăng xuất/vào lại).
- Kết quả thử: zenity (GTK) hiện OSK, Chrome không. Mutter 46 text_input_commit_state: enable lần 1 chỉ focus_in, lần 2 (đã focus) mới
  set_input_panel_state(ON); GTK gửi lại enable khi chạm, Chrome chỉ 1 lần. Notch v1 không ăn: ở scale nguyên Monitor là px vật lý
  nhưng geometry_scale=2 → điều kiện 1440x2960 sai → h=0.
- Extension đổi tên `pixel3xl-shell@pixel3xl` (v2): notch theo tỉ lệ khung + mở OSK khi `Main.inputMethod` `cursor-location-changed`
  có currentFocus mà OSK ẩn. Script `scripts/98-gnome-shell-ext.sh` (thay 98-gnome-notch.sh, tự gỡ bản cũ). Cần đăng nhập lại.
- Giữ lâu = chuột phải mọi app: kernel thiếu CONFIG_INPUT_UINPUT → chưa làm.
- Tài liệu mới: docs/software/touch-ui.md (thao tác nhanh, cơ chế, bẫy); mục lục docs/README.md, RUNBOOK §2, rootfs-services trỏ tới.
- Người dùng: tai thỏ đẹp, OSK Chrome hiện ✅. Lỗi mới: cửa sổ Chrome phóng to bị dải đen/thanh trên che, không chạm được.
  Gốc: _updateRegions chỉ tính strut khi actor chạm mép màn hình; panelBox dời xuống mất strut; dải đen reactive chặn chạm.
  v3: strut vô hình (reactive false) phủ notch+panelBox.height, dải đen không nhận chạm. Đã cài, chờ đăng nhập lại.
- Giữ lâu trên icon desktop không ăn (dock thì có): icon do DING (app GTK3 riêng) chỉ nhận nút chuột 3. Viết bộ vá
  /usr/local/sbin/pixel-ding-longpress (overlay) + hook apt + scripts/99-ding-longpress.sh: hẹn giờ 600 ms với sự kiện TOUCHSCREEN, mở menu khi
  nhấc tay; vá 3 file DING (check → vá → pkill ding.js, extension tự chạy lại). DING chạy lại không lỗi. Chờ người dùng thử.
- Rà riêng tư trước khi công khai: patch 0005–0014 có Signed-off-by mang email cá nhân (do `git commit -s` dùng git config của cây kernel)
  → thay bằng `pixel3 port <pixel3@localhost>`, 30-kernel.sh đặt cứng identity này. Script 97/98/99 dùng $PIXEL_HOST (mặc định USB).
  IP Tailscale/SSID trong docs → placeholder. NOTES.md vẫn còn (nhật ký cá nhân) → checklist công khai.
- README.md cấp repo mới (badge, bảng phần cứng, sơ đồ mermaid, bắt đầu nhanh, patch, bài học, an toàn, ghi công, giấy phép) + docs/PUBLISHING.md
  (checklist công khai: NOTES.md còn SSID/IP, archive/device, firmware, lịch sử git có email ở commit đầu, chọn LICENSE). Chưa commit (người dùng chưa yêu cầu).
- "đổi 90": /etc/default/pixel-charge-limit STOP=90 START=85 (overlay + máy), restart dịch vụ → auto, nạp ~1.16 A từ 80 %. Description dịch vụ bỏ "75-80%".
  Pin: charge_full 3135 / design 3456 mAh (~91 %). Nhắc: Battery Defender Google (≥4.27 V + ≥35 °C 6 h) → nếu hay nóng nên về 80/75.
- Defender (yêu cầu người dùng): pixel-charge-limit.sh thêm DEFEND_* (35 °C liên tục 60 phút ở ≥80 % → giữ 75–80, ngắt USBIN bằng status=Unknown
  để xả về 80; thoát khi ≤32 °C 30 phút hoặc rút sạc). Thử ngắt/cấp lại tay 10 s OK (xả 175 mA, usb0 vẫn lên). Unit thêm ExecStopPost cấp lại nguồn.
  Thử ngưỡng 30 °C/1 phút: bật → ngắt → xả 146 mA → trả cấu hình → nạp lại. Tài liệu: power-battery.md §Defender.
- Bluetooth: kernel OK (crbtfw21/crnv21, setup completed) nhưng bluetoothctl "No default controller": btmgmt config = Unconfigured, missing public-address
  (ABL không truyền địa chỉ). pixel-bt-addr.service gán địa chỉ ổn định sha256(serial) (locally administered). Bẫy btmgmt: </dev/null thoát trước phản hồi,
  không stdin thì treo (systemctl start treo) → `sleep 2 | timeout 5 btmgmt`. Kiểm chứng bằng rmmod/modprobe hci_uart. Quét thấy thiết bị (RSSI -59…-100).
- DING: người dùng báo chưa ăn → log tạm PIXELDBG: chạm = nút 1 từ "Wayland Touch" (src 5 = TOUCHSCREEN), release lp=true → bản vá đúng;
  lần trước nhiều khả năng giữ chưa đủ 0.6 s. Người dùng xác nhận chuột phải OK. Gỡ log (khôi phục bản vá), sửa pkill tự giết SSH ([d]ing) trong script 99.
- README viết lại bằng tiếng Anh, văn phong chuyên nghiệp, bỏ emoji; docs/ giữ tiếng Việt (song ngữ thuật ngữ) theo người dùng.
- Kiểm tra bền vững sau reboot (chưa reboot thật): kernel #10/DTB 0013 ở boot_b, alias module PD, các dịch vụ enabled+active (qbootctl, charge-limit,
  power-log, bt-addr, sound, powerkey, bluetooth), fwupd masked, cấu hình sạc 90/85+Defender, UPower PowerOff, journald 1G, udev, hook DING, DING 3/3,
  Chrome .desktop, gsettings OSK/secondary-click, extension v3 đang chạy (strut 236), slot b Successful, GDM autologin.

### 2026-11-15 — kiểm tra sau khi người dùng khởi động lại máy
- system running, không unit lỗi (systemd-backlight lần này OK). Giữ đủ: kernel #10/DTB 0013, PD (usb_power_delivery, ICL 3 A), sạc 90/85 + Defender,
  power-log, Wi-Fi, Tailscale, 4 container server game healthy ("Up 56 years" = do RTC 1970 trước NTP, chỉ hiển thị), loa mặc định, DING, extension v3, slot b Successful.
- 🔴 Bluetooth không lên: race — pixel-bt-addr chạy 5.5 s khi hci0 có trong sysfs nhưng QCA setup xong 6.3 s → mgmt chưa liệt kê → "bỏ qua".
  Sửa: lặp tới khi Unconfigured (gán) hoặc có trong btmgmt info (bỏ qua), tối đa 60 s. Tái hiện race bằng rmmod/modprobe + restart ngay → OK, Powered yes.

### 2026-11-15 — gửi file Bluetooth "not sent"
- Ghép đôi với Legion Tab Y700 OK nhưng gửi file báo "not sent". bluez-obexd có nhưng obexd không chạy (D-Bus activation), GNOME 46 không có
  agent nhận file. Viết `pixel-obex-agent` (user service, chỉ nhận từ thiết bị đã ghép đôi, lưu ~/Downloads/Bluetooth, notify) + drop-in
  obex.service `-r Downloads/Bluetooth`. Agent đăng ký OK nhưng bluetoothd: "RFCOMM server failed for Object Push: socket(STREAM, RFCOMM):
  Protocol not supported" → **kernel thiếu CONFIG_BT_RFCOMM** (cũng thiếu BT_BNEP, BT_LE). Thêm vào pixel3.config (+ need_m).
  Kế hoạch: build lại (đổi config → ~25–35 phút), thay nóng toàn bộ module Bluetooth (BT toàn module, lõi kernel không đổi) — không flash.
  SSD workspace chưa cắm → chờ.
- OSK thiếu Esc trong terminal: layout terminal = `us-extended` (Tab/Ctrl/Alt/mũi tên, KHÔNG Esc). Script 97 sinh bản thay phím emoji→Esc vào
  ~/.local/share/pixel-osk-layouts + environment.d G_RESOURCE_OVERLAYS=/org/gnome/shell/osk-layouts=… (cần đăng nhập lại). Tài liệu touch-ui.md.
- Esc chưa hiện sau đăng nhập lại: gnome-shell không có G_RESOURCE_OVERLAYS vì systemd --user (giữ sống bởi SSH) chưa đọc environment.d → daemon-reload; script 97 tự reload. Cần đăng nhập lại lần nữa.
- Tối nay làm tiếp: cắm SSD rồi `scripts/00-workspace.sh` báo "hdiutil: attach failed - no mountable file systems" (chưa điều tra: /Volumes/LIB có mount
  chưa? sparsebundle còn nguyên?). Sau đó: `scripts/30-kernel.sh build` (RFCOMM/BNEP/LE) → thay nóng module Bluetooth → thử nhận file OBEX.

### 2026-11-18
- Tư vấn pin server 24/7: inhibit giữ pin đứng yên → STOP quyết định tuổi thọ; START thấp (30 %) chỉ mất dự phòng sau mất điện. Người dùng chọn **60/55**
  (overlay + máy qua Tailscale). Pin đang 90 % → giữ yên (không tự xả). power-battery.md có bảng chọn.
- Máy cắm nguồn PD nhưng Mac không thấy USB (UDC not attached, usb0 DOWN) → nhiều khả năng cắm cục sạc/dây chỉ sạc; làm qua Tailscale.
- SSD mount OK lần này. Build #11 (BT_RFCOMM/BNEP/LE) chạy nền.
- USB không lên dù tráo cáp: UDC "not attached", dmesg "dwc3 a600000.usb: failed to enable ep0out"; soft_connect/gắn lại UDC không ăn.
  Rebind driver dwc3-qcom-legacy (a6f8800.usb) → configured high-speed; Mac en6 chỉ 169.254 vì dnsmasq NM "Address already in use" → nmcli con down/up usb0 → OK.
  IPv6 link-local fe80::ff:fe3a:2%en6 SSH được trong lúc đó. Gói thành /usr/local/sbin/pixel-usb-reset (overlay) + RUNBOOK §4 + storage-usb.md.
- Build #11 OK (~3 phút; lần đầu lỗi vì Docker Desktop chưa bật). Chép module BT ra scratchpad trước khi tháo SSD (Docker VM giữ ổ → quit Docker).
- Thay nóng module BT: lần 1 `rmmod bluetooth` thất bại (bnep tự nạp, stop bluetooth bị "canceled") → bluetooth.ko CŨ + rfcomm/bnep/hci_uart MỚI (srcversion lệch).
  Sửa: mask --runtime bluetooth → stop → modprobe -r toàn bộ → modprobe hci_uart → unmask → bt-addr → bluetooth → obex agent. Tất cả srcversion khớp,
  Powered yes, UUID OBEX Object Push + File Transfer có. Chờ người dùng gửi thử file. Tài liệu connectivity.md (OBEX + quy trình thay nóng).
