# Bản lưu trữ phụ thuộc (`archive/<YYYYMMDD>/`)

Mục đích: dựng lại / sửa dự án kể cả khi nguồn bên ngoài đổi hoặc biến mất (Google gỡ factory image, lore/gitlab
không truy cập được, gói Ubuntu đổi phiên bản, upstream force-push…). Tạo bằng `scripts/95-archive.sh`
(`ONLY=device` để chỉ sao lưu lại cấu hình điện thoại). File lớn bị `.gitignore`; **zip cả thư mục repo** để cất.

Kiểm tra toàn vẹn: `cd archive/20261113 && shasum -a 256 -c MANIFEST.sha256`

| Thư mục | Nội dung | Dùng khi |
|---|---|---|
| `repo/` | snapshot repo (scripts, docs, overlay, patches) — không gồm `archive/` | khôi phục repo |
| `kernel/linux-pixel3-<sha>.tar.xz` | **toàn bộ source kernel đã vá** (v7.4-rc2 + panel v3 + patch riêng) | build lại không cần mạng |
| `kernel/patches/`, `commits.txt`, `BASE.txt` | `git format-patch v7.4-rc2..pixel3` | rebase lên kernel mới |
| `kernel/panel/`, `kernel/pixel3-v7/` | mbox + cover letter từ b4 (series panel v3, Pixel 3 v7 — có mục "Booting") | lore không vào được |
| `kernel/config-*` | `.config` đã build | |
| `kernel/build-output/` | Image.gz, dtb (+ `.dts` giải mã), `modules.tar.xz`, **`boot-install.img`, `boot-smoke.img`**, initramfs | flash lại ngay không cần build |
| `stock/*-factory-*.zip` | **factory image Google 12.0.0 (SP1A.210812.016.C2)** + SHA-256 | **khôi phục Android**, trích lại firmware |
| `stock/stock-base-dtb*.dtb(.dts)`, `stock-dtbo*-id*.dtbo(.dts)`, `dtbo-index.txt` | DT gốc Google đã giải mã (14 overlay) | tra số liệu phần cứng (GPIO, nguồn, địa chỉ) |
| `sources/linux-msm-{tqftpserv,rmtfs,qrtr,pd-mapper}.bundle` | git bundle đầy đủ lịch sử | `git clone x.bundle` |
| `sources/aosp-{mkbootimg,avb}-android-15.0.0_r1.tar.gz` | mkbootimg/avbtool đã ghim | dựng image Docker |
| `sources/sdm845-next-branch-sdm845-next.tar.gz` + `sdm845-next-commits.txt` | tree cộng đồng SDM845 (fuel gauge, audio qdsp6, camera, touchscreen blueline) | làm pin/loa/camera |
| `debs/` | .deb noble arm64: rmtfs, qrtr-tools, libqrtr1, tqftpserv, protection-domain-mapper, xrdp, xorgxrdp, iptables, nftables, mkbootimg… + `tailscale_*_arm64.tgz` | cài offline |
| `firmware/firmware.tar.gz`, `SHA256SUMS-*` | firmware đang dùng (riêng máy + linux-firmware) | |
| `docker/pixel-build-noble.tar.gz` | image build (`docker load < …`) | môi trường build y hệt |
| `device/` (**700, BÍ MẬT**) | `/etc`, `/usr/local`, `/home/ubuntu` của máy (netplan có mật khẩu Wi-Fi, SSH host key, xrdp key), danh sách gói, trạng thái runtime | khôi phục cấu hình sau khi flash lại |

Không lưu: cây kernel git đầy đủ (4 GB, thay bằng tarball), thư mục build kernel, `rootfs.img` cũ (đã khác máy thật — dùng
`device/` + `50-rootfs.sh`), trạng thái Tailscale (đăng nhập lại).
