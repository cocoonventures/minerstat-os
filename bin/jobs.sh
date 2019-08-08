#!/bin/bash
exec 2>/dev/null
echo "Running Clean jobs.."
# Kernel panic auto reboot
sudo su -c "echo 20 >/proc/sys/kernel/panic"
# Remove logs
find '/home/minerstat/minerstat-os/clients/claymore-eth' -name "*log.txt" -type f -delete
sudo find /var/log -type f -name "*.journal" -delete
sudo service rsyslog stop
sudo systemctl disable rsyslog
#echo "Log files deleted"
sudo dmesg -n 1
sudo apt clean
# Apply crontab
sudo su -c "cp /home/minerstat/minerstat-os/core/minerstat /var/spool/cron/crontabs/minerstat"
sudo su -c "chmod 600 /var/spool/cron/crontabs/minerstat"
sudo su -c "chown minerstat /var/spool/cron/crontabs/minerstat"
sudo service cron restart
# Fix Slow start bug
sudo systemctl disable NetworkManager-wait-online.service
sudo sed -i s/"TimeoutStartSec=5min"/"TimeoutStartSec=5sec"/ /etc/systemd/system/network-online.target.wants/networking.service
sudo sed -i s/"timeout 300"/"timeout 5"/ /etc/dhcp/dhclient.conf
# Nvidia PCI_BUS_ID
sudo rm /etc/environment
sudo cp /home/minerstat/minerstat-os/core/environment /etc/environment
export CUDA_DEVICE_ORDER=PCI_BUS_ID
sudo su -c "export CUDA_DEVICE_ORDER=PCI_BUS_ID"
# libc-ares2 && libuv1-dev
# sudo apt-get --yes --force-yes install libcurl3/bionic | grep "install"
# Max performance
#export GPU_FORCE_64BIT_PTR=1 #causes problems
export GPU_USE_SYNC_OBJECTS=1
export GPU_MAX_ALLOC_PERCENT=100
export GPU_SINGLE_ALLOC_PERCENT=100
export GPU_MAX_HEAP_SIZE=100
# .bashrc
sudo cp -fR /home/minerstat/minerstat-os/core/.bashrc /home/minerstat
# rocm for VEGA
export HSA_ENABLE_SDMA=0
# Hugepages (XMR) [Need more test, this required or not]
sudo su -c "echo 128 > /proc/sys/vm/nr_hugepages"
sudo su -c "sysctl -w vm.nr_hugepages=128"
# Fix ERROR Messages
export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
# OpenCL
export OpenCL_ROOT=/opt/amdgpu-pro/lib/x86_64-linux-gnu
# FSCK
sudo sed -i s/"#FSCKFIX=no"/"FSCKFIX=yes"/ /etc/default/rcS
# Change hostname
WNAME=$(cat /media/storage/config.js | grep 'global.worker' | sed 's/global.worker =/"/g' | sed 's/"//g' | sed 's/;//g' | xargs)
sudo sed -i s/"minerstat"/"$WNAME"/ /etc/hosts
if grep -q $WNAME "/etc/hosts"; then
  echo ""
else
  echo " Hostname mismatch - FIXING.. "
  sudo su -c "sed -i '/127.0.1.1/d' /etc/hosts"
  sudo su -c "echo '127.0.1.1   $WNAME' >> /etc/hosts"
fi
sudo su -c "echo '$WNAME' > /etc/hostname"
sudo hostname -F /etc/hostname
#WNAME=$(cat /media/storage/config.js | grep 'global.worker' | sed 's/global.worker =/"/g' | sed 's/"//g' | sed 's/;//g' | xargs)
#sudo sed -i s/"$WNAME"/"minerstat"/ /etc/hosts
#sudo su -c "echo 'minerstat' > /etc/hostname"
#sudo hostname -F /etc/hostname
# CloudFlare DNS
#sudo resolvconf -u
GET_GATEWAY=$(route -n -e -4 | awk {'print $2'} | grep -vE "0.0.0.0|IP|Gateway" | head -n1 | xargs)
# systemd resolve casusing problems with 127.0.0.53
if [ ! -z "$GET_GATEWAY" ]; then
  sudo su -c "echo 'nameserver $GET_GATEWAY' > /run/resolvconf/interface/systemd-resolved"
