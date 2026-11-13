#!/usr/bin/env python3
"""Chạy lệnh trên điện thoại qua telnet và GHI LIÊN TỤC mọi output vào file (flush từng đoạn).
Dùng khi lệnh có thể làm máy reset: dòng cuối cùng trong file = việc cuối cùng máy làm được.
Dùng: tstream.py <file_log> 'lệnh' [timeout_giây]
"""
import socket, sys, time
IAC = 255
def clean(b: bytes) -> bytes:
    out = bytearray(); i = 0
    while i < len(b):
        if b[i] == IAC and i + 2 < len(b) and b[i+1] in (251, 252, 253, 254):
            i += 3; continue
        out.append(b[i]); i += 1
    return bytes(out)
def main(path, cmd, timeout):
    s = socket.create_connection(("172.16.42.1", 23), timeout=10); s.settimeout(1.0)
    time.sleep(0.5)
    try: s.recv(65536)
    except socket.timeout: pass
    s.sendall(b"stty -echo; cat | sh 2>&1\r\n"); time.sleep(0.3)
    s.sendall(f"{cmd}\necho __TSTREAM_END__\r\n".encode())
    end = time.time() + timeout; buf = b""
    with open(path, "ab") as f:
        while time.time() < end:
            try:
                c = s.recv(65536)
                if not c:
                    f.write(b"\n[tstream] KET NOI DONG (may reset?)\n"); return 2
                c = clean(c); buf += c; f.write(c); f.flush()
                if b"__TSTREAM_END__" in buf: return 0
            except socket.timeout:
                try: s.sendall(b"\r\n")
                except OSError:
                    f.write(b"\n[tstream] MAT KET NOI (may reset?)\n"); return 2
            except OSError:
                f.write(b"\n[tstream] MAT KET NOI (may reset?)\n"); return 2
    return 124
if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2], float(sys.argv[3]) if len(sys.argv) > 3 else 600))
