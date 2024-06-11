#!/bin/bash

# cd /root >/dev/null 2>&1

_red() { echo "$@"; }
_green() { echo "$@"; }
_yellow() { echo "$@"; }
_blue() { echo "$@"; }
reading() { read -rp "$1" "$2"; }

backup_suffix="$(date +%Y%m%d).backup"

backup_file() {
    if [ ! -f $1.backup ]; then 
        cp $1 $1.backup
    fi
}

restore_file() {
    if [ -f $1.backup ]; then 
        cp -f $1.backup $1 
    fi
}

pve_version=$(pveversion | awk -F"/" '{print $2}')
echo "PVE Version: $pve_version"

resolvconf=/etc/resolv.conf

sourceslist=/etc/apt/sources.list
pvenosubscriptlist=/etc/apt/sources.list.d/pve-no-subscription.list
cephlist=/etc/apt/sources.list.d/ceph.list
pveenterpriselist=/etc/apt/sources.list.d/pve-enterprise.list

grubconf=/etc/default/grub
modulesconf=/etc/modules

aplinfopm=/usr/share/perl5/PVE/APLInfo.pm
pvemanagerlibjs=/usr/share/pve-manager/js/pvemanagerlib.js
nodespm=/usr/share/perl5/PVE/API2/Nodes.pm
proxmoxlibjs=/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js

# 是否需要重启pveproxy
restart_pveproxy=0

backup_file $resolvconf
backup_file $sourceslist
backup_file $grubconf
backup_file $modulesconf
backup_file $aplinfopm
backup_file $pvemanagerlibjs
backup_file $nodespm
backup_file $proxmoxlibjs

_red "step 1: 配置国内dns"
cat <<EOF
  0: 跳过
  1: 阿里云DNS
  2: 谷歌DNS
  3: 恢复默认
EOF
reading "请选择DNS(默认跳过): " select_dns
case $select_dns in
1)
    cat > $resolvconf <<EOF
nameserver 223.5.5.5
nameserver 223.6.6.6
EOF
    ;;
2)
    cat > $resolvconf <<EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
    ;;
3)
    restore_file $resolvconf
    ;;
esac

apt install apt-transport-https ca-certificates
source /etc/os-release
CEPH_CODENAME=`ceph -v | grep ceph | awk '{print $(NF-1)}'`

# PVE-换源
_red "step 2: PVE-换源"
cat <<EOF
  0: 跳过
  1: 科大镜像源
  2: 清华镜像源
  3: 恢复官方源
EOF
reading "请选择更新源(默认跳过): " select_source
case $select_source in
1)
    # 科大源
    cat > $sourceslist <<EOF
deb https://mirrors.ustc.edu.cn/debian/ $VERSION_CODENAME main contrib non-free non-free-firmware
deb https://mirrors.ustc.edu.cn/debian/ $VERSION_CODENAME-updates main contrib non-free non-free-firmware
#deb https://mirrors.ustc.edu.cn/debian/ $VERSION_CODENAME-backports main contrib non-free non-free-firmware

deb https://mirrors.ustc.edu.cn/debian-security/ $VERSION_CODENAME-security main contrib non-free non-free-firmware

deb https://mirrors.ustc.edu.cn/proxmox/debian/ceph-$CEPH_CODENAME $VERSION_CODENAME no-subscription
EOF

    # pve subscription
    echo "deb https://mirrors.ustc.edu.cn/proxmox/debian/pve $VERSION_CODENAME pve-no-subscription" > $pvenosubscriptlist

    # CT Templates
    sed -i 's|http://download.proxmox.com|https://mirrors.ustc.edu.cn/proxmox|g' $aplinfopm
    sed -i 's|https://mirrors.tuna.tsinghua.edu.cn/proxmox|https://mirrors.ustc.edu.cn/proxmox|g' $aplinfopm

    # ceph
    sed -i 's|^deb http|#deb http|g' $cephlist

    # pve-enterprise.list
    sed -i 's|^deb http|#deb http|g' $pveenterpriselist
    ;;
2)
    # 清华源
    cat > $sourceslist <<EOF
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ $VERSION_CODENAME main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ $VERSION_CODENAME-updates main contrib non-free non-free-firmware
#deb https://mirrors.tuna.tsinghua.edu.cn/debian/ $VERSION_CODENAME-backports main contrib non-free non-free-firmware

deb https://mirrors.tuna.tsinghua.edu.cn/debian-security $VERSION_CODENAME-security main contrib non-free non-free-firmware

