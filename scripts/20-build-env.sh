#!/usr/bin/env bash
# Pha 2: dựng image Docker build env + helper chạy lệnh trong container.
#   scripts/20-build-env.sh build            # dựng image pixel-build:noble
#   scripts/20-build-env.sh run <lệnh...>    # chạy lệnh trong container
#   scripts/20-build-env.sh priv <lệnh...>   # như run nhưng --privileged (loop mount, debootstrap)
# Mount: /work = /Volumes/pixelwork (workspace SSD), /repo = repo này (scripts, read-only)
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE=pixel-build:noble
W=/Volumes/pixelwork
cmd="${1:-}"; shift || true
common=(--rm -v "$W:/work" -v "$REPO:/repo:ro" -w /work -e HOME=/work/home)
tty=(-i); [[ -t 0 && -t 1 ]] && tty=(-it)
case "$cmd" in
  build) docker build --platform linux/arm64 -t "$IMAGE" "$REPO/docker" ;;
  run)   mkdir -p "$W/home"; docker run "${common[@]}" ${tty[@]+"${tty[@]}"} "$IMAGE" "$@" ;;
  priv)  mkdir -p "$W/home"; docker run --privileged "${common[@]}" ${tty[@]+"${tty[@]}"} "$IMAGE" "$@" ;;
  *) sed -n '2,6p' "$0"; exit 1 ;;
esac
