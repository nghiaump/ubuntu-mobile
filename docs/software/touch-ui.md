# Giao diện cảm ứng trên GNOME 46 (Wayland): bàn phím ảo, giữ lâu, tai thỏ, Chrome

Tài liệu cho phần "dùng máy như tablet": cái gì đã chạy, vì sao, sửa ở đâu, lệnh thao tác nhanh.
Cập nhật: 2026-11-15. Liên quan: [`rootfs-services.md`](rootfs-services.md) (GNOME chống reset), [`../RUNBOOK.md`](../RUNBOOK.md).

## Thao tác nhanh

| Việc | Lệnh (chạy trên Mac, trong repo) |
|---|---|
| Cài/cập nhật extension GNOME tự viết | `scripts/98-gnome-shell-ext.sh [host]` → **đăng xuất/đăng nhập lại** |
| Chỉnh độ cao dải che tai thỏ | `scripts/98-gnome-shell-ext.sh [host] <px vật lý>` (vd. 150, 190; 0 = tắt) → tắt/bật extension hoặc đăng nhập lại |
| Gỡ extension | `scripts/98-gnome-shell-ext.sh [host] undo` |
| Cờ Chrome + bật OSK/giữ-lâu trong GNOME | `scripts/97-chrome-osk.sh [host]` (gỡ: `... [host] undo`) |
| Giữ lâu = chuột phải trên icon/nền desktop (vá DING) | `scripts/99-ding-longpress.sh [host]` (gỡ: `... [host] restore`) — không cần đăng nhập lại |
| Xem extension đã nạp chưa | trên máy: `gnome-extensions info pixel3xl-shell@pixel3xl` (cần `DBUS_SESSION_BUS_ADDRESS` của phiên, xem script 97) |
| Xem log extension | `journalctl --user -b | grep pixel3xl-shell` |
`[host]` mặc định `$PIXEL_HOST`, không đặt thì USB `172.16.42.1`. Qua Tailscale: `export PIXEL_HOST=<ip-tailscale-của-máy>`.

## Thông số màn hình (đo trên máy)
- Panel `DSI-1` **1440×2960 @60**, dọc. `~/.config/monitors.xml`: **scale 2** (số nguyên → GNOME dùng tọa độ **px vật lý**;
  `Monitor.geometry_scale` vẫn = 2 — bẫy, xem dưới).
- Cảm ứng `s6sy761` = `/dev/input/event3`, udev `ID_INPUT_TOUCHSCREEN=1`, `INPUT_PROP_DIRECT` → GNOME nhận đúng là touchscreen.

## 1. Bàn phím ảo (OSK)

### Trạng thái
| Ứng dụng | OSK khi chạm ô nhập |
|---|---|
| Ô nhập của GNOME Shell (màn đăng nhập, tìm kiếm) | ✅ |
| App GTK (zenity, Settings, Files, Text Editor…) | ✅ (kiểm chứng bằng `zenity --entry` 2026-11-15) |
| Chrome 157 | ✅ nhờ extension (2) (người dùng xác nhận 2026-11-15) |

### Cơ chế (đọc từ mã nguồn trên máy: `gresource extract /usr/lib/gnome-shell/libshell-*.so /org/gnome/shell/ui/keyboard.js`)
1. GNOME bật OSK nếu `org.gnome.desktop.a11y.applications screen-keyboard-enabled = true` **hoặc** (seat touch-mode && thiết bị cuối là touchscreen).
   Đã đặt `true` (script 97) cho chắc.
2. Với app Wayland, OSK chỉ mở khi Mutter đặt input-panel-state = ON. **Mutter 46 `text_input_commit_state`**
   (`src/wayland/meta-wayland-text-input.c`): lần `zwp_text_input_v3.enable` đầu chỉ `focus_in`; **chỉ lần enable THỨ HAI khi đã có focus**
   mới bật panel. GTK gửi lại enable mỗi lần chạm → OSK hiện. **Chrome chỉ gửi enable một lần** → không bao giờ hiện
   (đã xác nhận bằng `WAYLAND_DEBUG=client`: Chrome có gửi enable/commit/set_cursor_rectangle/set_content_type).
