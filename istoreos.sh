#!/bin/bash

mkdir -p openwrt

# 从固定tag "istoreos.img.gz" 获取带版本号的img.gz文件
REPO="${GITHUB_REPOSITORY:-itsypa/img-to-iso}"
TAG="istoreos.img.gz"

# 查找带版本号的img.gz文件，支持istoreos+版本号.img.gz格式
FILE_NAME=$(curl -s https://api.github.com/repos/$REPO/releases/tags/$TAG | jq -r '.assets[] | select(.name | test("^istoreos.*\.img\.gz$")) | .name' | head -1)

if [[ -z "$FILE_NAME" || "$FILE_NAME" == "null" ]]; then
  echo "错误：未找到带版本号的img.gz文件"
  exit 1
fi

# 提取版本号（去掉istoreos-前缀和.img.gz后缀）
ISO_VERSION=$(echo "$FILE_NAME" | sed -E 's/^istoreos[+-]?([0-9.]+)\.img\.gz$/\1/')

OUTPUT_PATH="openwrt/$FILE_NAME"
DOWNLOAD_URL=$(curl -s https://api.github.com/repos/$REPO/releases/tags/$TAG | jq -r '.assets[] | select(.name == "'"$FILE_NAME"'") | .browser_download_url')

if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "错误：未找到文件 $FILE_NAME"
  exit 1
fi

echo "下载地址: $DOWNLOAD_URL"
echo "下载文件: $FILE_NAME -> $OUTPUT_PATH"
curl -L -o "$OUTPUT_PATH" "$DOWNLOAD_URL"

if [[ $? -eq 0 ]]; then
  echo "下载istoreos成功!"
  echo "正在解压为:istoreos-$ISO_VERSION.img"
  gzip -d "$OUTPUT_PATH"
  # 重命名解压后的文件，添加版本号
  mv "openwrt/$(basename "$FILE_NAME" .gz)" "openwrt/istoreos-$ISO_VERSION.img"
  ls -lh openwrt/
  echo "准备合成 istoreos-$ISO_VERSION 安装器"
else
  echo "下载失败！"
  exit 1
fi

mkdir -p output
docker run --privileged --rm \
        -v $(pwd)/output:/output \
        -v $(pwd)/supportFiles:/supportFiles:ro \
        -v $(pwd)/openwrt/istoreos-$ISO_VERSION.img:/mnt/istoreos.img \
        debian:buster \
        /supportFiles/istoreos/build.sh "$ISO_VERSION"
