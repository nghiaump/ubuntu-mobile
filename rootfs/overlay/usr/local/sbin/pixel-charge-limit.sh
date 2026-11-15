#!/bin/sh
# Pixel 3 XL: quản lý sạc (chạy mỗi 30 s). Tài liệu: docs/hardware/power-battery.md
#  1) Giới hạn sạc START..STOP % (server cắm điện 24/7) — patch 0008 (charge_behaviour).
#     inhibit-charge = NGỪNG NẠP pin nhưng USB vẫn cấp điện cho máy (pin đứng yên).
#  2) Sạc nhanh theo bảng gốc của Google (stock dtbo: google,chg-temp-limits / chg-cv-limits / chg-cc-limits,
#     pin 3430 mAh) — patch 0009 (constant_charge_current, trần DT 3 A). Kernel khởi động ở 1 A.
#  3) DEFENDER (giống Battery Defender của Google: >= 4.27 V + >= 35 °C kéo dài 6 h -> xả về 80 %):
#     pin >= DEFEND_STOP % và nóng >= DEFEND_TEMP °C LIÊN TỤC DEFEND_MINUTES phút -> hạ giới hạn về DEFEND_STOP/DEFEND_START,
#     NGẮT nguồn USB vào (status=Unknown -> USBIN_SUSPEND) để máy chạy pin xả về DEFEND_STOP rồi cấp lại.
#     Thoát khi pin nguội <= DEFEND_RELEASE_TEMP °C liên tục DEFEND_RELEASE_MINUTES phút, hoặc rút sạc.
#     Không tính nhiệt lúc đang sạc nhanh ngắn hạn (vài chục phút) nhờ ngưỡng thời gian.
#     AN TOÀN: không bao giờ ngắt nguồn vào khi pin <= DEFEND_STOP; khởi động/dừng dịch vụ luôn cấp lại nguồn vào
#     (ExecStopPost trong pixel-charge-limit.service).
# Cấu hình: /etc/default/pixel-charge-limit
STOP=80; START=75; ENABLE=1; FAST=1; FAST_MAX_MA=3000
DEFEND=1; DEFEND_TEMP=35; DEFEND_MINUTES=60; DEFEND_STOP=80; DEFEND_START=75
DEFEND_RELEASE_TEMP=32; DEFEND_RELEASE_MINUTES=30
[ -r /etc/default/pixel-charge-limit ] && . /etc/default/pixel-charge-limit
B=/sys/class/power_supply/max1720x
C=/sys/class/power_supply/pmi8998-charger
STATE=/run/pixel-charge-defend          # "1" khi đang ở chế độ Defender (giữ qua restart dịch vụ, mất khi reboot)
TICK=30
CAP_MAH=3430
# Bảng Google: hàng = khoảng nhiệt độ (0.1 °C), cột = điện áp pin < 4.20 / < 4.30 / <= 4.40 V, giá trị = % của C
TEMPS="0 100 200 420 460 480 550"
CC_ROWS="30,10,0 50,30,30 100,70,50 80,50,50 50,50,0 30,0,0"

cc_target_ua() {   # $1 = nhiệt độ 0.1 °C, $2 = điện áp µV -> in dòng nạp µA theo bảng
  t=$1; v=$2; row=""; i=0; prev=""
  for th in $TEMPS; do
    if [ -n "$prev" ] && [ "$t" -ge "$prev" ] && [ "$t" -lt "$th" ]; then row=$i; break; fi
    [ -n "$prev" ] && i=$((i + 1)); prev=$th
  done
  [ -z "$row" ] && { echo 0; return; }            # < 0 °C hoặc >= 55 °C: không nạp
  if [ "$v" -lt 4200000 ]; then col=1; elif [ "$v" -lt 4300000 ]; then col=2; else col=3; fi
  pct=$(echo $CC_ROWS | cut -d' ' -f$((row + 1)) | cut -d, -f$col)
  echo $((pct * CAP_MAH * 10))
}

input_resume()  { echo Charging > $C/status 2>/dev/null; suspended=""; }   # vô điều kiện: ghi Charging khi không ngắt cũng vô hại
input_suspend() { echo Unknown > $C/status && suspended=1; }

