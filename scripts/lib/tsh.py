#!/usr/bin/env python3
"""Chạy lệnh shell trên điện thoại qua telnetd của initramfs (172.16.42.1:23).
macOS không còn lệnh telnet; Python 3.13 bỏ telnetlib -> client tối giản, bỏ qua lệnh IAC.
Dùng: tsh.py 'lệnh shell' [timeout_giây]
"""
import socket
import sys
import time

HOST, PORT = "172.16.42.1", 23
IAC, DONT, DO, WONT, WILL, SB, SE = 255, 254, 253, 252, 251, 250, 240
MARK = "__TSH_END__"


def strip_iac(buf: bytearray, sock: socket.socket) -> bytes:
    out = bytearray(); i = 0
    while i < len(buf):
        b = buf[i]
        if b == IAC and i + 1 < len(buf):
            cmd = buf[i + 1]
            if cmd in (DO, DONT, WILL, WONT) and i + 2 < len(buf):
                i += 3; continue   # không trả lời: telnetd vẫn chạy bình thường
            if cmd == SB:
                j = buf.find(bytes([IAC, SE]), i)
                i = j + 2 if j != -1 else len(buf); continue
            i += 2; continue
        out.append(b); i += 1
    return bytes(out)


def main(cmd: str, timeout: float) -> int:
    s = socket.create_connection((HOST, PORT), timeout=10)
    s.settimeout(1.0)
    time.sleep(0.5)
    try:
        strip_iac(bytearray(s.recv(65536)), s)
    except socket.timeout:
        pass
    # ash tương tác có line-editing (gửi ESC[6n, vẽ lại dòng dài) -> chạy qua `cat | sh` (không tương tác)
    s.sendall(b"stty -echo; cat | sh 2>&1\r\n")
    time.sleep(0.3)
    s.sendall(f"{cmd}\necho; echo {MARK}$?\r\n".encode())
    data = b""; end = time.time() + timeout
    while time.time() < end:
        try:
            chunk = s.recv(65536)
            if not chunk:
                break
            data += strip_iac(bytearray(chunk), s)
            if (MARK + "0").encode() in data or any(f"{MARK}{n}".encode() in data for n in range(1, 256)):
                break
        except socket.timeout:
            # kết quả chỉ được đẩy ra khi có dòng nhập tiếp theo -> gửi dòng trống (vô hại với sh)
            s.sendall(b"\r\n")
            continue
    s.sendall(b"exit\r\n"); s.close()
    text = data.decode(errors="replace").replace("\r", "")
    body, _, rc = text.rpartition(MARK)
    # bỏ dòng lệnh vọng lại (nếu stty chưa kịp tắt echo) và prompt
    lines = [l for l in body.split("\n") if "__TSH_END__" not in l and "stty -echo" not in l
             and not l.startswith("~ # ")]
    sys.stdout.write("\n".join(lines).strip("\n") + "\n")
    try:
        return int(rc.strip().split()[0])
    except (ValueError, IndexError):
        print("(hết thời gian chờ / không đọc được mã thoát)", file=sys.stderr)
        return 124


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1], float(sys.argv[2]) if len(sys.argv) > 2 else 30))
