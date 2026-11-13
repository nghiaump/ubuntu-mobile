# Chuỗi khởi động

```
Nguồn → XBL → ABL (b1c1-0.4-7617406, UNLOCKED, orange) → boot_b → kernel + initramfs → switch_root → systemd (userdata)
```

## Yêu cầu của ABL (Pixel 3 XL, bootloader cuối)
| Yêu cầu | Giá trị | Hậu quả nếu sai | Nguồn |
|---|---|---|---|
| `text_offset` trong header Image | **0x80000** | ABL không boot kernel mainline (TEXT_OFFSET=0 từ 120dc60d) | cover letter v7 "Booting" |
| Board-id trong DTB | **`<0x11505 0>`** (C1 DVT1.1) | `Error verifying the received boot.img: Invalid Parameter` | thử nghiệm Pha 3 |
| MSM-id | `<0x141 0x20001>` (SDM845 v2.1) | — | mainline DTS |
| AVB footer | có (64 MiB như stock, test key SHA256_RSA2048) | (thử không footer cũng lỗi — nguyên nhân thật là board-id; giữ footer cho giống stock) | stock boot.img |
| Trạng thái verify | `orange` (unlock) — vbmeta stock không khớp vẫn boot | — | cmdline |

## boot.img (`scripts/60-bootimg.sh`, khớp stock theo `unpack_bootimg`)
| Trường | Giá trị |
|---|---|
| header | **v2**, pagesize 4096 |
| base / kernel / ramdisk / tags / dtb offset | 0x0 / 0x00008000 / 0x01000000 / 0x00000100 / 0x01f00000 |
| kernel | `Image` nén **LZ4 frame** (`04 22 4d 18 64 70 b9` = y hệt stock) |
| dtb | `sdm845-google-crosshatch.dtb`, board-id ghi đè bằng `fdtput` |
| os_version / patch | 12.0.0 / 2022-06 |
| cmdline | `console=tty0 loglevel=7 clk_ignore_unused pd_ignore_unused` + (install) `pixel.root=LABEL=pixelroot pixel.rootfstype=ext4 net.ifnames=0` |
| Kích thước | 67108864 B (= phân vùng boot), sau `avbtool add_hash_footer --partition_size 67108864 --salt 7069786533786c2d6d61696e6c696e65` |

## ABL sửa cmdline
- **Thay `console=` của ta bằng `console=null`** (arm64 không có `CMDLINE_EXTEND`) → không có log kernel trên màn hình.
- Chèn `rootwait ro init=/init androidboot.* msm_drm.dsi_display0=dsi_s6e3ha8_cmd_display::timing0 androidboot.dtbo_idx=13 …`
  → initramfs dùng **`pixel.root=`** riêng, bỏ qua `root=` của Android.
- ABL áp overlay dtbo stock idx 13 lên DTB mainline nhưng DT gốc vẫn sạch (không thấy node Android).

## initramfs (`initramfs/init`, busybox-static)
1. mount proc/sys/dev/devpts/configfs; `cat /dev/kmsg > /dev/tty1` (busybox `dmesg` không có `-w`).
2. Dựng gadget NCM+ACM, IP 172.16.42.1, udhcpd (cấp 172.16.42.2, không gateway), `telnetd` (cửa debug).
3. Nếu có `pixel.root=` và không có `pixel.shell=1`: chờ thiết bị (findfs), mount, **gỡ hẳn gadget**, `switch_root` → `/sbin/init`.
4. Không có `pixel.root` (boot-smoke.img): ở lại shell debug (telnet qua `scripts/lib/tsh.py`, `tstream.py`).
- `rebootarg <bootloader|recovery>`: reboot kèm tham số (reboot-mode PON) — busybox `reboot` không làm được.

## Slot A/B (ABL Qualcomm/Google)
- Cờ slot nằm trong thuộc tính GPT của `boot_a`/`boot_b` (LUN0: `sda11`/`sda12`): active, retry-count, successful, unbootable.
  Đọc từ fastboot: `fastboot getvar all 2>&1 | grep -E 'current-slot|:a:|:b:'`; từ Ubuntu: `sudo qbootctl`.
- `fastboot flash boot_b` hoặc `--set-active=b` → retry=3, successful=no. Mỗi lần boot slot chưa successful bị trừ 1; về 0 ⇒ unbootable ⇒ ABL boot slot a (Android stock).
- Ubuntu đánh dấu bằng `qbootctl.service` (gói `qbootctl`, drop-in `10-pixel.conf`). Chi tiết sự cố: RUNBOOK §6.5.
- `fastboot boot` (RAM) không trừ lượt slot b nhưng ABL ghi `androidboot.slot_suffix=_a` vào cmdline.