# Khởi động: luôn cấp lại nguồn vào (phòng lần trước chết khi đang xả)
echo Charging > $C/status 2>/dev/null || true
suspended=""
defend=$(cat $STATE 2>/dev/null || echo 0)
hot=0; cool=0; last=""
while :; do
  if [ -r $B/capacity ] && [ -w $C/charge_behaviour ]; then
    cap=$(cat $B/capacity); t=$(cat $B/temp); v=$(cat $B/voltage_now)
    plugged=$( [ "$(cat $C/online)" = 1 ] || [ -n "$suspended" ] && echo 1 || echo 0 )

    # --- Defender: đếm thời gian nóng/nguội ---
    if [ "$DEFEND" = 1 ] && [ "$ENABLE" = 1 ]; then
      if [ "$cap" -ge "$DEFEND_STOP" ] && [ "$t" -ge $((DEFEND_TEMP * 10)) ]; then hot=$((hot + TICK)); else hot=0; fi
      if [ "$t" -le $((DEFEND_RELEASE_TEMP * 10)) ]; then cool=$((cool + TICK)); else cool=0; fi
      if [ "$defend" != 1 ] && [ "$hot" -ge $((DEFEND_MINUTES * 60)) ]; then
        defend=1; echo 1 > $STATE; echo "DEFENDER BẬT: pin $cap% nóng >= ${DEFEND_TEMP} °C liên tục ${DEFEND_MINUTES} phút -> giữ ${DEFEND_START}-${DEFEND_STOP}%"
      elif [ "$defend" = 1 ] && { [ "$cool" -ge $((DEFEND_RELEASE_MINUTES * 60)) ] || [ "$plugged" = 0 ]; }; then
        defend=0; echo 0 > $STATE; hot=0; input_resume; echo "DEFENDER TẮT: pin nguội <= ${DEFEND_RELEASE_TEMP} °C ${DEFEND_RELEASE_MINUTES} phút hoặc đã rút sạc"
      fi
    elif [ "$defend" = 1 ]; then
      defend=0; echo 0 > $STATE; input_resume
    fi
    if [ "$defend" = 1 ]; then stop=$DEFEND_STOP; start=$DEFEND_START; else stop=$STOP; start=$START; fi

    # --- Xả về mức Defender: ngắt nguồn vào khi pin còn cao hơn ngưỡng; an toàn: cấp lại khi <= ngưỡng ---
    if [ "$defend" = 1 ] && [ "$cap" -gt "$DEFEND_STOP" ] && [ "$(cat $C/online)" = 1 ]; then
      [ -z "$suspended" ] && input_suspend && echo "DEFENDER: ngắt nguồn USB vào, xả từ $cap% về $DEFEND_STOP%"
    elif [ -n "$suspended" ] && { [ "$defend" != 1 ] || [ "$cap" -le "$DEFEND_STOP" ]; }; then
      input_resume; echo "DEFENDER: cấp lại nguồn USB vào ở $cap%"
    fi

    # --- Giới hạn sạc ---
    beh=$(sed -n 's/.*\[\(.*\)\].*/\1/p' $C/charge_behaviour)
    want=$beh
    if [ "$ENABLE" != 1 ]; then want=auto
    elif [ "$cap" -ge "$stop" ]; then want=inhibit-charge
    elif [ "$cap" -le "$start" ]; then want=auto
    fi
    [ "$want" != "$beh" ] && echo "$want" > $C/charge_behaviour
    msg="pin $cap% ${t%?}.${t#${t%?}} °C $((v / 1000)) mV: $want (giới hạn $start-$stop%$( [ "$defend" = 1 ] && echo ', DEFENDER')$( [ -n "$suspended" ] && echo ', đang xả'))"

    # --- Dòng nạp theo bảng Google ---
    if [ -w $C/constant_charge_current ]; then
      max=$(cat $C/constant_charge_current_max)
      if [ "$FAST" = 1 ]; then
        cc=$(cc_target_ua "$t" "$v"); lim=$((FAST_MAX_MA * 1000))
        [ "$cc" -gt "$lim" ] && cc=$lim
      else
        cc=1000000
      fi
      [ "$cc" -gt "$max" ] && cc=$max
      cc=$((cc / 25000 * 25000))              # thanh ghi FCC bước 25 mA
      cur=$(cat $C/constant_charge_current)
      [ "$cc" != "$cur" ] && echo "$cc" > $C/constant_charge_current
      msg="$msg, dòng nạp $((cc / 1000)) mA"
    fi
    key="$want ${cc:-} $defend $suspended"   # chỉ ghi log khi trạng thái đổi
    [ "$key" != "$last" ] && echo "$msg"
    last=$key
  fi
  sleep $TICK
done
