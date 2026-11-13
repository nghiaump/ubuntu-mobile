#!/usr/bin/env bash
# Pha 2/3: đóng initramfs tối giản (busybox tĩnh + initramfs/init) -> out/boot/initramfs.cpio.gz
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
exec "$REPO/scripts/20-build-env.sh" run bash -s <<'INNER'
set -euo pipefail
R=/tmp/ird; OUT=/work/out/boot
rm -rf "$R"; mkdir -p "$R"/{bin,sbin,dev,proc,sys,tmp,run,newroot,etc,usr/bin,usr/sbin,mnt} "$OUT"
cp /bin/busybox "$R/bin/busybox"
gcc -static -Os -o "$R/bin/rebootarg" /repo/initramfs/src/rebootarg.c && strip "$R/bin/rebootarg"
file "$R/bin/busybox" | grep -q "statically linked" || { echo "busybox không tĩnh" >&2; exit 1; }
install -m 755 /repo/initramfs/init "$R/init"
mknod -m 600 "$R/dev/console" c 5 1
mknod -m 666 "$R/dev/null" c 1 3
(cd "$R" && find . | LC_ALL=C sort | cpio -H newc -o --quiet --reproducible | gzip -9n > "$OUT/initramfs.cpio.gz")
ls -la "$OUT/initramfs.cpio.gz"
INNER
