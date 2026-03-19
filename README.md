English (OPTANE_en.sh):
A simple script for testing write endurance of Intel Optane SSDs after bandwidth throttling.

Intel implements a firmware-level bandwidth throttling in their SSDs once "Percentage Used" reaches 105, causing endurance tests taking a long time. This script bypasses that limitation by repeatedly issuing NVMe Format via nvme-cli to achieve writing, and only checks data integrity sparingly using fio, greatly saving test times. It also checks for drive controller reset failures and automatically issues PCI device removals and rescans to try bringing it back online.

This script is tested on the original Optane Memory and the Optane Memory M10 series, feedbacks from testing other models are welcome!

Dependencies: fio, nvme-cli, smartmontools

Usage:
  1. Make sure that the drive under test is directly connected via PCIe (no USB adapters), and that the newest versions of dependencies are installed.
  2. sudo chmod +x ./OPTANE_en.sh
  3. sudo ./OPTANE_en.sh

DISCLAIMER: This script comes with ABSOLUTELY NO WARRANTY, and will perform NVMe Format and fio write tests, which are DATA DESTRUCTIVE in nature. Be ABSOLUTELY sure that the selected drive is the correct one, as all data on it will be PERMANENTLY DESTROYED.
It is also strongly recommended that the drive under test be the only NVMe drive in the system, as the /dev/nvme*n* numbering may change between reboots/PCI device rescans.
The author is NOT RESPONSIBLE for any data loss/drive failures caused by running this script!

中文版 (OPTANE_zh.sh):
傲腾写入耐久度测试脚本，可绕过限速问题

由于牙膏厂在自家SSD的"已用寿命百分比"达到105后会触发固件层面的写入限速, 因此导致一般的耐久度测试耗时非常久
此脚本使用nvme-cli工具重复进行NVMe Format以达成写入效果, 仅偶尔进行耗时更长的fio数据完整性测试, 从而大大缩减测试时长
傲腾在格式化后有小概率掉线, 脚本在检测到掉线时会自动尝试移除并重新扫描PCI设备

本脚本已经在初代以及M10加速条上测试过, 欢迎提供其他傲腾型号的测试反馈!

依赖包: fio, nvme-cli, smartmontools

使用方法:
  1. 首先确保硬盘通过PCIe直连电脑 (请勿使用USB桥接), 并安装最新的依赖包
  2. sudo chmod +x ./OPTANE_zh.sh
  3. sudo ./OPTANE_zh.sh

叠甲: 此脚本是作者写着玩的, 不提供任何技术支持
在测试前请务必再三确认选中的硬盘是否正确, 脚本进行的NVMe Format及fio写入测试会彻底擦除测试盘上的所有数据且无法恢复!
由于 /dev/nvme*n* 编号有可能在重启/重新扫描PCI设备时变化, 强烈建议测试系统只接入待测盘这一个NVMe硬盘 (使用SATA或U盘启动系统)
作者对运行本脚本可能导致的任何数据丢失/硬盘损坏不负责!
