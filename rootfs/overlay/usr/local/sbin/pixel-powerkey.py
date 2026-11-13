#!/usr/bin/python3
"""Nút nguồn = bật/tắt màn hình "mềm" kiểu khoá màn hình điện thoại.

KHÔNG tắt panel thật: tắt panel S6E3HA8 (DPMS) hiện làm máy reset. Thay vào đó:
  tắt  -> backlight = 0 (AMOLED đen), khoá cảm ứng (inhibited=1)
  bật  -> trả độ sáng cũ, mở cảm ứng — vào thẳng desktop, KHÔNG khoá phiên GNOME:
          khi phiên bị khoá, gsd-power tự tắt màn hình sau ~30 s không thao tác (bỏ qua idle-delay)
          -> panel tắt -> máy treo -> watchdog reset (bootreason=watchdog, 2026-11-13).
Giữ lâu nút nguồn (~10s) vẫn là reset cứng của phần cứng (không đổi được).
GNOME power-button-action và logind HandlePowerKey phải là nothing/ignore để không đụng nhau.
"""
import glob
import os
import struct
import subprocess
import sys
import time

KEY_POWER = 116
EV_KEY = 1
BL = glob.glob("/sys/class/backlight/*/brightness")
STATE_FILE = "/run/pixel-powerkey.brightness"


def find_dev(name):
    for ev in sorted(glob.glob("/sys/class/input/event*")):
        try:
            if open(f"{ev}/device/name").read().strip() == name:
                return ev
        except OSError:
            pass
    return None


def log(msg):
    print(f"pixel-powerkey: {msg}", flush=True)


def set_touch(inhibit):
    ev = find_dev("s6sy761")
    if ev:
        try:
            with open(f"{ev}/device/inhibited", "w") as f:
                f.write("1" if inhibit else "0")
        except OSError as e:
            log(f"không đổi được inhibited cảm ứng: {e}")


def lock_seat0():
    try:
        out = subprocess.run(["loginctl", "list-sessions", "--no-legend"], capture_output=True, text=True).stdout
        for line in out.splitlines():
            parts = line.split()
            if len(parts) >= 4 and parts[3] == "seat0":
                subprocess.run(["loginctl", "lock-session", parts[0]], check=False)
    except OSError as e:
        log(f"không khoá được phiên: {e}")


def screen_off():
    if not BL:
        return
    cur = open(BL[0]).read().strip()
    if cur != "0":
        open(STATE_FILE, "w").write(cur)
    open(BL[0], "w").write("0")
    set_touch(True)
    log(f"tắt màn hình (độ sáng cũ {cur})")


def screen_on():
    if not BL:
        return
    try:
        val = open(STATE_FILE).read().strip() or "40"
    except OSError:
        val = "40"
    set_touch(False)
    open(BL[0], "w").write(val)
    log(f"bật màn hình (độ sáng {val})")


def main():
    ev = None
    while ev is None:
        ev = find_dev("pm8941_pwrkey")
        if ev is None:
            time.sleep(2)
    path = "/dev/input/" + os.path.basename(ev)
    log(f"nghe {path}")
    fmt = "llHHi"
    size = struct.calcsize(fmt)
    last = 0.0
    with open(path, "rb") as f:
        while True:
            data = f.read(size)
            if len(data) < size:
                continue
            _s, _us, typ, code, value = struct.unpack(fmt, data)
            if typ == EV_KEY and code == KEY_POWER and value == 1:
                now = time.monotonic()
                if now - last < 0.4:     # chống dội phím
                    continue
                last = now
                off = BL and open(BL[0]).read().strip() == "0"
                (screen_on if off else screen_off)()


if __name__ == "__main__":
    sys.exit(main())