deb https://mirrors.ustc.edu.cn/proxmox/debian/ceph-$CEPH_CODENAME $VERSION_CODENAME no-subscription
EOF

    # pve subscription
    echo "deb https://mirrors.tuna.tsinghua.edu.cn/proxmox/debian/pve $VERSION_CODENAME pve-no-subscription" > $pvenosubscriptlist

    # CT Templates
    sed -i 's|http://download.proxmox.com|https://mirrors.tuna.tsinghua.edu.cn/proxmox|g' $aplinfopm
    sed -i 's|https://mirrors.ustc.edu.cn/proxmox|https://mirrors.tuna.tsinghua.edu.cn/proxmox|g' $aplinfopm

    # ceph
    sed -i 's|^deb http|#deb http|g' $cephlist

    # pve-enterprise.list
    sed -i 's|^deb http|#deb http|g' $pveenterpriselist
    ;;
3)
    # 官方源
    # sources.list
    restore_file $sourceslist

    # pve-no-subscription.list
    rm -f $pvenosubscriptlist

    # CT Templates
    sed -i 's|https://mirrors.tuna.tsinghua.edu.cn/proxmox|http://download.proxmox.com|g' $aplinfopm
    sed -i 's|https://mirrors.ustc.edu.cn/proxmox|http://download.proxmox.com|g' $aplinfopm

    # ceph
    sed -i 's|^#deb http|deb http|g' $cephlist

    # pve-enterprise.list
    sed -i 's|^#deb http|deb http|g' $pveenterpriselist
    ;;
esac

_red "step 2: 更新并安装常用软件"
apt update -y
apt install vim net-tools curl screen lm-sensors linux-cpupower -y
apt dist-upgrade -y

_red "step 3: 直通PCIe设备"
cat <<EOF
  0: 跳过
  1: 恢复默认
  2: 直通PCIe设备
  3: 直通PCIe设备及核显(暂时不支持直通核显)
EOF
reading "请选择设置(默认跳过): " direct_pcie
case $direct_pcie in
1)
    restore_file $grubconf
    restore_file $modulesconf
    update-grub
    update-initramfs -u -k all
    ;;
2)
    sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT/c\GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt pcie_acs_override=downstream"' $grubconf
    echo -e "vfio\nvfio_iommu_type1\nvfio_pci\nvfio_virqfd" | tee -a $modulesconf
    update-grub
    update-initramfs -u -k all

    echo "直通PCIe设备完成"
    ;;
3)
    sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT/c\GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt pcie_acs_override=downstream"' $grubconf
    echo -e "vfio\nvfio_iommu_type1\nvfio_pci\nvfio_virqfd" | tee -a $modulesconf
    update-grub
    update-initramfs -u -k all

    echo "直通PCIe设备完成"
    echo "暂不支持直通核显"
    ;;
esac

_green "step 4: 去除登陆弹窗"
cat <<EOF
  0: 跳过
  1: 去除登陆弹窗
EOF
reading "请选择设置(默认跳过): " select_subscription
case $select_subscription in
1)
    sed -i "s/data.status === 'Active'/true/g" $pvemanagerlibjs
    sed -i "s/if (res === null || res === undefined || \!res || res/if(/g" $proxmoxlibjs
    sed -i "s/.data.status.toLowerCase() !== 'active'/false/g" $proxmoxlibjs
    restart_pveproxy=1
    ;;
esac

pve_setup_web="https://github.com/taodev/pve-setup"

