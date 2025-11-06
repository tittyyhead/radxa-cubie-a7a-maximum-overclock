# Hybrid Boot Configuration Guide

## Overview
Hybrid boot allows you to use a small SD card (64GB or smaller) for boot files while running the entire root filesystem from a large USB drive. This provides:

- **Maximum Storage**: Use 256GB+ USB drives for your system
- **Minimal SD Wear**: SD card only accessed during boot
- **Full Performance**: System runs entirely from USB 3.0 drive
- **Boot Reliability**: SD card provides reliable boot process

## What You Need

### Hardware
- **Small SD card**: 32GB-64GB (for boot files only)
- **Large USB drive**: 128GB+ (for root filesystem)
- **USB 3.0 recommended** for best performance

### Software
- Working Radxa Cubie A7A system with overclocking
- This repository cloned locally
- Root access (sudo)

## Installation Process

### Step 1: Prepare USB Drive
Your USB drive should already have a working root filesystem. If not:

```bash
# Create partitions on USB drive (/dev/sda)
sudo parted /dev/sda --script \
    mklabel gpt \
    mkpart primary fat16 16MiB 316MiB \
    mkpart primary ext4 316MiB 100%

# Format partitions
sudo mkfs.vfat -F 16 -n "USB_BOOT" /dev/sda1
sudo mkfs.ext4 -L "USB_ROOT" /dev/sda2

# Copy your current system to USB
sudo rsync -av --exclude='/dev/*' --exclude='/proc/*' --exclude='/sys/*' --exclude='/run/*' --exclude='/tmp/*' / /mnt/usb_root/
```

### Step 2: Create Hybrid Boot SD Card

```bash
# Navigate to the boot configs
cd boot-configs/hybrid-boot/

# Run the setup script (will prompt for device selection)
sudo ./create_hybrid_boot.sh
```

The script will:
1. Detect your SD card and USB drive
2. Create GPT partition table on SD card
3. Copy U-Boot bootloader 
4. Copy all boot files (kernel, DTB, initrd)
5. Configure extlinux.conf for USB root
6. Create minimal directory structure

### Step 3: Boot Test

1. **Shutdown**: `sudo shutdown -h now`
2. **Hardware swap**:
   - Remove old SD card from Radxa
   - Insert new hybrid boot SD card
   - Keep USB drive connected
3. **Power on** and verify boot

## Partition Layout

### SD Card (Boot Device)
```
/dev/mmcblk0p1  16-32MB   FAT16   config (unused)
/dev/mmcblk0p2  32-332MB  FAT16   boot files (kernel, DTB, etc)  
/dev/mmcblk0p3  332MB+    ext4    minimal root structure
```

### USB Drive (Root Device)  
```
/dev/sda1       16-316MB  FAT16   boot (optional backup)
/dev/sda2       316MB+    ext4    full root filesystem
```

## Boot Process

1. **BROM** → **U-Boot** (from SD sectors 256-32768)
2. **U-Boot** → loads `extlinux.conf` (from SD partition 2)
3. **extlinux** → loads kernel + DTB (from SD partition 2)  
4. **Kernel** → mounts root filesystem (from USB partition 2 via UUID)
5. **System** → runs entirely from USB drive

## Configuration Files

### extlinux.conf
Located at `/boot/extlinux/extlinux.conf` on SD card:

```
# HYBRID BOOT: SD card for /boot, USB drive for root filesystem
default working
menu title 🚀 RADXA MAXIMUM OVERCLOCK - Hybrid Boot
timeout 30

label working
    menu label ^1 Maximum Overclock (NPU 2520MHz, GPU 1488MHz, CPU 2080MHz)
    linux /boot/vmlinuz-5.15.147-7-a733
    initrd /boot/initrd.img-5.15.147-7-a733
    fdt /boot/radxa-a7a-full-optimized.dtb
    append root=UUID=<USB-ROOT-UUID> console=tty1 rootwait rootdelay=3 ...
```

The UUID automatically points to your USB drive's root partition.

## Advantages

✅ **Space**: Use 256GB+ USB drives vs limited SD card sizes  
✅ **Performance**: USB 3.0 faster than SD card for system operations  
✅ **Reliability**: SD card only used for boot, minimal wear  
✅ **Flexibility**: Easy to swap USB drives with different systems  
✅ **Overclocking**: All custom DTB files and modules preserved  

## Troubleshooting

### Boot Hangs at "Waiting for root device"
- Check USB drive is properly connected
- Verify UUID in extlinux.conf matches USB root partition
- Increase `rootdelay=3` to `rootdelay=10` in extlinux.conf

### SD Card Not Detected  
- Verify SD card is properly seated
- Check partition table with `sudo parted /dev/mmcblk0 print`
- Ensure boot flag is set on partition 2

### USB Drive Not Mounting
- Check USB root filesystem: `sudo fsck /dev/sda2`
- Verify required directories exist: `/dev`, `/proc`, `/sys`, `/run`
- Test manual mount: `sudo mount /dev/sda2 /mnt`

### Performance Issues
- Use USB 3.0 drive and port
- Check USB drive speed: `sudo hdparm -t /dev/sda`
- Monitor with: `iotop -a`

## Technical Details

### U-Boot Location
- **Start**: Sector 256 (128KB offset)
- **End**: Sector 32768 (16MB offset)  
- **Size**: 32512 sectors (16.6MB)
- **Source**: Copied from working mmcblk0

### Boot Sequence
1. BROM loads U-Boot from SD sectors 256-32768
2. U-Boot initializes hardware, MMC, USB
3. U-Boot loads extlinux.conf from SD partition 2
4. extlinux loads kernel/initrd/DTB from SD partition 2
5. Kernel initializes, searches for root UUID on all devices
6. Root filesystem mounts from USB partition 2
7. Init process starts from USB drive

This hybrid approach provides the reliability of SD boot with the performance and capacity of USB storage.