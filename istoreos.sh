#!/bin/bash
mkdir -p openwrt

# 直接使用已知的下载链接作为fallback，避免API访问问题
echo "使用直接下载链接获取istoreos镜像文件..."
# 已知的istoreos下载链接格式
DOWNLOAD_URL="https://fw.koolcenter.com/iStoreOS/x86_64/istoreos-24.10.1-2025060614-x86-64-squashfs-combined-efi.img.gz"
FILE_NAME=$(basename "$DOWNLOAD_URL")

# 输出信息
echo "使用直接链接：$DOWNLOAD_URL"
echo "使用文件名：$FILE_NAME"
echo -e "\n"

# 保留原始文件名
OUTPUT_PATH="openwrt/$FILE_NAME"
UNCOMPRESSED_NAME="${FILE_NAME%.img.gz}.img"

# 下载文件
echo "下载地址: $DOWNLOAD_URL"
echo "下载文件: $FILE_NAME -> $OUTPUT_PATH"
curl -L -o "$OUTPUT_PATH" "$DOWNLOAD_URL"

if [[ $? -eq 0 ]]; then
  echo "下载istoreos成功!"
  echo "正在解压为:$UNCOMPRESSED_NAME"
  gzip -d "$OUTPUT_PATH"
  ls -lh openwrt/
  echo "准备合成 istoreos 安装器"
else
  echo "下载失败！"
  exit 1
fi

mkdir -p output
docker run --privileged --rm \
        -e ISO_NAME="${FILE_NAME%.img.gz}" \
        -v $(pwd)/output:/output \
        -v $(pwd)/supportFiles:/supportFiles:ro \
        -v $(pwd)/openwrt/$UNCOMPRESSED_NAME:/mnt/istoreos.img \
        debian:buster \
        /supportFiles/istoreos/build.sh