setup_ui() {
    if ! command -v sensors > /dev/null; then
        echo "你需要先安装 lm-sensors 和 linux-cpupower, 尝试自动安装"
        if apt update ; apt install -y lm-sensors linux-cpupower; then 
            echo "lm-sensors linux-cpupower安装成功"
        else
            echo "安装所需依赖失败, 请手动安装"
            exit 1
        fi
    fi

    modprobe msr
    echo msr > /etc/modules-load.d/turbostat-msr.conf
    chmod +s /usr/sbin/turbostat

    content_nodespm=/tmp/.content_nodespm
    cat > $content_nodespm << 'EOF'

    # https://github.com/taodev/pve-setup
    # begin taodev/pve-setup
    my $cpupowers = `turbostat -S -q -s PkgWatt -i 0.1 -n 1 -c package | grep -v PkgWatt`;
	my $cpufreqs = `lscpu | grep MHz`;
	$res->{cpu_info} = $cpupowers . $cpufreqs;

    $res->{sensors_info} = `sensors`;
    # end taodev/pve-setup
EOF

    echo "修改nodes.pm"
    if ! grep -q 'taodev/pve-setup' $nodespm ;then
        if [ "$(sed -n "/PVE::pvecfg::version_text()/{=;p;q}" "$nodespm")" ];then #确认修改点
            sed -i "/PVE::pvecfg::version_text()/{
			    r $content_nodespm
		    }" $nodespm

            sed -n "/PVE::pvecfg::version_text()/,+5p" $nodespm
        else
            echo "找不到nodes.pm文件的修改点"
            exit 1
        fi
    else
        echo "已经修改过"
    fi

    content_pvemanagerlibjs=/tmp/.content_pvemanagerlibjs
    cat > $content_pvemanagerlibjs << 'EOF'

    // https://github.com/taodev/pve-setup
    // begin taodev/pve-setup
    {
        itemId: 'cpu-info',
	    colspan: 2,
	    printBar: false,
	    title: gettext('CPU'),
	    textField: 'cpu_info',
	    renderer: function(value) {
            value = value.replace(/Â/g, '');
	        let data = [];
	        let cpuinfos = value.matchAll(/^((?:[a-z]|(?:\d|\.)|CPU|cpu)[\s\S]*)+/gm);
	        for (const cpuinfo of cpuinfos) {
	            let cpuNumber = 0;
	            data[cpuNumber] = {
	                    freqs: [],
	                    scalings: [],
	                    minfreqs: [],
	                    maxfreqs: [],
	                    powers: []
	            };
	            
	            let freqs = cpuinfo[1].matchAll(/^CPU *MHz[^\d]+(.*)$/gm);
	            for (const freq of freqs) {
	                data[cpuNumber]['freqs'].push(freq[1]);
	            }

	            let scalings = cpuinfo[1].matchAll(/^CPU\(s\) *scaling *MHz[^\d]+(\d+).*$/gm);
	            for (const scaling of scalings) {
	                data[cpuNumber]['scalings'].push(scaling[1]);
	            }

	            let minfreqs = cpuinfo[1].matchAll(/^CPU *min *MHz[^\d]+(\d+).*$/gm);
	            for (const minfreq of minfreqs) {
	                data[cpuNumber]['minfreqs'].push(minfreq[1]);
	            }

	            let maxfreqs = cpuinfo[1].matchAll(/^CPU *max *MHz[^\d]+(\d+).*$/gm);
	            for (const maxfreq of maxfreqs) {
	                data[cpuNumber]['maxfreqs'].push(maxfreq[1]);
	            }
	            let powers = cpuinfo[1].matchAll(/^(\d(?:\d|\.)*)$/gm);
	            for (const power of powers) {
	                data[cpuNumber]['powers'].push(power[1]);
	            }
	        }

	        let output = '';
	        for (const [i, cpuinfo] of data.entries()) {
	            
	            if (cpuinfo.freqs.length > 0) {
	                for (const cpuinfofreq of cpuinfo.freqs) {
	                    output += `主频: ${cpuinfofreq} Mhz | `;
	                }
	            } else if (cpuinfo.scalings.length > 0 && cpuinfo.maxfreqs.length > 0) {
	                for (const cpuinfoscaling of cpuinfo.scalings) {
	                    var cpuscaling = `${cpuinfoscaling}`;
	                }
	                for (const cpuinfomaxfreq of cpuinfo.maxfreqs) {
	                    var cpumaxfreq = `${cpuinfomaxfreq}`;
	                }
	                var cpuinfofreq = `${cpumaxfreq}` * `${cpuscaling}` / 100;
	                output += `主频: ${cpuinfofreq} Mhz | `;
	            }
	            if (cpuinfo.powers.length > 0) {
	                for (const cpuinfopower of cpuinfo.powers) {
	                    output += `功率: ${cpuinfopower} W | `;
	                }
	            }
	            if (output) {
	                output = output.slice(0, -2);
	            }
	            
	        }
	        return output.replace(/\n/g, '<br>');
        }
    },
    {
	    itemId: 'sensors-info',
	    colspan: 2,
	    printBar: false,
	    title: gettext('传感器'),
	    textField: 'sensors_info',
	    renderer: function(value) {
	        value = value.replace(/Â/g, '');
	        let data = [];
	        let cpus = value.matchAll(/^(?:coretemp-isa|k10temp-pci)-(\w{4})$\n.*?\n((?:Package|Core|Tctl)[\s\S]*?^\n)+/gm);
	        for (const cpu of cpus) {
	            let cpuNumber = parseInt(cpu[1], 10);
	            data[cpuNumber] = {
	                    packages: [],
	                    cores: []
	            };
	            
	            let packages = cpu[2].matchAll(/^(?:Package id \d+|Tctl):\s*\+([^°C ]+).*$/gm);
	            for (const package of packages) {
	                data[cpuNumber]['packages'].push(package[1]);
	            }
	            let cores = cpu[2].matchAll(/^Core (\d+):\s*\+([^°C ]+).*$/gm);
	            for (const core of cores) {
					var corecombi = `核心 ${core[1]}: ${core[2]}°C`
	                data[cpuNumber]['cores'].push(corecombi);
	            }
	        }

	        let output = '';
	        for (const [i, cpu] of data.entries()) {

	            if (cpu.packages.length > 0) {
	                for (const packageTemp of cpu.packages) {
	                    output += `CPU ${i}: ${packageTemp}°C | `;
	                }
	            }


	            let acpitzs = value.matchAll(/^acpitz-acpi-(\d*)$\n.*?\n((?:temp)[\s\S]*?^\n)+/gm);
	            for (const acpitz of acpitzs) {
	                let acpitzNumber = parseInt(acpitz[1], 10);
	                data[acpitzNumber] = {
	                    acpisensors: []
	                };

	                let acpisensors = acpitz[2].matchAll(/^temp\d+:\s*\+([^°C ]+).*$/gm);
	                for (const acpisensor of acpisensors) {
	                    data[acpitzNumber]['acpisensors'].push(acpisensor[1]);
	                }

	                for (const [k, acpitz] of data.entries()) {
	                    if (acpitz.acpisensors.length > 0) {
	                        output += '主板: ';
	                        for (const acpiTemp of acpitz.acpisensors) {
	                            output += `${acpiTemp}°C, `;
	                        }
	                        output = output.slice(0, -2);
	                        output += ' | ';
	                    } else {
	                        output = output.slice(0, -2);
	                    }
	                }
	            }

	            output = output.slice(0, -2);

	            // if (cpu.cores.length > 4) {
	            //    output += '\n';
	            //    for (j = 1;j < cpu.cores.length;) {
	            //        for (const coreTemp of cpu.cores) {
	            //            output += `${coreTemp} | `;
	            //            j++;
	            //            if ((j-1) % 4 == 0){
	            //                output = output.slice(0, -2);
	            //                output += '\n';
	            //            }
	            //        }
	            //    }
	            //    output = output.slice(0, -2);
	            // }
	            output += '\n';
	        }

	        output = output.slice(0, -2);
	        // return output.replace(/\n/g, '<br>');
            return output.replace(/\n/g, '| ');
	    }
	},
    // end taodev/pve-setup