3. Chrome phải chạy Wayland + text-input-v3: `--ozone-platform=wayland --enable-wayland-ime --wayland-text-input-version=3`
   (ghi đè `~/.local/share/applications/{google-chrome,com.google.Chrome}.desktop`, script 97; mở Chrome bằng cách khác thì không có cờ).
4. Sửa phía GNOME: extension `pixel3xl-shell` nghe `Main.inputMethod` `cursor-location-changed`; nếu có focus của client
   (`Main.inputMethod.currentFocus`) và OSK đang ẩn → `Main.keyboard.open()`. Chạm lại vào ô (con trỏ đổi vị trí) cũng mở lại OSK.

### Lỗi đã biết
- `JS ERROR: Argument descendant may not be null` ở `keyboard.js:1165 maybeHandleEvent` khi có hộp thoại modal (polkit…): bug GNOME 46, vô hại.

## 2. Giữ lâu = chuột phải
| Nơi | Trạng thái | Cách |
|---|---|---|
| Dock / thanh tác vụ (GNOME Shell) | ✅ | GNOME Shell tự xử lý cảm ứng giữ lâu |
| Icon + nền desktop (DING) | ✅ (2026-11-15) | vá DING, xem §5 |
| Chrome (nội dung web) | ✅ | Chrome tự xử lý |
| App GTK4 (Files, Text Editor…) | ✅ phần lớn | app tự xử lý |
| App khác (GTK3 cũ, XWayland…) | ❌ | cần dịch vụ uinput (dưới) |

- GNOME `org.gnome.desktop.a11y.mouse secondary-click-enabled` (đã bật, 0.8 s) **chỉ áp cho con trỏ (chuột)**, không áp cho cảm ứng gốc của app Wayland.
- Trên Wayland, giữ lâu do từng app xử lý: Chrome (nội dung web), app GTK4 (Files, Text Editor) có; nhiều app khác không.
- Muốn cho **mọi app**: dịch vụ đọc touchscreen (python3-evdev) phát hiện giữ lâu → giả lập chuột phải qua **uinput**.
  Kernel hiện `# CONFIG_INPUT_UINPUT is not set` → cần thêm `CONFIG_INPUT_UINPUT=m` vào `kernel/pixel3.config`, build, fastboot boot, flash (hỏi "đồng ý").
  **Chưa làm** (chờ người dùng quyết). Khó: app vẫn nhận touch-up sau khi giữ → có thể thành click trái; cần grab thiết bị + touchscreen ảo.

## 3. Tai thỏ
- GNOME 46 không hỗ trợ display cutout. **Không cắt ở driver panel**: đổi mode = tắt/bật panel S6E3HA8 = nguy cơ treo/reset (RUNBOOK §6.3).
- Extension `pixel3xl-shell` (1): dải đen `St.Widget` qua `Main.layoutManager.addChrome(..., {affectsStruts: true, trackFullscreen: true})`
  + dời `Main.layoutManager.panelBox` xuống (bọc `LayoutManager._updateBoxes`, nơi GNOME đặt lại vị trí panelBox).
  App toàn màn hình vẫn dùng cả vùng tai thỏ.
- **Strut (v3, 2026-11-15)** — bẫy thứ hai: `LayoutManager._updateRegions` chỉ coi actor là strut khi nó **chạm mép màn hình**
  (actor full-width phải có `y1 <= monitor.y` mới là strut TOP). panelBox dời xuống → mất strut → cửa sổ phóng to (Chrome) chui dưới
  thanh trên, dải đen (reactive) chặn chạm. Sửa: actor **vô hình, reactive=false** `pixel3xlNotchStrut` phủ `0 … notch + panelBox.height`
  (affectsStruts), cập nhật khi `panelBox notify::height`; dải đen `affectsStruts:false, reactive:false` chỉ để che.
- Nhận diện panel: màn chính dọc, tỉ lệ 1440:2960 (±0.005) → không áp cho phiên xrdp/màn ngang.
  **Bẫy (bản v1 hỏng vì cái này):** ở scale nguyên, `Monitor.width/height` là px vật lý nhưng `geometry_scale` = 2 → đừng nhân với geometry_scale.
