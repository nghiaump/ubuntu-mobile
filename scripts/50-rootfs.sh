#!/usr/bin/env bash
# Pha 2: dựng rootfs Ubuntu 24.04 (noble) arm64 trong file ext4 (loop mount, container privileged).
# Đầu vào : kernel đã build (scripts/30-kernel.sh), firmware (scripts/11, 12), overlay trong rootfs/overlay
# Kết quả : /Volumes/pixelwork/out/rootfs/rootfs.img (raw ext4, nhãn "pixelroot")
#           /Volumes/pixelwork/out/rootfs/rootfs.simg (Android sparse, để fastboot flash userdata)
# FINALIZE=1 scripts/50-rootfs.sh : chỉ chạy bước cuối (e2fsck + img2simg) trên rootfs.img có sẵn.
# Người dùng: "ubuntu" (khoá mật khẩu, sudo NOPASSWD), đăng nhập SSH bằng key từ ~/.ssh/*.pub của Mac.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
W=/Volumes/pixelwork
[[ -f $W/out/kernel/kernel.release ]] || { echo "Chưa build kernel (scripts/30-kernel.sh)" >&2; exit 1; }
[[ -x $W/out/tqftpserv/tqftpserv ]] || { echo "Chưa build tqftpserv (scripts/55-tqftpserv.sh)" >&2; exit 1; }
mkdir -p "$W/out/rootfs"
cat ~/.ssh/*.pub > "$W/out/rootfs/authorized_keys"
echo "SSH keys: $(wc -l < "$W/out/rootfs/authorized_keys") key từ ~/.ssh/*.pub"
exec "$REPO/scripts/20-build-env.sh" priv env FINALIZE="${FINALIZE:-0}" bash -s <<'INNER'
set -euo pipefail
SIZE=4G
OUT=/work/out/rootfs
IMG=$OUT/rootfs.img
MNT=/mnt/root
KREL=$(cat /work/out/kernel/kernel.release)
MIRROR=http://ports.ubuntu.com/ubuntu-ports
PKGS=systemd-sysv,systemd-timesyncd,systemd-resolved,udev,dbus,kmod,sudo,locales,tzdata,
PKGS+=openssh-server,network-manager,dnsmasq-base,wpasupplicant,iw,rfkill,wireless-regdb,
PKGS+=iptables,nftables,   # NM method=shared (usb0) cần firewall backend iptables của Ubuntu; Docker cũng cần
PKGS+=bluez,iproute2,iputils-ping,ca-certificates,curl,nano,less,e2fsprogs,usbutils,zstd,
PKGS+=qrtr-tools,rmtfs,tqftpserv,protection-domain-mapper,
PKGS+=qbootctl   # đánh dấu slot A/B "boot thành công" — thiếu thì ABL hết lượt thử, rơi về Android (RUNBOOK §6.5)

cleanup() { set +e; for m in dev/pts dev proc sys run; do umount "$MNT/$m" 2>/dev/null; done; umount "$MNT" 2>/dev/null; }
trap cleanup EXIT

if [[ "${FINALIZE:-0}" != 1 ]]; then
rm -f "$IMG"; truncate -s $SIZE "$IMG"
mkfs.ext4 -q -F -L pixelroot "$IMG"
mkdir -p "$MNT"; mount -o loop "$IMG" "$MNT"

echo "== debootstrap noble arm64"
debootstrap --arch=arm64 --components=main,universe --include="$PKGS" noble "$MNT" "$MIRROR" \
  > /work/logs/debootstrap.log 2>&1 || { tail -30 /work/logs/debootstrap.log; exit 1; }

for m in proc sys dev dev/pts run; do mkdir -p "$MNT/$m"; done
mount -t proc proc "$MNT/proc"; mount -t sysfs sys "$MNT/sys"
mount --bind /dev "$MNT/dev"; mount --bind /dev/pts "$MNT/dev/pts"; mount -t tmpfs tmpfs "$MNT/run"
cp /etc/resolv.conf "$MNT/etc/resolv.conf.build"
in_chroot() { chroot "$MNT" /usr/bin/env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8 "$@"; }

cat > "$MNT/etc/apt/sources.list.d/ubuntu.sources" <<EOF
Types: deb
URIs: $MIRROR
Suites: noble noble-updates noble-backports noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
: > "$MNT/etc/apt/sources.list"
mv "$MNT/etc/resolv.conf" "$MNT/etc/resolv.conf.orig" 2>/dev/null || true
cp "$MNT/etc/resolv.conf.build" "$MNT/etc/resolv.conf"
echo "== apt upgrade"
in_chroot apt-get update -q > /work/logs/rootfs-apt.log 2>&1
in_chroot apt-get -y -q full-upgrade >> /work/logs/rootfs-apt.log 2>&1

echo "== cấu hình hệ thống"
echo pixel3xl > "$MNT/etc/hostname"
printf '127.0.0.1\tlocalhost\n127.0.1.1\tpixel3xl\n::1\tlocalhost ip6-localhost ip6-loopback\n' > "$MNT/etc/hosts"
printf 'LABEL=pixelroot\t/\text4\tdefaults,noatime,errors=remount-ro\t0\t1\n' > "$MNT/etc/fstab"
ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh "$MNT/etc/localtime"; echo Asia/Ho_Chi_Minh > "$MNT/etc/timezone"
echo 'LANG=C.UTF-8' > "$MNT/etc/default/locale"
in_chroot useradd -m -s /bin/bash -G sudo,adm,dialout,video,render,plugdev,systemd-journal ubuntu
in_chroot passwd -l ubuntu >/dev/null
install -d -m 700 -o 1000 -g 1000 "$MNT/home/ubuntu/.ssh"
install -m 600 -o 1000 -g 1000 "$OUT/authorized_keys" "$MNT/home/ubuntu/.ssh/authorized_keys"

echo "== overlay repo + firmware + modules"
cp -a /repo/rootfs/overlay/. "$MNT/"
# mọi đường dẫn từ overlay về root:root (file trên Mac mang uid người dùng)
(cd /repo/rootfs/overlay && find . -mindepth 1) | while read -r p; do chown -h root:root "$MNT/$p"; done
chmod 600 "$MNT/etc/NetworkManager/system-connections/usb0.nmconnection"; chmod 440 "$MNT/etc/sudoers.d/90-ubuntu"
mkdir -p "$MNT/usr/lib/firmware" "$MNT/usr/lib/modules"   # rootfs chưa có gói kernel -> chưa có 2 thư mục này
cp -a /work/firmware/rootfs-overlay/lib/firmware/. "$MNT/usr/lib/firmware/"
chown -R root:root "$MNT/usr/lib/firmware"
rm -rf "$MNT/usr/lib/modules/$KREL"
cp -a "/work/out/kernel/modules/lib/modules/$KREL" "$MNT/usr/lib/modules/"
rm -f "$MNT/usr/lib/modules/$KREL/build" "$MNT/usr/lib/modules/$KREL/source"
chown -R root:root "$MNT/usr/lib/modules/$KREL"
in_chroot depmod -a "$KREL"
# tqftpserv v1.3 (scripts/55-tqftpserv.sh); thư viện libqrtr/libzstd/liblzma đã có trong rootfs
install -m 755 /work/out/tqftpserv/tqftpserv "$MNT/usr/local/bin/tqftpserv"
install -d "$MNT/boot/pixel"
cp /work/out/kernel/Image.gz /work/out/kernel/sdm845-google-crosshatch.dtb /work/out/kernel/config "$MNT/boot/pixel/"

echo "== dịch vụ"
in_chroot systemctl enable usb-gadget.service pixel-firstboot.service pixel-sshkeys.service serial-getty@ttyGS0.service pixel-charge-limit.service pixel-power-log.timer pixel-bt-addr.service \
  NetworkManager.service ssh.service systemd-timesyncd.service >/dev/null 2>&1
for s in rmtfs tqftpserv; do
  in_chroot systemctl enable "$s.service" >/dev/null 2>&1 && echo "   enable $s" || echo "   !! không có $s.service"
done
# Nhận file Bluetooth (OBEX) trong phiên người dùng: agent chỉ nhận từ thiết bị đã ghép đôi (docs/hardware/connectivity.md)
in_chroot systemctl --global enable pixel-obex-agent.service >/dev/null 2>&1 || echo "   !! không enable được pixel-obex-agent"
# qbootctl.service là unit "static" (không có [Install]) -> gắn tay vào multi-user (RUNBOOK §6.5)
in_chroot ln -sf /lib/systemd/system/qbootctl.service /etc/systemd/system/multi-user.target.wants/qbootctl.service
# pd-mapper / qrtr-ns: kernel đã có (QCOM_PD_MAPPER, qrtr ns) -> tắt bản userspace để tránh tranh cổng
in_chroot systemctl disable pd-mapper.service qrtr-ns.service >/dev/null 2>&1 || true
in_chroot systemctl mask pd-mapper.service qrtr-ns.service >/dev/null 2>&1 || true
in_chroot systemctl list-unit-files 'rmtfs*' 'tqftp*' 'pd-mapper*' 'qrtr-ns*' 'usb-gadget*' 'pixel-*' 'ssh*' 2>/dev/null | grep -E 'service|socket' || true

echo "== dọn"
rm -f "$MNT"/etc/ssh/ssh_host_*      # sinh lại ở lần boot đầu (pixel-firstboot)
: > "$MNT/etc/machine-id"; rm -f "$MNT/var/lib/dbus/machine-id"
mv "$MNT/etc/resolv.conf.orig" "$MNT/etc/resolv.conf" 2>/dev/null || ln -sf ../run/systemd/resolve/stub-resolv.conf "$MNT/etc/resolv.conf"
rm -f "$MNT/etc/resolv.conf.build"
in_chroot apt-get clean
dpkg-query --admindir="$MNT/var/lib/dpkg" -W -f '${Package} ${Version}\n' > "$OUT/packages.txt"
du -shx "$MNT" 2>/dev/null || true   # -x: không đi vào /proc,/sys đang mount (lỗi đọc -> pipefail)
cleanup; trap - EXIT
set -e   # cleanup() đã set +e
fi   # hết phần dựng (bỏ qua khi FINALIZE=1)
e2fsck -f -y "$IMG" >/dev/null 2>&1 || true
e2fsck -f -n "$IMG" | tail -1
img2simg "$IMG" "$OUT/rootfs.simg"
ls -la "$OUT"
INNER
