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
