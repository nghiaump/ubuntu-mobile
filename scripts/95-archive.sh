#!/usr/bin/env bash
# Lưu trữ mọi thứ cần để dựng lại dự án kể cả khi nguồn bên ngoài thay đổi/biến mất.
# Kết quả: <repo>/archive/<YYYYMMDD>/ + MANIFEST.sha256 + README.txt (file lớn bị .gitignore; zip cả repo để cất)
#   repo/      snapshot repo này (scripts, docs, overlay, patches)
#   kernel/    source kernel đã vá (git archive), format-patch, config, mbox b4, output build, boot.img
#   stock/     DTB + dtbo gốc của Google (giải mã .dts), bootloader/radio version, SHA factory image
#   sources/   git bundle: tqftpserv, rmtfs, qrtr, pd-mapper; tarball AOSP mkbootimg/avb; tree sdm845-next
#   debs/      .deb noble arm64 các gói hạ tầng (rmtfs, qrtr, tqftpserv, xrdp, iptables...) + tailscale static
#   firmware/  firmware đang dùng (riêng máy + linux-firmware) + SHA256
#   docker/    image build `pixel-build:noble` (docker save)
#   device/    cấu hình trên điện thoại (/etc, /usr/local, home) — CHỨA BÍ MẬT (Wi-Fi, host key) → quyền 700
# Dùng: scripts/95-archive.sh [host] (mặc định 172.16.42.1). Chạy lại được; mỗi ngày một thư mục.
#       ONLY=device scripts/95-archive.sh : chỉ sao lưu cấu hình điện thoại + MANIFEST
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
H="${1:-172.16.42.1}"
W=/Volumes/pixelwork
D=$(date +%Y%m%d); A="$REPO/archive/$D"
# Bước trong container ghi vào /work/archive-staging rồi chuyển về repo (container không thấy repo dạng ghi)
STAGE="$W/archive-staging/$D"; mkdir -p "$STAGE"
SSH=(ssh -o UserKnownHostsFile="$REPO/.ssh_known_hosts" -o BatchMode=yes "ubuntu@$H")
mkdir -p "$A"/{repo,kernel,stock,sources,debs,firmware,docker,device}
step() { echo; echo "=== $* ($(date +%H:%M:%S))"; }

if [[ "${ONLY:-}" != device ]]; then   # ONLY=device: chỉ chạy lại bước sao lưu điện thoại + MANIFEST
step "repo snapshot"
# loại archive/ (đã nằm trong repo) để không lồng các bản archive cũ vào nhau
COPYFILE_DISABLE=1 tar --no-xattrs --no-mac-metadata --exclude="$(basename "$REPO")/archive" -C "$(dirname "$REPO")" -czf "$A/repo/pixel-repo.tar.gz" "$(basename "$REPO")"

step "kernel source + patches + build output (container)"
"$REPO/scripts/20-build-env.sh" run env A="/work/archive-staging/$D" bash -s <<'INNER'
set -euo pipefail
cd /work/kernel/linux
git config core.checkStat minimal
BASE=v7.4-rc2; HEAD_SHA=$(git rev-parse --short=12 pixel3)
git archive --format=tar --prefix=linux-pixel3/ pixel3 | xz -T0 -6 > "$A/kernel/linux-pixel3-$HEAD_SHA.tar.xz"
rm -rf "$A/kernel/patches"; git format-patch -q "$BASE..pixel3" -o "$A/kernel/patches"
git log --format='%h %ad %an%n    %s' --date=short "$BASE..pixel3" > "$A/kernel/commits.txt"
echo "base=$BASE ($(git rev-parse $BASE^{commit})) head=pixel3 ($(git rev-parse pixel3))" > "$A/kernel/BASE.txt"
cp /work/out/kernel/config "$A/kernel/config-$(cat /work/out/kernel/kernel.release)"
cp -r /work/kernel/patches/panel /work/kernel/patches/pixel3-v7 "$A/kernel/"
mkdir -p "$A/kernel/build-output"
cp /work/out/kernel/{Image.gz,sdm845-google-crosshatch.dtb,kernel.release,patches.txt} "$A/kernel/build-output/"
tar -C /work/out/kernel/modules -cJf "$A/kernel/build-output/modules.tar.xz" lib
cp /work/out/boot/boot-install.img /work/out/boot/boot-smoke.img /work/out/boot/initramfs.cpio.gz "$A/kernel/build-output/"
dtc -I dtb -O dts /work/out/kernel/sdm845-google-crosshatch.dtb > "$A/kernel/build-output/sdm845-google-crosshatch.dts" 2>/dev/null

echo "--- stock DTB/dtbo của Google (giải mã)"
F=/work/factory/crosshatch-sp1a.210812.016.c2
cd /tmp && rm -rf stk && mkdir stk && cd stk
unpack_bootimg --boot_img $F/img/boot.img --out . >/dev/null
python3 - "$F/img/dtbo.img" "$A/stock" <<'PY'
import struct,subprocess,sys,os
out=sys.argv[2]; os.makedirs(out,exist_ok=True)
d=open("dtb","rb").read(); off=0; i=0
while off+8<=len(d):
    m,sz=struct.unpack_from(">II",d,off)
    if m!=0xd00dfeed: break
    p=f"{out}/stock-base-dtb{i}.dtb"; open(p,"wb").write(d[off:off+sz]); off+=sz; i+=1
