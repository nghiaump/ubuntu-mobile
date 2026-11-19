#!/usr/bin/env bash
# Pha 5: Remote Desktop bằng xrdp (thay GNOME Remote Login).
# Lý do: Windows App (Mac) không dùng thông tin đăng nhập một lần mà GNOME Remote Login gửi kèm server redirection
# (lớp 1 xác thực đúng, lớp 2 hỏi lại với username ngẫu nhiên -> NTLM "MIC verification failed").
# xrdp không dùng redirection; GNOME (Ubuntu) chạy dạng phiên Xorg qua xorgxrdp.
# Dùng: scripts/91-xrdp.sh [host]   (mặc định 172.16.42.1). Đăng nhập: user ubuntu + mật khẩu Linux của user.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
H="${1:-172.16.42.1}"
SSH=(ssh -o UserKnownHostsFile="$REPO/.ssh_known_hosts" -o BatchMode=yes "ubuntu@$H")
"${SSH[@]}" 'bash -s' <<'REMOTE'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
echo "== tắt GNOME Remote Login (nhường cổng 3389)"
sudo grdctl --system rdp disable 2>/dev/null || true
sudo systemctl disable --now gnome-remote-desktop.service 2>/dev/null || true
echo "== cài xrdp + xorgxrdp"
sudo apt-get install -y -q xrdp xorgxrdp >/tmp/xrdp-install.log 2>&1 || { tail -20 /tmp/xrdp-install.log; exit 1; }
sudo adduser xrdp ssl-cert >/dev/null
echo "== phiên GNOME (Ubuntu) cho xrdp"
# startwm.sh của xrdp gọi /etc/X11/Xsession -> đọc ~/.xsessionrc
cat > /home/ubuntu/.xsessionrc <<'EOF'
# Phiên xrdp: GNOME kiểu Ubuntu trên Xorg
export GNOME_SHELL_SESSION_MODE=ubuntu
export XDG_CURRENT_DESKTOP=ubuntu:GNOME
export XDG_SESSION_DESKTOP=ubuntu
export XDG_CONFIG_DIRS=/etc/xdg/xdg-ubuntu:/etc/xdg
export DESKTOP_SESSION=ubuntu
EOF
# Chỉ định rõ phiên (Xsession.options có allow-user-xsession) -> không rơi về phiên "gnome" trơn
printf 'exec gnome-session --session=ubuntu\n' > /home/ubuntu/.xsession
chmod 755 /home/ubuntu/.xsession
# Không cho polkit hỏi mật khẩu khi colord tạo thiết bị màu trong phiên từ xa (lỗi quen thuộc xrdp + GNOME)
sudo install -d -m 755 /etc/polkit-1/rules.d
sudo tee /etc/polkit-1/rules.d/50-xrdp-colord.rules >/dev/null <<'EOF'
polkit.addRule(function(action, subject) {
  if ((action.id == "org.freedesktop.color-manager.create-device" ||
       action.id == "org.freedesktop.color-manager.create-profile" ||
       action.id == "org.freedesktop.color-manager.delete-device" ||
       action.id == "org.freedesktop.color-manager.delete-profile" ||
       action.id == "org.freedesktop.color-manager.modify-device" ||
       action.id == "org.freedesktop.color-manager.modify-profile") &&
      subject.isInGroup("sudo")) {
    return polkit.Result.YES;
  }
});
EOF
echo "== KHÔNG tắt màn hình/ngủ (tắt panel S6E3HA8 làm máy reset sau ~300s: DTS ghi không bật lại được panel)"
F=/etc/gdm3/greeter.dconf-defaults
sudo grep -q "pixel3: không tắt màn hình" $F || printf "\n# pixel3: không tắt màn hình (tắt panel làm máy reset sau ~300s)\n[org/gnome/desktop/session]\nidle-delay=uint32 0\n\n[org/gnome/settings-daemon/plugins/power]\nsleep-inactive-ac-type='nothing'\nsleep-inactive-battery-type='nothing'\npower-button-action='nothing'\nidle-dim=false\n" | sudo tee -a $F >/dev/null
sudo install -d /etc/dconf/db/local.d /etc/dconf/profile
# Mặc định + KHOÁ (locks/) cho mọi phiên người dùng: cấu hình riêng của user không ghi đè được
# (sự cố: phiên GNOME trên máy có idle-delay=60 -> tắt màn hình -> reset). Nút nguồn = nothing (bấm = tắt màn = reset).
printf "[org/gnome/desktop/session]\nidle-delay=uint32 0\n\n[org/gnome/settings-daemon/plugins/power]\nsleep-inactive-ac-type='nothing'\nsleep-inactive-battery-type='nothing'\nidle-dim=false\npower-button-action='nothing'\n\n[org/gnome/desktop/screensaver]\nlock-enabled=false\nubuntu-lock-on-suspend=false\n\n[org/gnome/desktop/lockdown]\ndisable-lock-screen=true\n" | sudo tee /etc/dconf/db/local.d/90-pixel-no-blank >/dev/null
sudo install -d /etc/dconf/db/local.d/locks
printf "/org/gnome/desktop/session/idle-delay\n/org/gnome/settings-daemon/plugins/power/sleep-inactive-ac-type\n/org/gnome/settings-daemon/plugins/power/sleep-inactive-battery-type\n/org/gnome/settings-daemon/plugins/power/idle-dim\n/org/gnome/settings-daemon/plugins/power/power-button-action\n/org/gnome/desktop/screensaver/lock-enabled\n/org/gnome/desktop/screensaver/ubuntu-lock-on-suspend\n/org/gnome/desktop/lockdown/disable-lock-screen\n" | sudo tee /etc/dconf/db/local.d/locks/90-pixel-no-blank >/dev/null
# Pin cạn: UPower mặc định HybridSleep -> ngủ = tắt panel = treo/reset. Tắt máy thay vì ngủ (RUNBOOK §6).
sudo sed -i 's/^CriticalPowerAction=.*/CriticalPowerAction=PowerOff/' /etc/UPower/UPower.conf
# Tắt máy ở 15 % (mặc định 2 %): giữ pin không cạn sâu khi mất nguồn USB lúc vắng người (sự cố 2026-11-19, power-battery.md).
# Phải giữ Low > Critical > Action. Cắm sạc lại -> máy tự boot vào Ubuntu.
sudo sed -i -e 's/^PercentageLow=.*/PercentageLow=20/' -e 's/^PercentageCritical=.*/PercentageCritical=17/' \
  -e 's/^PercentageAction=.*/PercentageAction=15/' /etc/UPower/UPower.conf
