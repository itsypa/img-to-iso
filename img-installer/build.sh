#!/bin/bash

# img-installer build script
# 基于wukongdaily/img-installer项目

set -e

# 检查参数
if [ $# -lt 1 ]; then
    echo "Usage: $0 <image.img.gz> [output.iso]"
    exit 1
fi

IMG_GZ_FILE=$1
DEFAULT_ISO_NAME="${IMG_GZ_FILE%.img.gz}.iso"
ISO_NAME=${2:-$DEFAULT_ISO_NAME}

# 创建工作目录
WORK_DIR="/tmp/img-installer-work"
BOOT_DIR="$WORK_DIR/boot"
ISO_DIR="$WORK_DIR/iso"

# 清理旧工作目录
rm -rf $WORK_DIR
mkdir -p $WORK_DIR $BOOT_DIR $ISO_DIR

echo "[1/6] Extracting img.gz file..."
gunzip -c $IMG_GZ_FILE > $WORK_DIR/source.img

echo "[2/6] Creating boot environment..."

# 安装必要的包
sudo apt update
sudo apt install -y xorriso isolinux syslinux-common

# 复制引导文件
mkdir -p $BOOT_DIR/isolinux
cp /usr/lib/ISOLINUX/isolinux.bin $BOOT_DIR/isolinux/
cp /usr/lib/syslinux/modules/bios/* $BOOT_DIR/isolinux/

# 创建isolinux配置文件
cat > $BOOT_DIR/isolinux/isolinux.cfg << 'EOF'
SERIAL 0 115200

DEFAULT install
LABEL install
  SAY Installing iStoreOS...
  KERNEL /vmlinuz
  APPEND initrd=/initrd.img root=/dev/ram0 rw quiet
LABEL live
  SAY Booting iStoreOS Live...
  KERNEL /vmlinuz
  APPEND initrd=/initrd.img root=/dev/ram0 rw quiet live
EOF

echo "[3/6] Preparing ISO filesystem..."

# 复制镜像文件到ISO目录
cp $WORK_DIR/source.img $ISO_DIR/

# 创建安装脚本
cat > $ISO_DIR/install.sh << 'EOF'
#!/bin/bash

echo "=== iStoreOS Installer ==="
echo "Detecting disks..."

# 列出可用磁盘
lsblk -d -o NAME,SIZE,TYPE

echo -n "Enter disk to install (e.g., /dev/sda): "
read TARGET_DISK

if [ -z "$TARGET_DISK" ]; then
    echo "Error: No disk specified"
    exit 1
fi

echo "Installing iStoreOS to $TARGET_DISK..."
echo "This will erase all data on $TARGET_DISK!"
echo -n "Are you sure? (y/N): "
read CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Installation cancelled"
    exit 0
fi

# 安装镜像到目标磁盘
echo "Writing image to $TARGET_DISK..."
dd if=/source.img of=$TARGET_DISK bs=4M status=progress

# 安装引导
echo "Installing bootloader..."
apt-get update
apt-get install -y grub-pc-bin

grub-install --target=i386-pc --no-floppy --force $TARGET_DISK

# 更新grub配置
echo "Updating GRUB configuration..."
update-grub

echo "=== Installation Complete ==="
echo "iStoreOS has been installed to $TARGET_DISK"
echo "Please reboot your system"
EOF

chmod +x $ISO_DIR/install.sh

echo "[4/6] Creating initramfs..."

# 简化的initramfs创建
# 实际项目中可能需要更复杂的initramfs
cat > $BOOT_DIR/initrd.img << 'EOF'
# Minimal initramfs for iStoreOS installer
EOF

# 创建简单的内核文件（实际项目中需要真实内核）
touch $BOOT_DIR/vmlinuz

echo "[5/6] Building ISO file..."

# 使用xorriso创建ISO
xorriso -as mkisofs \
    -o $ISO_NAME \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -J \
    -R \
    -V "iStoreOS Installer" \
    $WORK_DIR

echo "[6/6] Cleanup..."
rm -rf $WORK_DIR

echo "✓ ISO file created: $ISO_NAME"
echo "✓ Installation complete!"
