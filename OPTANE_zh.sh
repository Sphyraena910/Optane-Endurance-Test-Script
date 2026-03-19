#!/bin/bash

# 简介: 傲腾写入耐久度测试脚本，可绕过限速问题
# 由于牙膏厂在自家SSD的"已用寿命百分比"达到105后会触发固件层面的写入限速, 因此导致一般的耐久度测试耗时非常久
# 此脚本使用nvme-cli工具重复进行NVMe Format以达成写入效果, 仅偶尔进行耗时更长的fio数据完整性测试, 从而大大缩减测试时长
# 傲腾在格式化后有小概率掉线, 脚本在检测到掉线时会自动尝试移除并重新扫描PCI设备
# 本脚本已经在初代以及M10加速条上测试过, 欢迎提供其他傲腾型号的测试反馈!

# 依赖包: fio, nvme-cli, smartmontools

# 使用方法:
    # 首先确保硬盘通过PCIe直连电脑 (请勿使用USB桥接), 并安装最新的依赖包
    # sudo chmod +x ./OPTANE_zh.sh
    # sudo ./OPTANE_zh.sh

# 叠甲: 此脚本是作者写着玩的, 不提供任何技术支持
# 在测试前请务必再三确认选中的硬盘是否正确, 脚本进行的NVMe Format及fio写入测试会彻底擦除测试盘上的所有数据且无法恢复!
# 由于 /dev/nvme*n* 编号有可能在重启/重新扫描PCI设备时变化, 强烈建议测试系统只接入待测盘这一个NVMe硬盘 (使用SATA或U盘启动系统)
# 作者对运行本脚本可能导致的任何数据丢失/硬盘损坏不负责!

if [ $(id -u) -ne 0 ] # 检测root权限
    then echo "请使用 'sudo ./OPTANE_zh.sh' 以root身份运行此脚本!"
    exit
fi

while :
do
    echo
    lsblk --output NAME,SIZE,MODEL,SERIAL | grep nvme # 显示所有NVMe硬盘
    echo
    read -p "输入要测试的硬盘 (例如: /dev/nvme0n1): " drive
    smartctl -i $drive # 使用smartmontools显示选中硬盘的详细信息
    read -p "请再次确认, 此硬盘上的所有数据将被永久清除! (y/N) " selection
    if [ $selection = "y" ] || [ $selection = "Y" ]
    then
        break
    fi
done

read -p "请输入格式化圈数: " total
read -p "请输入每隔几圈进行一次SMART检测与fio数据完整性测试: " check

echo
smartctl -A $drive # 显示硬盘SMART
nvme intel smart-log-add $drive # 使用nvme-cli显示隐藏SMART项目

mbsize=$(expr $(lsblk --output SIZE -b -n $drive) / 1000000) # 获取硬盘大小并转换为MB
pciaddr=$(cat /sys/block/${drive:5}/device/address) # 获取硬盘PCI地址 (硬盘掉线时可尝试移除并重新扫描PCI设备)
gcycle=1

while [ $gcycle -le $total ]
do
    cycle=1
    while [ $cycle -le $check ]
    do
        echo
        echo "开始第 $gcycle 圈格式化..."
        nvme format --force $drive # 发送NVMe Format指令 (注: 格式化偶尔报错'Input/output error'是正常情况)
        mbwritten=$(($mbsize * $gcycle))"MB"
        echo "格式化完成! 已写入约 $mbwritten"
        cycle=$(( $cycle + 1 ))
        gcycle=$(( $gcycle + 1 ))
        retries=0
        sleep 1
        while [ $(lsblk --output SIZE -b -n $drive) = 0 ] # 检测硬盘是否掉线
        do
            if [ $retries = 10 ]
            then
                echo
                echo "硬盘掉线且无法重新上线!"
                exit
            fi
            echo "检测到硬盘掉线! 尝试重新扫描PCI设备..."
            echo 1 > /sys/bus/pci/devices/$pciaddr/remove # 移除PCI设备
            sleep 1
            echo 1 > /sys/bus/pci/rescan # 重新扫描PCI设备
            retries=$(( $retries + 1 ))
            sleep 1
        done
    done
    echo
    smartctl -A $drive
    nvme intel smart-log-add $drive
    echo
    fio -name rand_verify -filename=$drive -ioengine=libaio -direct=1 -size=100% -bs=4k -iodepth=16 -rw=randwrite -verify=crc32 # 进行定期fio数据完整性测试 @Q16T1
done