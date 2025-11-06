#!/bin/bash
# Hybrid Boot Status Checker
# Verifies that hybrid boot is working correctly

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE} Hybrid Boot Status Check${NC}"
    echo -e "${BLUE}================================${NC}"
    echo
}

check_storage() {
    echo -e "${YELLOW}📦 Storage Configuration:${NC}"
    echo
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E "NAME|mmcblk0|sda|MOUNTPOINT"
    echo
    
    # Check if root is on USB
    ROOT_DEVICE=$(df / | grep -v Filesystem | awk '{print $1}')
    if [[ "$ROOT_DEVICE" == *"sda"* ]]; then
        echo -e "${GREEN}✅ Root filesystem on USB drive: $ROOT_DEVICE${NC}"
    elif [[ "$ROOT_DEVICE" == *"mmcblk0"* ]]; then
        echo -e "${RED}❌ Root filesystem on SD card: $ROOT_DEVICE${NC}"
        echo -e "${YELLOW}   This is not hybrid boot - system running from SD${NC}"
    else
        echo -e "${YELLOW}⚠️  Unexpected root device: $ROOT_DEVICE${NC}"
    fi
    
    # Check boot partition
    BOOT_DEVICE=$(df /boot/efi 2>/dev/null | grep -v Filesystem | awk '{print $1}' || echo "Not mounted")
    if [[ "$BOOT_DEVICE" == *"sda"* ]]; then
        echo -e "${GREEN}✅ Boot files on USB: $BOOT_DEVICE${NC}"
    elif [[ "$BOOT_DEVICE" == *"mmcblk0"* ]]; then
        echo -e "${YELLOW}⚠️  Boot files on SD card: $BOOT_DEVICE${NC}"
    else
        echo -e "${YELLOW}⚠️  Boot EFI: $BOOT_DEVICE${NC}"
    fi
}

check_overclocking() {
    echo
    echo -e "${YELLOW}🚀 Overclocking Status:${NC}"
    echo
    
    # Check loaded modules
    LOADED_MODULES=$(lsmod | grep overclock | wc -l)
    if [[ $LOADED_MODULES -gt 0 ]]; then
        echo -e "${GREEN}✅ Overclocking modules loaded:${NC}"
        lsmod | grep overclock
    else
        echo -e "${RED}❌ No overclocking modules loaded${NC}"
    fi
    
    # Check DTB file
    if [[ -f /boot/radxa-a7a-full-optimized.dtb ]]; then
        echo -e "${GREEN}✅ Custom DTB present: radxa-a7a-full-optimized.dtb${NC}"
        DTB_SIZE=$(stat -c%s /boot/radxa-a7a-full-optimized.dtb)
        echo -e "   Size: $((DTB_SIZE/1024))KB"
    else
        echo -e "${RED}❌ Custom DTB not found${NC}"
    fi
}

check_performance() {
    echo
    echo -e "${YELLOW}⚡ Performance Check:${NC}"
    echo
    
    # Storage performance
    ROOT_FS_SIZE=$(df -h / | grep -v Filesystem | awk '{print $2}')
    ROOT_FS_USED=$(df -h / | grep -v Filesystem | awk '{print $3}')
    ROOT_FS_AVAIL=$(df -h / | grep -v Filesystem | awk '{print $4}')
    
    echo -e "${GREEN}💾 Root Filesystem:${NC}"
    echo -e "   Size: $ROOT_FS_SIZE"
    echo -e "   Used: $ROOT_FS_USED"
    echo -e "   Available: $ROOT_FS_AVAIL"
    
    # Memory info
    echo
    echo -e "${GREEN}🧠 Memory:${NC}"
    free -h | head -2
}

check_boot_config() {
    echo
    echo -e "${YELLOW}⚙️  Boot Configuration:${NC}"
    echo
    
    if [[ -f /boot/extlinux/extlinux.conf ]]; then
        echo -e "${GREEN}✅ extlinux.conf found${NC}"
        
        # Check for hybrid boot comment
        if grep -q "HYBRID BOOT" /boot/extlinux/extlinux.conf; then
            echo -e "${GREEN}✅ Hybrid boot configuration detected${NC}"
        fi
        
        # Show root UUID
        ROOT_UUID=$(grep "root=UUID=" /boot/extlinux/extlinux.conf | head -1 | sed 's/.*root=UUID=\([^ ]*\).*/\1/')
        if [[ -n "$ROOT_UUID" ]]; then
            echo -e "${GREEN}✅ Root UUID: $ROOT_UUID${NC}"
            
            # Verify UUID matches current root
            CURRENT_ROOT_UUID=$(lsblk -no UUID $(df / | grep -v Filesystem | awk '{print $1}'))
            if [[ "$ROOT_UUID" == "$CURRENT_ROOT_UUID" ]]; then
                echo -e "${GREEN}✅ Boot config matches current root${NC}"
            else
                echo -e "${YELLOW}⚠️  Boot config UUID differs from current root${NC}"
            fi
        fi
        
        # Show DTB being used
        DTB_FILE=$(grep "fdt /boot/" /boot/extlinux/extlinux.conf | head -1 | awk '{print $2}')
        if [[ -n "$DTB_FILE" ]]; then
            echo -e "${GREEN}✅ DTB file: $DTB_FILE${NC}"
        fi
    else
        echo -e "${RED}❌ extlinux.conf not found${NC}"
    fi
}

main() {
    print_header
    check_storage
    check_overclocking  
    check_performance
    check_boot_config
    
    echo
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE} Check complete!${NC}"
    echo -e "${BLUE}================================${NC}"
}

main "$@"