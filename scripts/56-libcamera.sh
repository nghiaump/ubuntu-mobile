#!/usr/bin/env bash
# Build libcamera mới (có soft ISP — Ubuntu noble chỉ có 0.2.0, chưa có) cho camera CAMSS (IMX355 trước).
# CAMSS chỉ xuất Bayer thô; pipeline "simple" + IPA "simple" (soft ISP: debayer, AWB, AGC trên CPU/GPU) cho ra ảnh dùng được.
# Build trong container arm64 noble (cùng ABI với điện thoại), prefix /usr/local (không đụng gói hệ thống).
# Kết quả: /Volumes/pixelwork/out/libcamera/libcamera-<tag>-arm64.tar.gz  (giải nén vào / trên máy, rồi ldconfig)
# Dùng: scripts/56-libcamera.sh [tag]     (mặc định v0.8.0)
#       scripts/56-libcamera.sh install [host]  -> đẩy lên máy + cài gói runtime
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${1:-v0.8.0}"
OUT=/Volumes/pixelwork/out/libcamera

if [[ "${1:-}" == install ]]; then
  H="${2:-172.16.42.1}"
  TGZ=$(ls -t "$OUT"/libcamera-*-arm64.tar.gz | head -1)
  SSH=(ssh -o UserKnownHostsFile="$REPO/.ssh_known_hosts" -o BatchMode=yes "ubuntu@$H")
  "${SSH[@]}" "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q libyaml-0-2 libdw1t64 libunwind8 libevent-2.1-7t64 libevent-pthreads-2.1-7t64 \
      libjpeg-turbo8 libtiff6 libdrm2 libsdl2-2.0-0 gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-tools v4l-utils >/dev/null && echo deps ok"
  "${SSH[@]}" "sudo tar -C / -xzf - --no-same-owner && sudo ldconfig && /usr/local/bin/cam --version" < "$TGZ"
  exit 0
fi

mkdir -p "$OUT"
"$REPO/scripts/20-build-env.sh" run bash -s "$TAG" <<'INNER'
set -euo pipefail
TAG="$1"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends git meson ninja-build pkg-config g++ python3-yaml python3-ply python3-jinja2 \
  libyaml-dev libgnutls28-dev libssl-dev libdw-dev libunwind-dev libudev-dev libevent-dev libjpeg-dev libtiff-dev libdrm-dev \
  libsdl2-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev openssl >/dev/null
SRC=/work/src/libcamera
if [[ ! -d $SRC/.git ]]; then git clone -q https://git.libcamera.org/libcamera/libcamera.git $SRC; fi
cd $SRC
git config core.checkStat minimal
git fetch -q --tags && git checkout -q -f "$TAG"
echo "== libcamera $(git describe --tags)"
BUILD=/tmp/lcbuild; rm -rf $BUILD
meson setup $BUILD --prefix=/usr/local --libdir=lib/aarch64-linux-gnu --buildtype=release \
  -Dpipelines=simple -Dipas=simple -Dgstreamer=enabled -Dcam=enabled -Dqcam=disabled -Dv4l2=true \
  -Ddocumentation=disabled -Dtest=false -Dlc-compliance=disabled -Dpycamera=disabled >/tmp/meson.log || { tail -40 /tmp/meson.log; exit 1; }
grep -E "Pipelines|IPA|gstreamer|cam application|V4L2" /tmp/meson.log | head -12 || true
ninja -C $BUILD >/tmp/ninja.log 2>&1 || { tail -40 /tmp/ninja.log; exit 1; }
rm -rf /tmp/lcroot && DESTDIR=/tmp/lcroot meson install -C $BUILD --quiet
# IPA phải được ký (hoặc chạy cô lập); ký bằng khoá tạo lúc build — giữ nguyên chữ ký đi kèm .so
tar -C /tmp/lcroot -czf /work/out/libcamera/libcamera-$TAG-arm64.tar.gz usr
ls -la /work/out/libcamera/
INNER
