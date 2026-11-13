#!/usr/bin/env python3
"""Chuyển Android sparse image -> raw image (thay cho simg2img).
Nếu input không phải sparse thì copy nguyên (để script gọi được đồng nhất).
Dùng: simg2img.py <in.img> <out.raw>
"""
import shutil
import struct
import sys

SPARSE_MAGIC = 0xED26FF3A
RAW, FILL, DONT_CARE, CRC = 0xCAC1, 0xCAC2, 0xCAC3, 0xCAC4


def main(src: str, dst: str) -> None:
    with open(src, "rb") as f:
        hdr = f.read(28)
        magic, major, _minor, fhdr_sz, chdr_sz, blk_sz, total_blks, total_chunks, _csum = \
            struct.unpack("<IHHHHIIII", hdr)
        if magic != SPARSE_MAGIC:
            f.close()
            shutil.copyfile(src, dst)
            print(f"{src}: không phải sparse, đã copy nguyên")
            return
        if major != 1:
            sys.exit(f"sparse major version {major} không hỗ trợ")
        f.seek(fhdr_sz)
        with open(dst, "wb") as o:
            for _ in range(total_chunks):
                ctype, _res, csize, tsize = struct.unpack("<HHII", f.read(12))
                f.seek(chdr_sz - 12, 1)
                data_sz = tsize - chdr_sz
                nbytes = csize * blk_sz
                if ctype == RAW:
                    remaining = data_sz
                    while remaining:
                        buf = f.read(min(remaining, 1 << 22))
                        if not buf:
                            sys.exit("file sparse bị cụt")
                        o.write(buf)
                        remaining -= len(buf)
                elif ctype == FILL:
                    pat = f.read(4)
                    if pat == b"\0\0\0\0":
                        o.seek(nbytes, 1)
                    else:
                        o.write(pat * (nbytes // 4))
                elif ctype == DONT_CARE:
                    o.seek(nbytes, 1)
                elif ctype == CRC:
                    f.seek(data_sz, 1)
                else:
                    sys.exit(f"chunk type lạ 0x{ctype:x}")
            o.truncate(total_blks * blk_sz)
    print(f"{src} -> {dst}: {total_blks * blk_sz} bytes")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
