#!/usr/bin/env python3
"""Tách container FBPK v1 của Google (radio-*.img / bootloader-*.img trên Pixel 3).
Bố cục suy ra từ file thật (radio-crosshatch-g845-00194-210812-b-7635520.img):
  header 0x54 byte: magic "FBPK" | u32 version=1 | char[68] version string |
                    u32 số entry | u32 tổng kích thước file
  entry 0x38 byte : u32 type | char[36] tên | u32 size | u32 (0) | u32 next offset | u32 crc32
  dữ liệu entry nằm ngay sau entry header.
Chỉ ĐỌC; ghi từng phân vùng ra <outdir>/<tên>.img. Dùng: fbpk_unpack.py <file> <outdir>
"""
import os
import struct
import sys
import zlib


def main(path: str, outdir: str) -> None:
    d = open(path, "rb").read()
    magic, ver = struct.unpack_from("<4sI", d, 0)
    if magic != b"FBPK" or ver != 1:
        sys.exit(f"không phải FBPK v1 (magic={magic!r}, ver={ver})")
    vstr = d[8:0x4C].split(b"\0")[0].decode()
    count, total = struct.unpack_from("<II", d, 0x4C)
    if total != len(d):
        sys.exit(f"tổng kích thước header {total} != file {len(d)}")
    print(f"{os.path.basename(path)}: {vstr}, {count} entry")
    os.makedirs(outdir, exist_ok=True)
    off = 0x54
    for _ in range(count):
        etype, raw_name, size, _zero, nxt, crc = struct.unpack_from("<I36sIIII", d, off)
        name = raw_name.split(b"\0")[0].decode()
        data = d[off + 0x38 : off + 0x38 + size]
        if len(data) != size:
            sys.exit(f"entry {name}: dữ liệu bị cụt")
        calc = zlib.crc32(data) & 0xFFFFFFFF
        print(f"  {name}: type={etype} size={size} crc32 header=0x{crc:08x} tính=0x{calc:08x}"
              f" {'OK' if calc == crc else 'KHÁC (định dạng crc có thể khác, kiểm tra thủ công)'}")
        open(os.path.join(outdir, f"{name}.img"), "wb").write(data)
        off = nxt


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
