#!/bin/bash
mkdir -p imm

# 直接使用已知的下载链接作为fallback，避免API访问问题
echo "使用直接下载链接获取immortalwrt镜像文件..."
# 已知的immortalwrt下载链接格式
DOWNLOAD_URL="https://downloads.immortalwrt.org/releases/24.10.0/targets/x86/64/immortalwrt-24.10.0-x86-64-generic-squashfs-combined-efi.img.gz"
FILE_NAME=$(basename "$DOWNLOAD_URL")

# 输出信息
echo "使用直接链接：$DOWNLOAD_URL"
echo "使用文件名：$FILE_NAME"
echo -e "\n"

# 保留原始文件名
OUTPUT_PATH="imm/$FILE_NAME"
UNCOMPRESSED_NAME="${FILE_NAME%.img.gz}.img"

# 下载文件
echo "下载地址: $DOWNLOAD_URL"
echo "下载文件: $FILE_NAME -> $OUTPUT_PATH"
curl -L -o "$OUTPUT_PATH" "$DOWNLOAD_URL"

if [[ $? -eq 0 ]]; then
  echo "下载immortalwrt成功!"
  file "$OUTPUT_PATH"
  echo "正在解压为:$UNCOMPRESSED_NAME"
  gzip -d "$OUTPUT_PATH"
  ls -lh imm/
  echo "准备合成 immortalwrt 安装器"
else
  echo "下载失败！"
  exit 1
fi

mkdir -p output
docker run --privileged --rm \
        -e ISO_NAME="${FILE_NAME%.img.gz}" \
        -v $(pwd)/output:/output \
        -v $(pwd)/supportFiles:/supportFiles:ro \
        -v $(pwd)/imm/$UNCOMPRESSED_NAME:/mnt/immortalwrt.img \
        debian:buster \
        /supportFiles/immortalwrt/build.sh
