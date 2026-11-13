#!/usr/bin/env python3
"""Gộp firmware Qualcomm dạng chia nhỏ (.mdt + .b00..bNN) thành 1 file .mbn
(tương đương linux-msm/pil-squasher). Kernel mainline nạp .mbn theo firmware-name trong DTS.
Dùng: pil_squash.py <out.mbn> <in.mdt>
"""
import os
import struct
import sys


def main(out_path: str, mdt_path: str) -> None:
    mdt = open(mdt_path, "rb").read()
    if mdt[:4] != b"\x7fELF":
        sys.exit(f"{mdt_path}: không phải ELF")
    is64 = mdt[4] == 2
    base = mdt_path[:-4]  # bỏ ".mdt"
    if is64:
        e_phoff, = struct.unpack_from("<Q", mdt, 0x20)
        e_phentsize, e_phnum = struct.unpack_from("<HH", mdt, 0x36)
    else:
        e_phoff, = struct.unpack_from("<I", mdt, 0x1C)
        e_phentsize, e_phnum = struct.unpack_from("<HH", mdt, 0x2A)

    out = bytearray()
    def put(off: int, data: bytes) -> None:
        end = off + len(data)
        if len(out) < end:
            out.extend(b"\0" * (end - len(out)))
        out[off:end] = data

    # Header ELF + bảng program header luôn nằm trong .mdt
    put(0, mdt[: e_phoff + e_phentsize * e_phnum])
    for i in range(e_phnum):
        ph = e_phoff + i * e_phentsize
        if is64:
            _t, _fl, p_offset, _va, _pa, p_filesz = struct.unpack_from("<IIQQQQ", mdt, ph)
        else:
            _t, p_offset, _va, _pa, p_filesz = struct.unpack_from("<IIIII", mdt, ph)
        if p_filesz == 0:
            continue
        seg = f"{base}.b{i:02d}"
        if os.path.exists(seg):
            data = open(seg, "rb").read()
        elif p_offset + p_filesz <= len(mdt):
            data = mdt[p_offset : p_offset + p_filesz]
        else:
            sys.exit(f"thiếu segment {seg}")
        if len(data) != p_filesz:
            sys.exit(f"{seg}: kích thước {len(data)} != p_filesz {p_filesz}")
        put(p_offset, data)
    with open(out_path, "wb") as f:
        f.write(out)
    print(f"{mdt_path} -> {out_path} ({len(out)} bytes, {e_phnum} segments)")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
