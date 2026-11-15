#!/bin/sh
# Ghi 1 dòng trạng thái điện năng mỗi lần chạy (timer 2 phút) -> /var/log/pixel-power.csv
# Mục đích: điều tra máy cạn pin dù đang cắm sạc (server 24/7). Giữ tối đa 50000 dòng (~2 tháng).
# Kèm /var/log/pixel-tcpm.log: toàn bộ sự kiện USB PD (TCPM), tối đa ~20 MB.
F=/var/log/pixel-power.csv
B=/sys/class/power_supply/max1720x; C=/sys/class/power_supply/pmi8998-charger
R=/sys/kernel/debug/regmap/0-02/registers
[ -s $F ] || echo "time,uptime_s,cap_pct,batt_mA,batt_mV,batt_temp_C,usb_online,chg_status,behaviour,fcc_mA,icl_cfg_mA,icl_eff_mA,chg_state,typec_mode,tcpm_last,cpu_temp_C,load1" > $F
reg() { v=$(grep -m1 "^$1:" $R 2>/dev/null | cut -d' ' -f2); echo $((0x${v:-0})); }
# Log TCPM trong debugfs bị XOÁ khi đọc -> nối toàn bộ phần mới vào file riêng (không trùng lặp)
T=/var/log/pixel-tcpm.log
chunk=$(cat /sys/kernel/debug/usb/tcpm-*/log 2>/dev/null)
[ -n "$chunk" ] && { echo "=== $(date -Iseconds)"; echo "$chunk"; } >> $T
[ -f $T ] && [ "$(stat -c %s $T)" -gt 20000000 ] && { tail -c 10000000 $T > $T.tmp && mv $T.tmp $T; }
tcpm=$(echo "$chunk" | grep -E "state change|Setting voltage" | tail -1 | sed 's/^\[[^]]*\] //; s/,/;/g' | cut -c1-80)
cpu=0
for z in /sys/class/thermal/thermal_zone*; do
  case "$(cat $z/type)" in cpu*|cluster*) t=$(cat $z/temp 2>/dev/null); [ "${t:-0}" -gt "$cpu" ] && cpu=$t;; esac
done
printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
  "$(date -Iseconds)" "$(cut -d. -f1 /proc/uptime)" "$(cat $B/capacity)" "$(( $(cat $B/current_now) / 1000 ))" "$(( $(cat $B/voltage_now) / 1000 ))" \
  "$(( $(cat $B/temp) / 10 ))" "$(cat $C/online)" "$(cat $C/status)" "$(sed -n 's/.*\[\(.*\)\].*/\1/p' $C/charge_behaviour)" \
  "$(( $(cat $C/constant_charge_current) / 1000 ))" "$(( $(reg 1370) * 25 ))" "$(( $(reg 1607) * 25 ))" "$(( $(reg 1006) & 7 ))" \
  "$(cat /sys/class/typec/port0/power_operation_mode 2>/dev/null || echo none)" "$tcpm" "$(( ${cpu:-0} / 1000 ))" "$(cut -d' ' -f1 /proc/loadavg)" >> $F
n=$(wc -l < $F); [ "$n" -gt 50000 ] && { tail -n 40000 $F > $F.tmp && mv $F.tmp $F; }
exit 0
