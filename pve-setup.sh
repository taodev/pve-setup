#!/bin/bash

# cd /root >/dev/null 2>&1

_red() { echo "\033[31m\033[01m$@\033[0m"; }
_green() { echo "\033[32m\033[01m$@\033[0m"; }
_yellow() { echo "\033[33m\033[01m$@\033[0m"; }
_blue() { echo "\033[36m\033[01m$@\033[0m"; }
reading() { read -rp "$(_green "$1")" "$2"; }

backup_suffix="$(date +%Y%m%d).backup"

backup_file() {
    if [ -e $1.backup ]; then 
        echo "$1已经备份"
    else
        cp $1 $1.backup
    fi
}

pve_version=$(pveversion | awk -F"/" '{print $2}')
echo "PVE Version: $pve_version"

_red "step 1: 配置国内dns"
backup_file /etc/resolv.conf
cat > /etc/resolv.conf <<EOF
nameserver 223.5.5.5
nameserver 223.6.6.6
EOF

apt install apt-transport-https ca-certificates
source /etc/os-release

# PVE-换源
_red "step 2: PVE-换源"
backup_file /etc/apt/sources.list
backup_file /etc/apt/sources.list.d/ceph.list
backup_file /etc/apt/sources.list.d/pve-enterprise.list
backup_file /usr/share/perl5/PVE/APLInfo.pm

cat <<EOF
  0: 默认官方源
  1: 科大镜像源
  2: 清华镜像源
EOF
reading "请选择更新源(default 0): " select_source
case $select_source in
1)
    # 科大源
    cat > /etc/apt/sources.list <<EOF
deb https://mirrors.ustc.edu.cn/debian/ $VERSION_CODENAME main contrib non-free non-free-firmware
deb https://mirrors.ustc.edu.cn/debian/ $VERSION_CODENAME-updates main contrib non-free non-free-firmware
# deb https://mirrors.ustc.edu.cn/debian/ $VERSION_CODENAME-backports main contrib non-free non-free-firmware

deb https://mirrors.ustc.edu.cn/debian-security/ $VERSION_CODENAME-security main contrib non-free non-free-firmware
EOF

    # pve subscription
    echo "deb https://mirrors.ustc.edu.cn/proxmox/debian/pve $VERSION_CODENAME pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list

    # CT Templates
    sed -i 's|http://download.proxmox.com|https://mirrors.ustc.edu.cn/proxmox|g' /usr/share/perl5/PVE/APLInfo.pm

    # ceph
    if [ -f /etc/apt/sources.list.d/ceph.list ]; then
        CEPH_CODENAME=`ceph -v | grep ceph | awk '{print $(NF-1)}'`
        echo "deb https://mirrors.ustc.edu.cn/proxmox/debian/ceph-$CEPH_CODENAME $VERSION_CODENAME no-subscription" > /etc/apt/sources.list.d/ceph.list
    fi

    # pve-enterprise.list
    sed -i 's|deb|# deb|g' /etc/apt/sources.list.d/pve-enterprise.list
    ;;
2)
    # 清华源
    cat > /etc/apt/sources.list <<EOF
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ $VERSION_CODENAME main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ $VERSION_CODENAME-updates main contrib non-free non-free-firmware
# deb https://mirrors.tuna.tsinghua.edu.cn/debian/ $VERSION_CODENAME-backports main contrib non-free non-free-firmware

deb https://mirrors.tuna.tsinghua.edu.cn/debian-security $VERSION_CODENAME-security main contrib non-free non-free-firmware
EOF

    # pve subscription
    echo "deb https://mirrors.tuna.tsinghua.edu.cn/proxmox/debian/pve $VERSION_CODENAME pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list

    # CT Templates
    sed -i 's|http://download.proxmox.com|https://mirrors.tuna.tsinghua.edu.cn/proxmox|g' /usr/share/perl5/PVE/APLInfo.pm

    # pve-enterprise.list
    sed -i 's|deb|# deb|g' /etc/apt/sources.list.d/pve-enterprise.list
    ;;
*)
    echo "使用默认官方源"
    ;;
esac

_red "step 2: 更新并安装常用软件"
apt update -y
apt install vim net-tools curl screen lm-sensors linux-cpupower -y
apt dist-upgrade -y

_red "step 3: 直通PCIe设备"
backup_file /etc/default/grub
backup_file /etc/modules

reading "是否直通PCIe设备?(y/N) " direct_pcie
case $direct_pcie in
[yY][eE][sS] | [yY])
    sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT/c\GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt pcie_acs_override=downstream"' /etc/default/grub
    echo -e "vfio\nvfio_iommu_type1\nvfio_pci\nvfio_virqfd" | tee -a /etc/modules
    update-grub
    update-initramfs -u -k all
    ;;
esac

_green "step 4: 去除登陆弹窗"
backup_file /usr/share/pve-manager/js/pvemanagerlib.js
backup_file /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js

sed -i_orig "s/data.status === 'Active'/true/g" /usr/share/pve-manager/js/pvemanagerlib.js
sed -i_orig "s/if (res === null || res === undefined || \!res || res/if(/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
sed -i_orig "s/.data.status.toLowerCase() !== 'active'/false/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
systemctl restart pveproxy
