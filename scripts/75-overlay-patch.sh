#!/usr/bin/env bash
# Đóng gói rootfs/overlay thành tar (chủ sở hữu root, giữ quyền) để VÁ rootfs đang có trên máy
# mà không cần dựng lại + flash lại userdata. Áp dụng: boot boot-smoke.img rồi chạy scripts/phone/apply-overlay.sh.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
exec "$REPO/scripts/20-build-env.sh" run bash -s <<'INNER'
set -euo pipefail
mkdir -p /work/out/smoke
tar -C /repo/rootfs/overlay --owner=0 --group=0 --numeric-owner -cf /work/out/smoke/overlay.tar .
tar -tvf /work/out/smoke/overlay.tar | awk '{print $1, $2, $6}'
INNER