EOF

    echo "修改pvemanagerlib.js"
    if ! grep -q 'taodev/pve-setup' $pvemanagerlibjs ;then
        if [ "$(sed -n '/pveversion/,+3{
                /},/{=;p;q}
            }' $pvemanagerlibjs)" ];then 
            
            sed -i "/pveversion/,+3{
                /},/r $content_pvemanagerlibjs
            }" $pvemanagerlibjs
            
            sed -n "/pveversion/,+8p" $pvemanagerlibjs
        else
            echo '找不到pvemanagerlib.js文件的修改点'
            exit 1
        fi
    else 
        echo "已经修改过"
    fi
}

_green "step 5: 配置显示功耗及温度"
cat <<EOF
  0: 跳过
  1: 恢复默认
  2: 显示功耗及温度
EOF
reading "请选择设置(默认跳过): " select_ui
case $select_ui in
1)
    restore_file $nodespm
    restore_file $pvemanagerlibjs
    restart_pveproxy=1
    ;;
2)
    setup_ui

    restart_pveproxy=1
    ;;
esac

_green "step 6: 移除local-lvm"
cat <<EOF
  0: 跳过
  2: 移除local-lvm, 扩容local
EOF
reading "请选择设置(默认跳过): " remove_local_lvm
case $select_ui in
1)
    lvremove -y /dev/pve/data
    lvextend -rl +100%FREE /dev/pve/root
    echo "删除local-lvm并扩容local, 需要手动在数据中心->存储, 移除local-lvm"
    ;;
esac

if [ $restart_pveproxy -eq 1 ]; then 
    echo "重启pveproxy"
    systemctl restart pveproxy
fi