# fwupd (kéo theo bởi ubuntu-desktop) dò phân vùng EFI qua udisks -> từng mount modem_b. Vô dụng trên máy này: mask.
sudo systemctl disable --now fwupd-refresh.timer fwupd.service >/dev/null 2>&1 || true
sudo systemctl mask fwupd.service fwupd-refresh.service fwupd-refresh.timer >/dev/null
[ -f /etc/dconf/profile/user ] || printf "user-db:user\nsystem-db:local\n" | sudo tee /etc/dconf/profile/user >/dev/null
sudo dconf update
echo "== GDM tự đăng nhập user ubuntu (tablet; bàn phím ảo không có phím số)"
F=/etc/gdm3/custom.conf; sudo cp -n $F $F.orig
grep -q "^AutomaticLoginEnable" $F || sudo sed -i "/^\[daemon\]/a # pixel3: tự đăng nhập\nAutomaticLoginEnable=true\nAutomaticLogin=ubuntu" $F
sudo systemctl enable --now xrdp xrdp-sesman >/dev/null 2>&1
sudo systemctl restart xrdp xrdp-sesman
sleep 2
systemctl is-active xrdp xrdp-sesman
sudo ss -ltnp | grep -E ":3389 " || echo "!! chưa thấy cổng 3389"
REMOTE
