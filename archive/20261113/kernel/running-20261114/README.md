# Bản đang chạy trên máy (2026-11-14)
- `boot-install.img` = kernel #8 (7.4.0-rc2-pixel3+, Fri Nov 13 15:56 UTC) + DTB có loa — **đang flash ở boot_b** (sha256 trong `.sha256`).
- Module thay nóng (build từ cây có patch 0005/0006/0008; nằm ở `/lib/modules/7.4.0-rc2-pixel3+/` trên máy):
  `q6asm.ko`, `q6asm-dai.ko` (0005), `max1720x_battery.ko` (0006), `qcom_smbx.ko` (0008).
- Patch nguồn: `kernel/patches/0001…0008` (0007 camera/micro CHƯA thử).
