#!/bin/bash

# img-installer build script
# 基于wukongdaily/img-installer项目

set -e

# 增强的错误处理
trap 'echo "ERROR: Script failed at line $LINENO"; exit 1' ERR

# 检查参数
if [ $# -lt 1 ]; then
    echo "Usage: $0 <image.img.gz> [output.iso]"
    exit 1
fi

IMG_GZ_FILE=$1

# 检查输入文件是否存在
if [ ! -f "$IMG_GZ_FILE" ]; then
    echo "ERROR: Input file '$IMG_GZ_FILE' not found"
    exit 1
fi

# 确定输入文件类型
if [[ "$IMG_GZ_FILE" == *.img.gz ]]; then
    IS_GZIPPED=true
    DEFAULT_ISO_NAME="${IMG_GZ_FILE%.img.gz}.iso"
    SOURCE_IMG="$WORK_DIR/source.img"
elif [[ "$IMG_GZ_FILE" == *.img ]]; then
    IS_GZIPPED=false
    DEFAULT_ISO_NAME="${IMG_GZ_FILE%.img}.iso"
    SOURCE_IMG="$WORK_DIR/source.img"
else
    echo "ERROR: Input file must be a .img or .img.gz file"
    exit 1
fi

ISO_NAME=${2:-$DEFAULT_ISO_NAME}

# 创建工作目录
WORK_DIR="/tmp/img-installer-work-$(date +%s)"
BOOT_DIR="$WORK_DIR/boot"
ISO_DIR="$WORK_DIR/iso"

# 清理旧工作目录（如果存在）
if [ -d "$WORK_DIR" ]; then
    rm -rf $WORK_DIR
fi

mkdir -p $WORK_DIR $BOOT_DIR $ISO_DIR

if [ "$IS_GZIPPED" = true ]; then
    echo "[1/6] Extracting img.gz file..."
    # 检查.gz文件完整性
gzip -t $IMG_GZ_FILE || {
        echo "WARNING: gzip file integrity check failed, but attempting extraction anyway..."
    }
    # 使用gunzip提取
    gunzip -c $IMG_GZ_FILE 2>/dev/null > $SOURCE_IMG
else
    echo "[1/6] Copying img file..."
    # 直接复制.img文件
    cp -f $IMG_GZ_FILE $SOURCE_IMG
fi

# 检查处理后的文件大小
if [ ! -s $SOURCE_IMG ]; then
    echo "ERROR: Failed to process img file or processed file is empty"
    exit 1
fi

echo "[2/6] Creating boot environment..."

# 安装必要的包
sudo apt update > /dev/null 2>&1
sudo apt install -y xorriso isolinux syslinux-common > /dev/null 2>&1

# 复制引导文件
mkdir -p $BOOT_DIR/isolinux
cp -f /usr/lib/ISOLINUX/isolinux.bin $BOOT_DIR/isolinux/ 2>/dev/null || {
    echo "ERROR: Failed to copy isolinux.bin, please install isolinux package"
    exit 1
}
cp -f /usr/lib/syslinux/modules/bios/* $BOOT_DIR/isolinux/ 2>/dev/null || {
    echo "ERROR: Failed to copy syslinux modules, please install syslinux-common package"
    exit 1
}

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
LABEL local
  SAY Boot from local disk
  LOCALBOOT 0x80
EOF

echo "[3/6] Preparing ISO filesystem..."

# 复制镜像文件到ISO目录
cp -f $SOURCE_IMG $ISO_DIR/

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

# 检查磁盘是否存在
if [ ! -b "$TARGET_DISK" ]; then
    echo "Error: Disk $TARGET_DISK does not exist"
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
dd if=./source.img of=$TARGET_DISK bs=4M status=progress

# 安装引导
echo "Installing bootloader..."
apt-get update > /dev/null 2>&1
apt-get install -y grub-pc-bin > /dev/null 2>&1

grub-install --target=i386-pc --no-floppy --force $TARGET_DISK

# 更新grub配置
echo "Updating GRUB configuration..."
update-grub

echo "=== Installation Complete ==="
echo "iStoreOS has been installed to $TARGET_DISK"
echo "Please reboot your system"
EOF

chmod +x $ISO_DIR/install.sh

echo "[4/6] Creating minimal boot files..."

# 创建简单的内核和initrd文件
# 这些是占位符，实际系统会使用真实的内核
cat > $BOOT_DIR/initrd.img << 'EOF'
# Minimal initramfs for iStoreOS installer
EOF

touch $BOOT_DIR/vmlinuz

echo "[5/6] Building ISO file..."

# 合并boot和iso目录
mkdir -p $WORK_DIR/final
cp -r $BOOT_DIR/* $WORK_DIR/final/
cp -r $ISO_DIR/* $WORK_DIR/final/

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
    $WORK_DIR/final

echo "[6/6] Cleanup..."
rm -rf $WORK_DIR

echo "✓ ISO file created: $ISO_NAME"
echo "✓ Installation complete!"