fi
sudo su -c 'echo "nameserver 1.1.1.1" >> /run/resolvconf/interface/systemd-resolved'
sudo su -c 'echo "nameserver 1.0.0.1" >> /run/resolvconf/interface/systemd-resolved'
sudo su -c 'echo "nameserver 8.8.8.8" >> /run/resolvconf/interface/systemd-resolved'
sudo su -c 'echo "nameserver 8.8.4.4" >> /run/resolvconf/interface/systemd-resolved'
if [ ! -z "$GET_GATEWAY" ]; then
  sudo su -c "echo 'nameserver $GET_GATEWAY' > /run/systemd/resolve/stub-resolv.conf"
fi
sudo su -c 'echo "nameserver 1.1.1.1" >> /run/systemd/resolve/stub-resolv.conf'
sudo su -c 'echo "nameserver 1.0.0.1" >> /run/systemd/resolve/stub-resolv.conf'
sudo su -c 'echo "nameserver 8.8.8.8" >> /run/systemd/resolve/stub-resolv.conf'
sudo su -c 'echo "nameserver 8.8.4.4" >> /run/systemd/resolve/stub-resolv.conf'
sudo su -c 'echo options edns0 >> /run/systemd/resolve/stub-resolv.conf'
# Rewrite
sudo su -c 'echo "" > /etc/resolv.conf'
if [ ! -z "$GET_GATEWAY" ]; then
  sudo su -c "echo 'nameserver $GET_GATEWAY' >> /etc/resolv.conf"
fi
sudo su -c 'echo "nameserver 1.1.1.1" >> /etc/resolv.conf'
sudo su -c 'echo "nameserver 1.0.0.1" >> /etc/resolv.conf'
sudo su -c 'echo "nameserver 8.8.8.8" >> /etc/resolv.conf'
sudo su -c 'echo "nameserver 8.8.4.4" >> /etc/resolv.conf'
# IPV6
sudo su -c 'echo nameserver 2606:4700:4700::1111 >> /etc/resolv.conf'
sudo su -c 'echo nameserver 2606:4700:4700::1001 >> /etc/resolv.conf'
# Memory Info
sudo chmod -R 777 * /home/minerstat/minerstat-os
sudo rm /home/minerstat/minerstat-os/bin/amdmeminfo.txt

if [ -z "$1" ]; then
  AMDDEVICE=$(sudo lshw -C display | grep AMD | wc -l)
fi

# Update motd.d
sudo chmod 777 /etc/update-motd.d/10-help-text
sudo cp /home/minerstat/minerstat-os/core/10-help-text /etc/update-motd.d
# Update tmux design
sudo cp /home/minerstat/minerstat-os/core/.tmux.conf /home/minerstat
# Tmate config
sudo cp /home/minerstat/minerstat-os/core/.tmate.conf /home/minerstat
echo "" | ssh-keygen -N "" &> /dev/null
sudo killall tmate
#/home/minerstat/minerstat-os/bin/tmate -S /tmp/tmate.sock new-session -d
# Update profile
sudo chmod 777 /etc/profile
sudo cp /home/minerstat/minerstat-os/core/profile /etc
# Restart listener, Maintenance Process, Also from now it can be updated in runtime (mupdate)
sudo su -c "screen -S listener -X quit"
sudo su minerstat -c "screen -S listener -X quit"
sudo su minerstat -c "screen -A -m -d -S listener sudo sh /home/minerstat/minerstat-os/core/init.sh"
# Disable UDEVD & JOURNAL
sudo systemctl stop systemd-udevd systemd-udevd-kernel.socket systemd-udevd-control.socket
sudo systemctl disable systemd-udevd systemd-udevd-kernel.socket systemd-udevd-control.socket
sudo su -c "sudo rm -rf /var/log/journal; sudo ln -s /dev/shm /var/log/journal"
sudo systemctl start systemd-journald.service systemd-journald.socket systemd-journald-dev-log.socket
# Create Shortcut for JQ
sudo ln -s /home/minerstat/minerstat-os/bin/jq /sbin &> /dev/null
# Remove ppfeaturemask to avoid kernel panics with old cards
#sudo chmod 777 /boot/grub/grub.cfg && sudo su -c "sed -Ei 's/amdgpu.ppfeaturemask=0xffffffff//g' /boot/grub/grub.cfg" && sudo chmod 444 /boot/grub/grub.cfg
# Restart fan curve if running
FNUM=$(sudo su -c "screen -list | grep -c curve")
if [ "$FNUM" -gt "0" ]; then
echo "Fan curve detected.. restarting"
sudo killall curve
sudo screen -A -m -d -S curve /home/minerstat/minerstat-os/core/curve
fi
# Safety layer
CURVE_FILE=/media/storage/fans.txt
if [ -f "$CURVE_FILE" ]; then
    echo "Fan curve detected.. restarting"
    sudo killall curve
    sleep 2
    sudo killall curve
    sleep 1
    sudo screen -A -m -d -S curve /home/minerstat/minerstat-os/core/curve
