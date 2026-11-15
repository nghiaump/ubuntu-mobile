# Checklist trước khi công khai repo

Repo được viết để có thể chia sẻ, nhưng có vài thứ **mang tính cá nhân** cần xử lý trước khi đẩy lên GitHub/GitLab công khai.

## Bắt buộc
- [ ] **`NOTES.md`**: nhật ký cá nhân, còn tên Wi-Fi/hotspot và IP Tailscale (`grep -n -E '100\.[0-9]+\.[0-9]+\.[0-9]+|SSID' NOTES.md`).
      Chọn: thay bằng placeholder, hoặc không đưa NOTES.md lên (thêm vào `.gitignore`), hoặc tách bản đã làm sạch.
- [ ] **`archive/`**: chỉ commit phần nhỏ đã được `.gitignore` cho phép; **`archive/**/device/`** (khoá SSH host, cấu hình NetworkManager có mật khẩu) KHÔNG bao giờ lên repo.
      Kiểm: `git status --ignored archive | head`.
- [ ] **Firmware độc quyền** (`*.mbn`, `*.mdt`, `board-2.bin`, factory image): không commit — người dùng tự trích bằng `scripts/10`, `11`.
- [ ] `.ssh_known_hosts` (đã `.gitignore`).
- [ ] Rà lại lần cuối:
      `git grep -n -I -E '@gmail|password|passwd|psk=|100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.' -- . ':!archive'`
- [ ] Lịch sử git: nếu commit cũ từng chứa dữ liệu trên, phải viết lại lịch sử (`git filter-repo`) hoặc tạo repo mới từ bản sạch.

## Nên làm
- [ ] Chọn giấy phép cho script/tài liệu (MIT + CC-BY-4.0 gợi ý) → thêm `LICENSE`.
- [ ] Ảnh chụp màn hình thật (GNOME trên máy) vào README.
- [ ] Patch kernel: dòng `Signed-off-by` đang là danh tính trung tính `pixel3 port <pixel3@localhost>`; gửi upstream thì phải ký bằng **tên thật** (DCO).

## Đã làm (2026-11-15)
- Patch 0005–0014: thay `Signed-off-by` mang email cá nhân bằng danh tính trung tính; `scripts/30-kernel.sh` đặt cứng danh tính này.
- Script `97/98/99` dùng biến `PIXEL_HOST` thay vì IP Tailscale cứng.
- `docs/`: IP Tailscale và tên Wi-Fi thay bằng placeholder (`<ip-tailscale-điện-thoại>`, `<wifi-nhà>`…).
