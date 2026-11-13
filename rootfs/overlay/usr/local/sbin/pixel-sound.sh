#!/bin/sh
# Âm thanh Pixel 3 XL: nạp machine driver (udev không nạp ổn định) + bật đường loa.
# Đường: MultiMedia1 (q6asm) -> QUAT_TDM_RX_0 (q6afe) -> 2x CS35L36 (Left=trên @0x41, Right=dưới @0x40).
# Âm lượng phần cứng cố định vừa phải; âm lượng người dùng (nút Vol+/-) do PipeWire/GNOME điều khiển.
for i in 1 2 3 4 5 6 7 8 9 10; do
    grep -q "Pixel 3 XL" /proc/asound/cards 2>/dev/null && break
    modprobe snd-soc-sdm845 2>/dev/null
    sleep 2
done
grep -q "Pixel 3 XL" /proc/asound/cards || { echo "pixel-sound: không có card âm thanh"; exit 1; }
set_ctl() { amixer -q -c0 cset name="$1" "$2" || echo "pixel-sound: lỗi đặt '$1'"; }
set_ctl "QUAT_TDM_RX_0 Audio Mixer MultiMedia1" on
for s in Left Right; do
    set_ctl "$s Channel Mux" RX1
    # thang 0..912 = -102..+12 dB (816 = 0 dB). 768 = -6 dB: đủ to, chừa an toàn cho loa
    set_ctl "$s Digital PCM Volume" 768
    set_ctl "$s AMP Enable Switch" on
    set_ctl "$s BOOST Enable Switch" on
done
echo "pixel-sound: loa sẵn sàng"
