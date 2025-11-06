#!/bin/bash
# USB Drive Preparation Script for Hybrid Boot
# Prepares a USB drive with proper partitions and root filesystem

set -e

USB_DEVICE=""
SOURCE_ROOT="/"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

main() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE} USB Drive Preparation for Hybrid Boot${NC}"
    echo -e "${BLUE}================================${NC}"
    echo

    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi

    echo "Available storage devices:"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E "NAME|disk"
    echo
    
    read -p "Enter USB device to prepare (e.g., /dev/sda): " USB_DEVICE
    
    if [[ ! -b "$USB_DEVICE" ]]; then
        print_error "Device $USB_DEVICE does not exist"
        exit 1
    fi

    print_warning "⚠️  This will ERASE all data on $USB_DEVICE"
    read -p "Continue? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        print_info "Operation cancelled"
        exit 0
    fi

    print_info "Creating partitions on $USB_DEVICE..."
    parted "$USB_DEVICE" --script \
        mklabel gpt \
        mkpart primary fat16 16MiB 316MiB \
        mkpart primary ext4 316MiB 100%

    sleep 2
    partprobe "$USB_DEVICE"
    sleep 2

    print_info "Formatting partitions..."
    mkfs.vfat -F 16 -n "USB_BOOT" "${USB_DEVICE}1"
    mkfs.ext4 -L "USB_ROOT" "${USB_DEVICE}2"

    print_info "Creating mount point..."
    mkdir -p /mnt/usb_root
    mount "${USB_DEVICE}2" /mnt/usb_root

    print_info "Copying root filesystem... (this may take a while)"
    rsync -av \
        --exclude='/dev/*' \
        --exclude='/proc/*' \
        --exclude='/sys/*' \
        --exclude='/run/*' \
        --exclude='/tmp/*' \
        --exclude='/mnt/*' \
        --exclude='/media/*' \
        --exclude='/boot/efi' \
        "$SOURCE_ROOT" /mnt/usb_root/

    print_info "Creating essential directories..."
    mkdir -p /mnt/usb_root/{dev,proc,sys,run,tmp,media,mnt}
    chmod 1777 /mnt/usb_root/tmp

    print_info "Getting USB UUID..."
    umount /mnt/usb_root
    USB_UUID=$(blkid -s UUID -o value "${USB_DEVICE}2")
    
    print_info "✅ USB drive prepared successfully!"
    echo
    print_info "USB Root UUID: $USB_UUID"
    print_info "Next: Run create_hybrid_boot.sh to create the boot SD card"
}

main "$@"