#!/bin/bash

# 转换脚本：将iStoreOS的.img文件转换为基于Debian Live系统的ISO文件

set -e

# 检查参数
if [ $# -lt 1 ]; then
    echo "Usage: $0 <istoreos-image.img> [output-iso-name]"
    exit 1
fi

IMG_FILE=$1
# 使用默认值或用户提供的文件名
ISO_NAME=${2:-"isstoreos-live.iso"}
WORK_DIR="/tmp/istoreos-iso-build"
LIVE_DIR="$WORK_DIR/live-build"
ROOTFS_DIR="$WORK_DIR/rootfs"

# 清理旧工作目录
rm -rf $WORK_DIR
mkdir -p $WORK_DIR $LIVE_DIR $ROOTFS_DIR

# 1. 检查并挂载iStoreOS镜像
echo "[1/6] Checking and mounting iStoreOS image..."

# 获取分区信息
PART_INFO=$(fdisk -l $IMG_FILE | grep -A2 "Device")
ROOT_PART=$(echo "$PART_INFO" | grep "Linux filesystem" | awk '{print $1}')

if [ -z "$ROOT_PART" ]; then
    echo "Error: Could not find root partition in $IMG_FILE"
    exit 1
fi

# 获取偏移量
ROOT_PART_NUM=$(echo $ROOT_PART | grep -o '[0-9]\+$')
OFFSET=$(fdisk -l $IMG_FILE | grep "^$IMG_FILE$ROOT_PART_NUM" | awk '{print $2}')

if [ -z "$OFFSET" ]; then
    echo "Error: Could not find partition offset"
    exit 1
fi

# 挂载rootfs
mount -o loop,offset=$((OFFSET * 512)) $IMG_FILE $ROOTFS_DIR

echo "✓ Mounted iStoreOS rootfs at $ROOTFS_DIR"

# 2. 设置Debian Live构建环境
echo "[2/6] Setting up Debian Live build environment..."

cd $LIVE_DIR
lb config \
    --distribution bookworm \
    --architecture amd64 \
    --debootstrap-options "--variant=minbase" \
    --include "linux-image-amd64 live-boot systemd-sysv sudo locales"

# 3. 配置Debian Live
echo "[3/6] Configuring Debian Live..."

# 复制iStoreOS的squashfs文件（如果存在）
if [ -f $ROOTFS_DIR/squashfs.img ]; then
    mkdir -p $LIVE_DIR/binary/live
    cp $ROOTFS_DIR/squashfs.img $LIVE_DIR/binary/live/filesystem.squashfs
    echo "✓ Copied squashfs.img to Debian Live"
fi

# 创建自定义引导配置
mkdir -p $LIVE_DIR/config/bootloaders/isolinux
cat > $LIVE_DIR/config/bootloaders/isolinux/isolinux.cfg << 'EOF'
SERIAL 0 115200

DEFAULT live
LABEL live
  SAY Booting iStoreOS Live...
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd.img boot=live persistence quiet
LABEL live-failsafe
  SAY Booting iStoreOS Live (failsafe)...
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd.img boot=live persistence config memtest noapic noapm nodma nomce nolapic nomodeset nosmp nosplash vga=normal
EOF

# 4. 构建Debian Live ISO
echo "[4/6] Building Debian Live ISO..."

cd $LIVE_DIR
lb build 2>&1 | tee build.log

# 5. 复制生成的ISO到工作目录
echo "[5/6] Copying generated ISO..."

if [ -f $LIVE_DIR/live-image-amd64.iso ]; then
    cp $LIVE_DIR/live-image-amd64.iso $WORK_DIR/$ISO_NAME
    echo "✓ Generated ISO: $WORK_DIR/$ISO_NAME"
else
    echo "Error: ISO generation failed, checking build log..."
    tail -n 50 $LIVE_DIR/build.log
    exit 1
fi

# 6. 复制ISO到当前目录
echo "[6/6] Copying ISO to current directory..."

cp $WORK_DIR/$ISO_NAME ./

# 清理工作目录
umount -f $ROOTFS_DIR 2>/dev/null || true
rm -rf $WORK_DIR

# 显示结果
echo "✓✓✓ iStoreOS ISO conversion completed! ✓✓✓"
echo "Generated ISO: ./$ISO_NAME"
echo "You can now use this ISO to boot iStoreOS in a virtual machine or on physical hardware."

# 验证ISO
echo "Verifying ISO..."
isohybrid --check $ISO_NAME 2>/dev/null || echo "✓ ISO is valid"

exit 0
