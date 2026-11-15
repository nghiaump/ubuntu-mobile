# Tài liệu dự án: Ubuntu 24.04 native trên Google Pixel 3 XL (crosshatch)

Giới thiệu dự án (ảnh tổng quan, trạng thái phần cứng, bắt đầu nhanh): [`../README.md`](../README.md).

Thứ tự đọc khi quay lại dự án sau một thời gian:
1. [`../CLAUDE.md`](../CLAUDE.md) — bối cảnh + **luật an toàn** (bắt buộc trước khi flash).
2. [`RUNBOOK.md`](RUNBOOK.md) — tra cứu nhanh, quy trình chuẩn, **bảng lỗi đã gặp → cách tránh**.
3. Tài liệu chi tiết bên dưới khi cần sửa một phần cụ thể.
4. [`../NOTES.md`](../NOTES.md) — nhật ký theo thời gian (lệnh, kết quả, quyết định).

## Cấu trúc
```
docs/
├── README.md                     (file này)
├── RUNBOOK.md                    vận hành + xử lý sự cố
├── ARCHIVE.md                    bản lưu trữ phụ thuộc + cách khôi phục
├── PUBLISHING.md                 checklist trước khi công khai repo (dữ liệu cá nhân, firmware, giấy phép)
├── hardware/                     TỪNG LINH KIỆN: chip, thông số, GPIO, nguồn, driver, firmware, trạng thái
│   ├── README.md                 bảng tổng hợp + ID bo mạch
│   ├── power-battery.md          PMIC, chip sạc PMI8998, fuel gauge MAX1720x, pin, sạc không dây, nút nguồn
│   ├── display-touch-gpu.md      panel AMOLED S6E3HA8, cảm ứng S6SY761, GPU Adreno 630, simplefb
│   ├── connectivity.md           Wi-Fi/BT WCN3990, modem/DSP, rmtfs/tqftpserv, NFC
│   ├── storage-usb.md            UFS (bảng phân vùng), USB-C dwc3, gadget NCM/ACM
│   └── audio-camera-haptics.md   loa CS35L36, codec WCD934x, rung CS40L20, 3 camera
├── software/
│   ├── boot-chain.md             ABL, boot.img, AVB, cmdline, initramfs
│   ├── kernel.md                 base, patch, config (lý do từng nhóm), build
│   ├── firmware.md               nguồn + đường dẫn + cách trích
│   ├── rootfs-services.md        gói, overlay, dịch vụ systemd, GNOME, chống reset màn hình, nút nguồn
│   ├── touch-ui.md               bàn phím ảo (Chrome), giữ lâu = chuột phải, tai thỏ, extension GNOME tự viết
│   └── remote-access.md          USB NCM, Wi-Fi, Tailscale, xrdp, AP dự phòng
└── generated/                    TỰ SINH (scripts/96-hw-facts.sh) — không sửa tay
    ├── driver-map.md             node DT → compatible → file driver → Kconfig → y/m
    ├── stock-c1-overlay.dts      overlay gốc Google bo C1 (nguồn số liệu phần cứng)
    ├── mainline-crosshatch.dts   DTB đang chạy
    └── firmware.sha256
```

## Quy ước
- Số liệu phần cứng luôn ghi **nguồn**: `stock dtbo` (overlay gốc Google, id 0x115 "C1 DVT1.1"), `mainline DTS`,
  hoặc `đo trên máy` (sysfs/dmesg). Chưa kiểm chứng thì ghi rõ **(chưa kiểm chứng)**.
- Không ghi mật khẩu/bí mật vào docs. Bí mật chỉ nằm trong NetworkManager/netplan trên máy và `archive/*/device/`.