fi
# Time Date SYNC
sudo timedatectl set-ntp on &
# Check CURL is installed
ISCURL=$(dpkg -l curl | grep curl | wc -l | sed 's/[^0-9]*//g')
if [ "$ISCURL" -lt 1 ]; then
  sudo apt --yes --force-yes --fix-broken install
  sudo apt-get --yes --force-yes install curl
  NVIDIADEVICE=$(sudo lshw -C display | grep NVIDIA | wc -l)
  if [ "$NVIDIADEVICE" -gt 0 ]; then
    sudo dpkg --remove --force-all libegl1-amdgpu-pro:i386 libegl1-amdgpu-pro:amd64
  fi
fi
# install curl if required
which curl 2>&1 >/dev/null && curlPresent=true
if [ -z "${curlPresent:-}" ]; then
  echo "CURL FIX"
  sudo apt --yes --force-yes --fix-broken install
  sudo apt-get --yes --force-yes install curl libcurl4
  NVIDIADEVICE=$(sudo lshw -C display | grep NVIDIA | wc -l)
  if [ "$NVIDIADEVICE" -gt 0 ]; then
    sudo dpkg --remove --force-all libegl1-amdgpu-pro:i386 libegl1-amdgpu-pro:amd64
  fi
fi
if [ "$1" -gt 0 ] || [ "$AMDDEVICE" -gt 0 ]; then
  #sudo /home/minerstat/minerstat-os/bin/amdmeminfo -s -o -q > /home/minerstat/minerstat-os/bin/amdmeminfo.txt &
  sudo /home/minerstat/minerstat-os/bin/amdmeminfo -s -o -q | tac > /home/minerstat/minerstat-os/bin/amdmeminfo.txt &
  sudo chmod 777 /home/minerstat/minerstat-os/bin/amdmeminfo.txt
fi
# grub fix
GRB=/home/minerstat/minerstat-os/bin/amdmeminfo.txt
if [ -f "$GRB" ]; then
  if grep -q amdgpu.ppfeaturemask "/boot/grub/grub.cfg"; then
    echo ""
  else
    sudo chmod 777 /boot/grub/grub.cfg && sudo su -c "sed -Ei 's/spectre_v2=off/spectre_v2=off amdgpu.ppfeaturemask=0xffffffff/g' /boot/grub/grub.cfg" && sudo chmod 444 /boot/grub/grub.cfg
  fi
fi
if grep -q iommu "/boot/grub/grub.cfg"; then
    echo ""
  else
    sudo chmod 777 /boot/grub/grub.cfg && sudo su -c "sed -Ei 's/spectre_v2=off/spectre_v2=off consoleblank=0 intel_pstate=disable net.ifnames=0 ipv6.disable=1 pci=noaer iommu=soft/g' /boot/grub/grub.cfg" && sudo chmod 444 /boot/grub/grub.cfg
fi
if [ -f "/etc/netplan/minerstat.yaml" ]; then
  if grep -q dhcp-identifier "/etc/netplan/minerstat.yaml"; then
      echo ""
    else
      echo ""
      INTERFACE="$(sudo cat /proc/net/dev | grep -vE lo | tail -n1 | awk -F '\\:' '{print $1}' | xargs)"
      if [ "$INTERFACE" = "eth0" ]; then
        sudo echo "network:" > /etc/netplan/minerstat.yaml
        sudo echo " version: 2" >> /etc/netplan/minerstat.yaml
        sudo echo " renderer: networkd" >> /etc/netplan/minerstat.yaml
        sudo echo " ethernets:" >> /etc/netplan/minerstat.yaml
        sudo echo "   eth0:" >> /etc/netplan/minerstat.yaml
        sudo echo "     dhcp4: yes" >> /etc/netplan/minerstat.yaml
        sudo echo "     dhcp-identifier: mac" >> /etc/netplan/minerstat.yaml
        sudo echo "     dhcp6: no" >> /etc/netplan/minerstat.yaml
        sudo echo "     nameservers:" >> /etc/netplan/minerstat.yaml
        sudo echo "         addresses: [1.1.1.1, 1.0.0.1]" >> /etc/netplan/minerstat.yaml
        sudo /usr/sbin/netplan apply
    fi
  fi
fi
