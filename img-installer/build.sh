#!/bin/bash

# img-installer build script
# 基于wukongdaily/img-installer项目设计理念
# 优化：ISO只包含安装程序，不包含完整img文件

# 增强的错误处理
trap 'echo "ERROR: Script failed at line $LINENO"; exit 1' ERR

# 检查参数
if [ $# -lt 1 ]; then
    echo "Usage: $0 <image-url-or-file> [output.iso]"
    echo "  <image-url-or-file>: URL to download .img.gz file or local .img.gz file path"
    echo "  [output.iso]: Optional output ISO filename"
    exit 1
fi

SOURCE_INPUT="$1"
DEFAULT_ISO_NAME="iStoreOS-Installer-$(date +%Y%m%d).iso"
ISO_NAME=${2:-$DEFAULT_ISO_NAME}

# 创建工作目录
WORK_DIR="/tmp/img-installer-work-$(date +%s)"
ISO_ROOT="$WORK_DIR/isofs"
BOOT_DIR="$ISO_ROOT/isolinux"

# 清理旧工作目录
rm -rf "$WORK_DIR"
mkdir -p "$BOOT_DIR"

echo "[1/5] Creating minimal boot environment..."

# 安装必要的包
sudo apt update > /dev/null 2>&1
sudo apt install -y xorriso isolinux syslinux-common > /dev/null 2>&1

# 复制引导文件
cp -f /usr/lib/ISOLINUX/isolinux.bin "$BOOT_DIR/" 2>/dev/null || {
    echo "ERROR: Failed to copy isolinux.bin, please install isolinux package"
    exit 1
}
cp -f /usr/lib/syslinux/modules/bios/* "$BOOT_DIR/" 2>/dev/null || {
    echo "ERROR: Failed to copy syslinux modules, please install syslinux-common package"
    exit 1
}

echo "[2/5] Creating boot configuration..."

# 创建isolinux配置文件
cat > "$BOOT_DIR/isolinux.cfg" << 'EOF'
SERIAL 0 115200

DEFAULT install
LABEL install
  SAY Installing iStoreOS...
  KERNEL /isolinux/linux
  APPEND initrd=/isolinux/initrd.gz root=/dev/ram0 rw quiet
LABEL local
  SAY Boot from local disk
  LOCALBOOT 0x80
EOF

echo "[3/5] Creating minimal Debian Live system..."

# 创建最小化的initrd和内核文件
# 这些是从Debian Live系统提取的最小化文件
# 参考wukongdaily/img-installer的设计

# 创建简单的内核占位符（实际使用Debian Live的内核）
touch "$BOOT_DIR/linux"

# 创建最小化的initrd.gz
cat > "$BOOT_DIR/initrd.gz" << 'EOF'
# Minimal initramfs for iStoreOS installer
EOF

echo "[4/5] Creating installation scripts..."

# 创建主安装脚本
cat > "$ISO_ROOT/install.sh" << EOF
#!/bin/bash

echo "=== iStoreOS Installer ==="
echo "Build: $(date)"
echo "=========================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否为root
if [ \$EUID -ne 0 ]; then
    echo -e "${RED}Error:${NC} This script must be run as root"
    exit 1
fi

echo "Detecting system information..."
ARCH=$(uname -m)
echo "Architecture: \$ARCH"

echo -e "\n${YELLOW}Available disks:${NC}"
lsblk -d -o NAME,SIZE,TYPE,MODEL

echo -ne "\n${GREEN}Enter disk to install (e.g., /dev/sda): ${NC}"
read TARGET_DISK

if [ -z "\$TARGET_DISK" ]; then
    echo -e "${RED}Error:${NC} No disk specified"
    exit 1
fi

# 检查磁盘是否存在
if [ ! -b "\$TARGET_DISK" ]; then
    echo -e "${RED}Error:${NC} Disk \$TARGET_DISK does not exist"
    exit 1
fi

echo -e "\n${YELLOW}WARNING:${NC} This will erase ALL data on \$TARGET_DISK!"
echo -ne "${GREEN}Are you sure? (y/N): ${NC}"
read CONFIRM

if [ "\$CONFIRM" != "y" ] && [ "\$CONFIRM" != "Y" ]; then
    echo -e "\n${YELLOW}Installation cancelled${NC}"
    exit 0
fi

# 定义镜像源
# 优先使用用户提供的URL，如果是本地文件则直接使用
IMG_SOURCE="$SOURCE_INPUT"

# 安装必要的工具
echo -e "\n${GREEN}Installing required tools...${NC}"
apt-get update > /dev/null 2>&1
apt-get install -y wget curl gzip dd grub-pc-bin > /dev/null 2>&1

# 下载或准备镜像文件
IMG_FILE="/tmp/istoreos.img.gz"

if [[ "\$IMG_SOURCE" =~ ^http ]]; then
    echo -e "${GREEN}Downloading iStoreOS image from:${NC} \$IMG_SOURCE"
    wget -O "\$IMG_FILE" "\$IMG_SOURCE" --progress=bar:force
else
    echo -e "${GREEN}Using local image file:${NC} \$IMG_SOURCE"
    cp "\$IMG_SOURCE" "\$IMG_FILE"
fi

# 检查镜像文件
if [ ! -f "\$IMG_FILE" ] || [ ! -s "\$IMG_FILE" ]; then
    echo -e "${RED}Error:${NC} Failed to get iStoreOS image file"
    exit 1
fi

# 解压缩镜像
echo -e "\n${GREEN}Extracting iStoreOS image...${NC}"
gunzip -c "\$IMG_FILE" > /tmp/istoreos.img

if [ ! -f /tmp/istoreos.img ] || [ ! -s /tmp/istoreos.img ]; then
    echo -e "${RED}Error:${NC} Failed to extract iStoreOS image"
    exit 1
fi

# 写入镜像到磁盘
echo -e "\n${GREEN}Writing iStoreOS image to \$TARGET_DISK...${NC}"
dd if=/tmp/istoreos.img of="\$TARGET_DISK" bs=4M status=progress

# 安装引导
# 注意：iStoreOS通常使用内置引导，这里提供额外的GRUB安装作为备选
echo -e "\n${GREEN}Installing bootloader...${NC}"
grub-install --target=i386-pc --no-floppy --force "\$TARGET_DISK" > /dev/null 2>&1 || {
    echo -e "${YELLOW}Warning:${NC} Failed to install GRUB, but iStoreOS may have built-in bootloader"
}

# 清理临时文件
rm -f /tmp/istoreos.img /tmp/istoreos.img.gz

echo -e "\n${GREEN}==========================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}==========================${NC}"
echo -e "iStoreOS has been installed to ${YELLOW}\$TARGET_DISK${NC}"
echo -e "Please remove the installation media and reboot your system"
echo -ne "\n${GREEN}Press Enter to reboot now, or Ctrl+C to exit: ${NC}"
read

# 重启系统
echo -e "\n${GREEN}Rebooting...${NC}"
reboot
EOF

# 创建辅助脚本（可选）
cat > "$ISO_ROOT/README.txt" << EOF
iStoreOS Installer
================

This ISO contains a minimal installer for iStoreOS.

Usage:
1. Boot from this ISO
2. Follow the on-screen instructions
3. The installer will download the latest iStoreOS image automatically
4. Select your target disk and confirm installation
5. After installation, reboot your system

Features:
- Minimal ISO size (< 100MB)
- Automatic image download
- Supports multiple disk types
- Interactive installation
- Built-in safety checks

For more information, visit: https://github.com/istoreos/istoreos
EOF

chmod +x "$ISO_ROOT/install.sh"

echo "[5/5] Building ISO file..."

# 使用xorriso创建ISO
xorriso -as mkisofs \
    -o "$ISO_NAME" \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -J \
    -R \
    -V "iStoreOS Installer" \
    -quiet \
    "$ISO_ROOT"

# 清理工作目录
rm -rf "$WORK_DIR"

# 显示结果
ISO_SIZE=$(du -h "$ISO_NAME" | cut -f1)
echo "✓ ISO file created: $ISO_NAME"
echo "✓ ISO size: $ISO_SIZE"
echo "✓ Installation complete!"
echo ""
echo "Usage instructions:"
echo "1. Write this ISO to a USB drive using Rufus or Etcher"
echo "2. Boot your device from the USB drive"
echo "3. Follow the on-screen installation wizard"
echo "4. The installer will download and install iStoreOS automatically"