- Độ cao: `~/.config/pixel-notch-px` (px vật lý, mặc định **172 ≈ 8.4 mm — ƯỚC LƯỢNG, chưa có số đo chuẩn**), quy đổi `px × height/2960`.
  Log: `pixel3xl-shell: monitor WxH scale S -> notch N`.

## 4. Extension `pixel3xl-shell@pixel3xl`
- Mã: `rootfs/gnome-extensions/pixel3xl-shell@pixel3xl/{metadata.json,extension.js}` (GNOME 46, ESM). Bản v1 tên `pixel-notch@pixel3xl` (script tự gỡ).
- Cài vào `~/.local/share/gnome-shell/extensions/` + thêm vào `org.gnome.shell enabled-extensions`.
- **GNOME Wayland chỉ nạp extension mới hoặc code đổi khi phiên khởi động lại** (đăng xuất/đăng nhập, reboot). Không restart được shell tại chỗ.
  Đăng xuất không ảnh hưởng server game (dịch vụ hệ thống). Sau đăng xuất có thể phải gõ mật khẩu (autologin chỉ lần đầu sau boot).
- Không có `org.gnome.Shell.Eval` (unsafe mode tắt) → debug bằng `console.log` + `journalctl --user`.

## 5. Desktop Icons NG (DING) — giữ lâu trên icon/nền desktop
- Icon desktop do extension hệ thống **`ding@rastersoft.com`** (gói `gnome-shell-extension-desktop-icons-ng` `46+really47.0.9-1ubuntu5`) vẽ:
  phần extension chỉ khởi chạy một **ứng dụng GTK3 riêng** `gjs …/ding@rastersoft.com/app/ding.js` (cửa sổ desktop). Ứng dụng này
  chỉ mở menu khi nhận **nút chuột 3** (`desktopIconItem.js _onPressButton`, `desktopManager.js onPressButton`) → chạm giữ không có tác dụng.
- Vá bằng **`/usr/local/sbin/pixel-ding-longpress`** (overlay `rootfs/overlay/usr/local/sbin/`, Python, idempotent, đánh dấu `PIXEL3XL-LONGPRESS`):
  | File | Thay đổi |
  |---|---|
  | `desktopIconItem.js` | `_pixelIsTouch(event)` (nguồn `Gdk.InputSource.TOUCHSCREEN`), hẹn giờ 600 ms khi nhấn nút 1 bằng cảm ứng; `_onReleaseButton`: nếu đã giữ lâu → `_doButtonThreePressed` (menu icon), chặn hành động thả tay; `_onLeave` huỷ |
  | `desktopManager.js` | `onPressButton`: hẹn giờ 600 ms trên nền (dừng rubberband khi tới hạn); `onMotion`: di chuyển > 20 px huỷ; `onReleaseButton(grid, event)`: nếu giữ lâu → menu desktop `popup_at_pointer(event)` |
  | `desktopGrid.js` | truyền `event` vào `onReleaseButton` |
- Thiết kế: **chỉ sự kiện cảm ứng** (chuột/RDP không đổi); **menu mở khi nhấc tay** (mở lúc đang giữ thì cú thả có thể bấm nhầm mục đầu menu, và Wayland cần serial của sự kiện gần nhất cho popup).
- An toàn: kiểm tra mỗi chỗ chèn xuất hiện **đúng 1 lần**, không thì báo `!!` và không vá file đó; sao lưu `*.pixel-orig`; `--check` (thử), `--restore` (gỡ).
- Cập nhật gói: apt ghi đè file → hook **`/etc/apt/apt.conf.d/99-pixel-ding-longpress`** (`DPkg::Post-Invoke`) tự vá lại. Nếu bản DING mới đổi mã, hook im lặng
  bỏ qua (`--quiet`): chạy `sudo pixel-ding-longpress --check` để xem, rồi sửa chuỗi neo trong bộ vá.
- Áp dụng không cần đăng nhập lại: `pkill -f ding@rastersoft.com/app/ding.js` → extension tự chạy lại ứng dụng (script 99 làm việc này).
- Log: `journalctl --user -b | grep DING` (stack trace `DesktopManager() …:264` là cảnh báo `Gio.UnixInputStream` có sẵn, không phải lỗi).
