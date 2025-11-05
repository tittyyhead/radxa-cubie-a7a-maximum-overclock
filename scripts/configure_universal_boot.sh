#!/bin/bash

echo "🔧 UNIVERSAL BOOT CONFIGURATION TOOL 🔧"
echo "========================================"
echo "This tool ensures your Radxa can boot from:"
echo "  ✅ SD Card"
echo "  ✅ USB Drive" 
echo "  ✅ NVMe SSD"
echo "  ✅ eMMC"
echo "  ✅ UFS"
echo ""

# Backup current configuration
echo "📋 Backing up current boot configuration..."
sudo cp /boot/extlinux/extlinux.conf /boot/extlinux/extlinux.conf.pre-universal-$(date +%Y%m%d-%H%M%S)

# Create universal boot configuration
echo "🔧 Creating universal boot configuration..."
sudo tee /boot/extlinux/extlinux.conf > /dev/null << 'EOF'
default working
menu title 🚀 RADXA MAXIMUM OVERCLOCK - Universal Storage Boot
prompt 1
timeout 30

# This configuration uses UUID-based root detection
# Works with: SD, USB, NVMe, eMMC, UFS

label working
    menu label ^1 Maximum Overclock (NPU 2520MHz, GPU 1488MHz, CPU 2080MHz)
    linux /boot/vmlinuz-5.15.147-7-a733
    initrd /boot/initrd.img-5.15.147-7-a733
    fdt /boot/radxa-a7a-full-optimized.dtb
    append root=UUID=13cba194-1b8f-44e8-9816-8d3bd0158a23 console=tty1 rootwait rootdelay=3 clk_ignore_unused mac_addr=08:51:49:58:3d:2f mac1_addr=08:51:49:58:3d:2e loglevel=4 rw consoleblank=0 coherent_pool=2M irqchip.gicv3_pseudo_nmi=0 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1 kasan=off

label extended-npu
    menu label ^2 Extended NPU Testing (1200MHz + 1500MHz)
    linux /boot/vmlinuz-5.15.147-7-a733
    initrd /boot/initrd.img-5.15.147-7-a733
    fdt /boot/radxa-a7a-extended-npu.dtb
    append root=UUID=13cba194-1b8f-44e8-9816-8d3bd0158a23 console=tty1 rootwait rootdelay=3 clk_ignore_unused mac_addr=08:51:49:58:3d:2f mac1_addr=08:51:49:58:3d:2e loglevel=4 rw consoleblank=0 coherent_pool=2M irqchip.gicv3_pseudo_nmi=0 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1 kasan=off

label safe
    menu label ^3 Safe Boot (No Overclocking)
    linux /boot/vmlinuz-5.15.147-7-a733
    initrd /boot/initrd.img-5.15.147-7-a733
    fdt /boot/dtbs/allwinner/sun60i-a733-cubie-a7a.dtb
    append root=UUID=13cba194-1b8f-44e8-9816-8d3bd0158a23 console=tty1 rootwait rootdelay=3 clk_ignore_unused mac_addr=08:51:49:58:3d:2f mac1_addr=08:51:49:58:3d:2e loglevel=4 rw consoleblank=0 coherent_pool=2M irqchip.gicv3_pseudo_nmi=0 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1 kasan=off

label debug
    menu label ^4 Debug Boot (Verbose Logging)
    linux /boot/vmlinuz-5.15.147-7-a733
    initrd /boot/initrd.img-5.15.147-7-a733
    fdt /boot/radxa-a7a-full-optimized.dtb
    append root=UUID=13cba194-1b8f-44e8-9816-8d3bd0158a23 console=ttyAS0,115200n8 console=tty1 rootwait rootdelay=3 clk_ignore_unused mac_addr=08:51:49:58:3d:2f mac1_addr=08:51:49:58:3d:2e loglevel=7 rw earlycon consoleblank=0 coherent_pool=2M irqchip.gicv3_pseudo_nmi=0 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1 kasan=off

EOF

echo ""
echo "✅ Universal boot configuration created!"
echo ""
echo "📝 KEY FEATURES:"
echo "  • UUID-based root detection (not device-specific)"
echo "  • rootdelay=3 ensures storage drivers load properly"
echo "  • Works with SD, USB, NVMe, eMMC, UFS automatically"
echo "  • Storage drivers included in initramfs:"
sudo lsinitramfs /boot/initrd.img-5.15.147-7-a733 2>/dev/null | grep -E "(usb-storage|nvme|mmc)" | awk '{print "    ✅ " $0}' | head -5
echo ""
echo "🔍 Verifying configuration..."
if grep -q "rootdelay=3" /boot/extlinux/extlinux.conf; then
    echo "  ✅ rootdelay configured (ensures storage detection)"
fi
if grep -q "UUID=" /boot/extlinux/extlinux.conf; then
    echo "  ✅ UUID-based root detection configured"
fi
echo ""
echo "🎯 Your system is now configured for UNIVERSAL storage boot!"
echo "   It will automatically work with whichever storage device contains"
echo "   the matching UUID (SD, USB, NVMe, eMMC, or UFS)"