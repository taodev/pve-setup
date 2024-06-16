# PVE初始化脚本
## PVE版本要求
使用```pveversion | awk -F"/" '{print $2}'```来查看PVE版本
>注意: 目前只针对PVE 8的版本，其它版本兼容性未进行测试，需使用root权限

## 安装
### 使用curl安装
github官方安装
```
bash <(curl -fsSL https://github.com/taodev/pve-setup/raw/main/pve-setup.sh)
```
ghproxy镜像安装
```
bash <(curl -fsSL https://mirror.ghproxy.com/https://github.com/taodev/pve-setup/raw/main/pve-setup.sh)
```

## 功能
- 配置dns(阿里云及谷歌)
- 更换国内镜像源(科大及清华)
- 更新并安装常用软件
- 直通PCIe设备以及核显虚拟化直通
- 去除登陆未订阅对话框
- 配置显示功耗及温度
- 移除local-lvm, 扩容local(root)
>注意: 设置PCIe设备直通后, 需要手动重启

## 扩展
### PVE宿主机设置DHCP获取IP
```
sed -i -e 's/addr/#addr/g' -e 's/gate/#gate/g' -e 's/static/dhcp/g' /etc/network/interfaces
```

## License
©️Copyright 2024 [taodev](https://github.com/taodev). All Right Reserved
