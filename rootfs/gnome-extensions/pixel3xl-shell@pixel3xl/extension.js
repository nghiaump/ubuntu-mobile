// Pixel 3 XL — chỉnh GNOME Shell 46 (tài liệu: docs/software/touch-ui.md)
//
// (1) TAI THỎ: GNOME không biết display cutout. Thêm dải đen (chrome, affectsStruts, ẩn khi app toàn màn hình)
//     ở mép trên màn hình tích hợp và dời thanh trên (panelBox) xuống dưới -> cửa sổ/dock nằm dưới tai thỏ.
//     Nhận diện panel bằng TỈ LỆ khung hình dọc 1440:2960 (không dùng geometry_scale: ở scale nguyên, tọa độ
//     là px vật lý nhưng geometry_scale vẫn = 2 -> bản v1 tính sai và đặt dải cao 0).
//     Độ cao = px VẬT LÝ trong ~/.config/pixel-notch-px (mặc định 172, ước lượng), quy đổi theo chiều cao màn hình.
//     STRUT (v3): GNOME (_updateRegions) chỉ coi actor là strut khi nó CHẠM mép màn hình; panelBox đã dời xuống thì
//     không còn strut -> cửa sổ phóng to chui dưới thanh trên. Dùng một actor VÔ HÌNH, không nhận chạm, phủ từ mép
//     trên tới hết panelBox làm strut; dải đen chỉ để che (affectsStruts false, reactive false).
//
// (2) BÀN PHÍM ẢO CHO CHROME: Mutter 46 (text_input_commit_state) chỉ bật OSK khi client gửi
//     zwp_text_input_v3.enable LẦN THỨ HAI lúc đã có focus. GTK gửi lại enable mỗi lần chạm; Chrome chỉ gửi
//     một lần -> OSK không bao giờ hiện. Khi InputMethod báo cursor-location-changed mà đang có focus của
//     client và OSK đang ẩn -> mở OSK (chỉ khi OSK được bật: a11y screen-keyboard-enabled hoặc touch-mode).
import St from 'gi://St';
import GLib from 'gi://GLib';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const PANEL_ASPECT = 1440 / 2960;
const PANEL_PHYS_H = 2960;
const DEFAULT_NOTCH_PX = 172;

export default class Pixel3xlShellExtension extends Extension {
    _notchPx() {
        try {
            const path = GLib.build_filenamev([GLib.get_home_dir(), '.config', 'pixel-notch-px']);
            const [ok, data] = GLib.file_get_contents(path);
            if (ok) {
                const v = parseInt(new TextDecoder().decode(data).trim(), 10);
                if (Number.isFinite(v) && v >= 0 && v < 600)
                    return v;
            }
        } catch (e) {
            // không có file -> mặc định
        }
        return DEFAULT_NOTCH_PX;
    }

    _applyNotch() {
        const lm = Main.layoutManager;
        const m = lm.primaryMonitor;
        if (!m || !this._bar || !this._strut)
            return;
        const portrait = m.height > m.width;
        const isPanel = portrait && Math.abs(m.width / m.height - PANEL_ASPECT) < 0.005;
        const h = isPanel ? Math.round(this._notchPx() * m.height / PANEL_PHYS_H) : 0;

        this._bar.set_position(m.x, m.y);
        this._bar.set_size(m.width, Math.max(h, 1));
        this._bar.visible = h > 0;
        lm.panelBox.set_position(m.x, m.y + h);
        // strut vô hình: tai thỏ + thanh trên (khi h = 0, panelBox tự là strut như bình thường)
        this._strut.set_position(m.x, m.y);
        this._strut.set_size(m.width, Math.max(h + lm.panelBox.height, 1));
        this._strut.visible = h > 0;
        lm._queueUpdateRegions?.();
        if (this._lastLog !== `${m.width}x${m.height}/${h}/${lm.panelBox.height}`) {
            this._lastLog = `${m.width}x${m.height}/${h}/${lm.panelBox.height}`;
            console.log(`pixel3xl-shell: monitor ${m.width}x${m.height} scale ${m.geometry_scale} -> notch ${h}, strut ${h + lm.panelBox.height}`);
        }
    }

    _onCursorLocation() {
        const kb = Main.keyboard;
        if (!kb?.keyboardActor)      // OSK chưa được bật (a11y/touch-mode)
            return;
        if (!Main.inputMethod.currentFocus || kb.visible)
            return;
        kb.open(Main.layoutManager.focusIndex);
    }

    enable() {
        const lm = Main.layoutManager;
        this._bar = new St.Widget({
            name: 'pixel3xlNotchBar',
            style: 'background-color: #000000;',
            reactive: false,
        });
        lm.addChrome(this._bar, {affectsStruts: false, trackFullscreen: true});
        this._strut = new St.Widget({name: 'pixel3xlNotchStrut', reactive: false, opacity: 0});
        lm.addChrome(this._strut, {affectsStruts: true, trackFullscreen: true});
        this._panelHeightId = lm.panelBox.connect('notify::height', () => this._applyNotch());

        this._origUpdateBoxes = lm._updateBoxes;
        const ext = this;
        lm._updateBoxes = function (...args) {
            const ret = ext._origUpdateBoxes.apply(this, args);
            ext._applyNotch();
            return ret;
        };
        this._applyNotch();

        this._imId = Main.inputMethod.connect('cursor-location-changed',
            () => this._onCursorLocation());
    }

    disable() {
        const lm = Main.layoutManager;
        if (this._imId) {
            Main.inputMethod.disconnect(this._imId);
            this._imId = 0;
        }
        if (this._origUpdateBoxes) {
            lm._updateBoxes = this._origUpdateBoxes;
            this._origUpdateBoxes = null;
        }
        if (this._panelHeightId) {
            lm.panelBox.disconnect(this._panelHeightId);
            this._panelHeightId = 0;
        }
        for (const a of [this._bar, this._strut]) {
            if (a) {
                lm.removeChrome(a);
                a.destroy();
            }
        }
        this._bar = null;
        this._strut = null;
        lm._updateBoxes();
        lm._queueUpdateRegions?.();
    }
}
