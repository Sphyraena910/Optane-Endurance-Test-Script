#!/bin/bash

# DESCRIPTION: A simple script for testing write endurance of Intel Optane SSDs after bandwidth throttling.
# Intel implements a firmware-level bandwidth throttling in their SSDs once "Percentage Used" reaches 105, causing endurance tests taking a long time.
# This script bypasses that limitation by repeatedly issuing NVMe Format via nvme-cli to achieve writing, and only checks data integrity sparingly using fio, greatly saving test times.
# It also checks for drive controller reset failures and automatically issues PCI device removals and rescans to try bringing it back online.
# This script is tested on the original Optane Memory and the Optane Memory M10 series, feedbacks from testing other models are welcome!

# DEPENDENCIES: fio, nvme-cli, smartmontools

# USAGE:
    # Make sure that the drive under test is directly connected via PCIe (no USB adapters), and that the newest versions of dependencies are installed.
    # sudo chmod +x ./OPTANE_en.sh
    # sudo ./OPTANE_en.sh

# DISCLAIMER: This script comes with ABSOLUTELY NO WARRANTY, and will perform NVMe Format and fio write tests, which are DATA DESTRUCTIVE in nature.
# Be ABSOLUTELY sure that the selected drive is the correct one, as all data on it will be PERMANENTLY DESTROYED.
# It is also strongly recommended that the drive under test be the only NVMe drive in the system, as the /dev/nvme*n* numbering may change between reboots/PCI device rescans.
# The author is NOT RESPONSIBLE for any data loss/drive failures caused by running this script!

if [ $(id -u) -ne 0 ] # Check for root privileges
    then echo "This script requires root privileges! Use 'sudo ./OPTANE_en.sh' to run as root."
    exit
fi

while :
do
    echo
    lsblk --output NAME,SIZE,MODEL,SERIAL | grep nvme # List all NVMe drives w/ model & serial number
    echo
    read -p "Enter NVMe drive (e.g. /dev/nvme0n1): " drive
    smartctl -i $drive # List selected drive's detailed info using smartmontools
    read -p "Is this correct? All data on this drive will be PERMANENTLY DESTROYED! (y/N) " selection
    if [ $selection = "y" ] || [ $selection = "Y" ]
    then
        break
    fi
done

read -p "Enter the number of format cycles: " total
read -p "Enter the number of cycles between SMART check & fio verify: " check

echo
smartctl -A $drive # Display the drive's SMART Log
nvme intel smart-log-add $drive # Also show Intel's additional NVMe SSD SMART Log w/ nvme-cli

mbsize=$(expr $(lsblk --output SIZE -b -n $drive) / 1000000) # Get the drive's size in bytes and convert it to MB
pciaddr=$(cat /sys/block/${drive:5}/device/address) # Get the drive's PCI address (for preforming PCI device rescans in case of controller reset failures)
gcycle=1

while [ $gcycle -le $total ]
do
    cycle=1
    while [ $cycle -le $check ]
    do
        echo
        echo "Starting cycle $gcycle..."
        nvme format --force $drive # Send NVMe Format command w/o confirmation (note: occasional 'Input/output error' after format is normal)
        mbwritten=$(($mbsize * $gcycle))"MB"
        echo "Format complete! ~$mbwritten written."
        cycle=$(( $cycle + 1 ))
        gcycle=$(( $gcycle + 1 ))
        retries=0
        sleep 1
        while [ $(lsblk --output SIZE -b -n $drive) = 0 ] # Check for controller reset failures (returning 0B capacity)
        do
            if [ $retries = 10 ]
            then
                echo
                echo "Controller reset failed and cannot be brought back online! Manual intervention required!"
                exit
            fi
            echo "Controller reset failed! PCI device rescan triggered..."
            echo 1 > /sys/bus/pci/devices/$pciaddr/remove # Remove PCI device
            sleep 1
            echo 1 > /sys/bus/pci/rescan # Rescan PCI devices
            retries=$(( $retries + 1 ))
            sleep 1
        done
    done
    echo
    smartctl -A $drive
    nvme intel smart-log-add $drive
    echo
    fio -name rand_verify -filename=$drive -ioengine=libaio -direct=1 -size=100% -bs=4k -iodepth=16 -rw=randwrite -verify=crc32 # Perform periodic fio verified random write @Q16T1
done