d=open(sys.argv[1],"rb").read()
m,t,h,es,cnt,eo,ps,v=struct.unpack_from(">8I",d,0)
with open(f"{out}/dtbo-index.txt","w") as idx:
    for n in range(cnt):
        sz,o,id_,rev,*_=struct.unpack_from(">8I",d,eo+n*es)
        p=f"{out}/stock-dtbo{n:02d}-id{id_:03x}-rev{rev:x}.dtbo"; open(p,"wb").write(d[o:o+sz])
        model=subprocess.run(["fdtget",p,"/","model"],capture_output=True,text=True).stdout.strip()
        idx.write(f"{n:2d} id=0x{id_:x} rev=0x{rev:x} {model}\n")
PY
for f in "$A"/stock/*.dtb "$A"/stock/*.dtbo; do dtc -I dtb -O dts "$f" > "${f}.dts" 2>/dev/null || true; done
cp $F/img/android-info.txt "$A/stock/"
ls $F/*.img | xargs -n1 basename > "$A/stock/bootloader-radio-versions.txt"

echo "--- debs noble arm64"
cd "$A/debs" && apt-get update -qq >/dev/null 2>&1
apt-get download -q rmtfs qrtr-tools libqrtr1 tqftpserv protection-domain-mapper xrdp xorgxrdp \
  iptables nftables libip4tc2 libip6tc2 mkbootimg android-sdk-libsparse-utils >/dev/null 2>&1 || true
ls "$A/debs" | wc -l

echo "--- sources (git bundle)"
mkdir -p "$A/sources" && cd /tmp && rm -rf src && mkdir src && cd src
for r in tqftpserv rmtfs qrtr pd-mapper; do
  git clone -q --mirror "https://github.com/linux-msm/$r" "$r.git" && git -C "$r.git" bundle create -q "$A/sources/linux-msm-$r.bundle" --all
done
for p in "platform/system/tools/mkbootimg" "platform/external/avb"; do
  n=$(basename $p); curl -fsSL -o "$A/sources/aosp-$n-android-15.0.0_r1.tar.gz" \
    "https://android.googlesource.com/$p/+archive/refs/tags/android-15.0.0_r1.tar.gz"
done
ls -la "$A/sources"
INNER

# gom phần container tạo ra về repo
for d in kernel stock debs sources; do mkdir -p "$A/$d"; cp -R "$STAGE/$d/." "$A/$d/" 2>/dev/null || true; done
rm -rf "$STAGE"
cp /Volumes/pixelwork/factory/*-factory-*.zip "$A/stock/"   # đường lui khôi phục Android (Google có thể gỡ bản cũ)
step "sdm845-next (tree tham khảo: fuel gauge, audio qdsp6, camera, touchscreen blueline)"
curl -fsSL -o "$A/sources/sdm845-next-branch-sdm845-next.tar.gz" \
  "https://gitlab.com/sdm845/sdm845-next/-/archive/sdm845-next/sdm845-next-sdm845-next.tar.gz"
for p in 1 2 3; do curl -fsSL "https://gitlab.com/api/v4/projects/sdm845%2Fsdm845-next/repository/commits?ref_name=sdm845-next&per_page=100&page=$p"; echo; done \
  | python3 -I -c 'import json,sys
for line in sys.stdin:
    line=line.strip()
    if line.startswith("["):
        for c in json.loads(line): print(c["id"][:12], c["committed_date"][:10], c["title"])' > "$A/sources/sdm845-next-commits.txt"
wc -l < "$A/sources/sdm845-next-commits.txt"

step "tailscale static (arm64)"
TSV=$("${SSH[@]}" "tailscale version | head -1" 2>/dev/null || echo 1.104.7)
curl -fsSL -o "$A/debs/tailscale_${TSV}_arm64.tgz" "https://pkgs.tailscale.com/stable/tailscale_${TSV}_arm64.tgz" || echo "!! không tải được tailscale $TSV"

step "firmware"
COPYFILE_DISABLE=1 tar --no-xattrs -C "$W/firmware" -czf "$A/firmware/firmware.tar.gz" rootfs-overlay device-extra
cp "$W"/firmware/SHA256SUMS-* "$A/firmware/"
shasum -a 256 "$W"/factory/*.zip > "$A/stock/factory-image.sha256"

step "docker image build env"
docker save pixel-build:noble | gzip -1 > "$A/docker/pixel-build-noble.tar.gz"

fi
step "cấu hình trên điện thoại (BÍ MẬT)"
chmod 700 "$A/device"
# GNU tar: --exclude phải đứng TRƯỚC các đường dẫn (đặt sau -> "has no effect" + exit 2)
"${SSH[@]}" "sudo tar --numeric-owner --exclude=home/ubuntu/.cache --exclude=home/ubuntu/snap \
   --exclude=etc/ssl/private -czf - -C / etc usr/local home/ubuntu 2>/dev/null" > "$A/device/device-config.tar.gz"
"${SSH[@]}" "dpkg --get-selections; echo '### apt-mark showmanual'; apt-mark showmanual" > "$A/device/packages.txt"
"${SSH[@]}" "uname -a; cat /proc/cmdline; lsmod; systemctl list-unit-files --state=enabled --no-legend" > "$A/device/runtime-state.txt" 2>&1
chmod 600 "$A"/device/*

step "MANIFEST"
( cd "$A" && find . -type f ! -name MANIFEST.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > MANIFEST.sha256 )
cat > "$A/README.txt" <<EOF
Archive dự án Pixel 3 XL Ubuntu — $D. Xem docs/ARCHIVE.md trong repo để biết cách dùng từng mục.
Kiểm tra toàn vẹn: cd "$A" && shasum -a 256 -c MANIFEST.sha256
device/ chứa bí mật (mật khẩu Wi-Fi trong netplan, SSH host key) — không chia sẻ.
EOF
du -sh "$A"/* | sort -k2; du -sh "$A"
