#!/bin/bash
# Radxa Cubie A7A - Hybrid Boot Setup Script
# Creates a small SD card for boot files while using USB drive for root filesystem
# This provides maximum storage space with minimal SD card wear

set -e

# Configuration
BOOT_SD_DEVICE=""
USB_DEVICE=""
USB_UUID=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE} Radxa A7A Hybrid Boot Setup${NC}"
    echo -e "${BLUE}================================${NC}"
    echo
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_requirements() {
    print_info "Checking requirements..."
    
    if ! command -v parted &> /dev/null; then
        print_error "parted is required but not installed. Run: sudo apt install parted"
        exit 1
    fi
    
    if ! command -v rsync &> /dev/null; then
        print_error "rsync is required but not installed. Run: sudo apt install rsync"
        exit 1
    fi
    
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

detect_devices() {
    print_info "Detecting storage devices..."
    echo
    echo "Available storage devices:"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E "NAME|disk|part"
    echo
    
    read -p "Enter the SD card device for boot (e.g., /dev/sdb): " BOOT_SD_DEVICE
    read -p "Enter the USB device for root filesystem (e.g., /dev/sda): " USB_DEVICE
    
    if [[ ! -b "$BOOT_SD_DEVICE" ]]; then
        print_error "Boot SD card device $BOOT_SD_DEVICE does not exist"
        exit 1
    fi
    
    if [[ ! -b "$USB_DEVICE" ]]; then
        print_error "USB device $USB_DEVICE does not exist"
        exit 1
    fi
    
    # Get USB root partition UUID
    USB_ROOT_PARTITION="${USB_DEVICE}2"
    if [[ ! -b "$USB_ROOT_PARTITION" ]]; then
        print_error "USB root partition $USB_ROOT_PARTITION does not exist"
        print_info "Please ensure your USB drive has a root filesystem on partition 2"
        exit 1
    fi
    
    USB_UUID=$(blkid -s UUID -o value "$USB_ROOT_PARTITION")
    if [[ -z "$USB_UUID" ]]; then
        print_error "Could not determine UUID of $USB_ROOT_PARTITION"
        exit 1
    fi
    
    print_info "Boot SD Card: $BOOT_SD_DEVICE"
    print_info "USB Root: $USB_ROOT_PARTITION (UUID: $USB_UUID)"
}

confirm_operation() {
    echo
    print_warning "⚠️  WARNING: This will COMPLETELY ERASE the SD card: $BOOT_SD_DEVICE"
    print_warning "⚠️  Make sure you have backed up any important data!"
    echo
    read -p "Are you sure you want to continue? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        print_info "Operation cancelled by user"
        exit 0
    fi
}

create_partitions() {
    print_info "Creating partition table on $BOOT_SD_DEVICE..."
    
    parted "$BOOT_SD_DEVICE" --script \
        mklabel gpt \
        mkpart primary fat16 16MiB 32MiB \
        mkpart primary fat16 32MiB 332MiB \
        mkpart primary ext4 332MiB 100% \
        set 2 boot on
    
    sleep 2
    partprobe "$BOOT_SD_DEVICE"
    sleep 2
    
    print_info "Formatting partitions..."
    mkfs.vfat -F 16 -n "config" "${BOOT_SD_DEVICE}1"
    mkfs.vfat -F 16 -n "efi" "${BOOT_SD_DEVICE}2" 
    mkfs.ext4 -L "bootfs" "${BOOT_SD_DEVICE}3"
}

copy_uboot() {
    print_info "Copying U-Boot bootloader..."
    
    # Copy U-Boot from current system (sectors 256-32768)
    dd if=/dev/mmcblk0 of="$BOOT_SD_DEVICE" bs=512 skip=256 seek=256 count=32512 conv=fsync
    
    print_info "U-Boot copied successfully"
}

copy_boot_files() {
    print_info "Copying boot files..."
    
    mkdir -p /tmp/hybrid_boot_mount
    mount "${BOOT_SD_DEVICE}2" /tmp/hybrid_boot_mount
    
    # Copy all boot files from current system
    rsync -av /boot/ /tmp/hybrid_boot_mount/ --exclude='efi'
    
    # Copy the hybrid boot extlinux.conf
    mkdir -p /tmp/hybrid_boot_mount/extlinux
    cp "$SCRIPT_DIR/extlinux.conf" /tmp/hybrid_boot_mount/extlinux/
    
    # Update UUID in extlinux.conf
    sed -i "s/root=UUID=[^ ]*/root=UUID=$USB_UUID/" /tmp/hybrid_boot_mount/extlinux/extlinux.conf
    
    umount /tmp/hybrid_boot_mount
    rmdir /tmp/hybrid_boot_mount
    
    print_info "Boot files copied and configured"
}

create_minimal_root() {
    print_info "Creating minimal root structure on SD card..."
    
    mkdir -p /tmp/hybrid_root_mount
    mount "${BOOT_SD_DEVICE}3" /tmp/hybrid_root_mount
    
    # Create essential directories
    mkdir -p /tmp/hybrid_root_mount/{dev,proc,sys,run,tmp,media,mnt}
    chmod 1777 /tmp/hybrid_root_mount/tmp
    
    # Create a README
    cat > /tmp/hybrid_root_mount/README.txt << 'EOF'
This is a hybrid boot SD card for Radxa Cubie A7A.

Boot Process:
1. U-Boot loads from this SD card
2. Kernel and DTB load from this SD card  
3. Root filesystem mounts from USB drive

The actual system runs entirely from the USB drive.
This SD card is only used for the initial boot process.
EOF
    
    umount /tmp/hybrid_root_mount
    rmdir /tmp/hybrid_root_mount
}

main() {
    print_header
    check_requirements
    detect_devices
    confirm_operation
    
    print_info "Starting hybrid boot SD card creation..."
    
    create_partitions
    copy_uboot
    copy_boot_files
    create_minimal_root
    
    echo
    print_info "✅ Hybrid boot SD card created successfully!"
    echo
    print_info "Next steps:"
    print_info "1. Shutdown your system: sudo shutdown -h now"
    print_info "2. Remove the old SD card from Radxa"
    print_info "3. Insert the new hybrid boot SD card"
    print_info "4. Keep the USB drive connected"
    print_info "5. Power on - system will boot from SD, run from USB"
    echo
    print_info "Boot Configuration:"
    print_info "- Boot files: SD card (${BOOT_SD_DEVICE}2)"
    print_info "- Root filesystem: USB drive (UUID: $USB_UUID)"
    print_info "- All overclocking settings preserved"
}

main "$@"