#!/bin/sh
# Lần boot đầu: nới ext4 cho đầy phân vùng userdata (online resize).
set -e
ROOTDEV=$(findmnt -n -o SOURCE /)
echo "resize2fs $ROOTDEV"
resize2fs "$ROOTDEV"
mkdir -p /var/lib/pixel && touch /var/lib/pixel/firstboot-done
