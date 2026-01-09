#!/bin/bash
mkdir -p openwrt

REPO="istoreos/istoreos"

# 获取最新Release的信息
LATEST_RELEASE=$(curl -s https://api.github.com/repos/$REPO/releases/latest)

# 查找最新的x86_64 squashfs combined efi img.gz文件
FILE_INFO=$(echo $LATEST_RELEASE | jq -r '.assets[] | select(.name | test("x86-64.*squashfs-combined-efi\\.img\\.gz$")) | {name, browser_download_url}')
FILE_NAME=$(echo $FILE_INFO | jq -r '.name')
DOWNLOAD_URL=$(echo $FILE_INFO | jq -r '.browser_download_url')

if [[ -z "$DOWNLOAD_URL" || -z "$FILE_NAME" ]]; then
  echo "错误：未找到合适的img.gz文件"
  exit 1
fi

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
