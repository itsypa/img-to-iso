#!/bin/bash

mkdir -p imm

REPO="${GITHUB_REPOSITORY:-itsypa/img-to-iso}"

# 从所有 immortalwrt-*.img.gz 的 Release 中，按推送时间找到最新的
echo "查找最新的 ImmortalWrt img.gz Release..."

LATEST_RELEASE=$(curl -s "https://api.github.com/repos/$REPO/releases" | \
  jq -r '[.[] | select(.tag_name | test("^immortalwrt-.*[.]img[.]gz$"))] | sort_by(.published_at) | reverse | .[0]')

if [[ -z "$LATEST_RELEASE" || "$LATEST_RELEASE" == "null" ]]; then
  echo "错误：未找到 ImmortalWrt img.gz Release"
  exit 1
fi

# 提取 Release 信息
TAG_NAME=$(echo "$LATEST_RELEASE" | jq -r '.tag_name')
PUBLISHED_AT=$(echo "$LATEST_RELEASE" | jq -r '.published_at')
echo "最新 Release tag: $TAG_NAME (发布时间: $PUBLISHED_AT)"

# 从 Release assets 中查找 img.gz 文件
FILE_NAME=$(echo "$LATEST_RELEASE" | jq -r '.assets[] | select(.name | test("^immortalwrt.*[.]img[.]gz$")) | .name' | head -1)

if [[ -z "$FILE_NAME" || "$FILE_NAME" == "null" ]]; then
  echo "错误：Release $TAG_NAME 中未找到 img.gz 文件"
  exit 1
fi

# 提取版本号（去掉immortalwrt-前缀和.img.gz后缀）
ISO_VERSION=$(echo "$FILE_NAME" | sed -E 's/^immortalwrt[+-]?([0-9.]+)\.img\.gz$/\1/')

DOWNLOAD_URL=$(echo "$LATEST_RELEASE" | jq -r '.assets[] | select(.name == "'"$FILE_NAME"'") | .browser_download_url')

if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "错误：未找到文件 $FILE_NAME 的下载地址"
  exit 1
fi

OUTPUT_PATH="imm/$FILE_NAME"
echo "下载地址: $DOWNLOAD_URL"
echo "下载文件: $FILE_NAME -> $OUTPUT_PATH"
curl -L -o "$OUTPUT_PATH" "$DOWNLOAD_URL"

if [[ $? -eq 0 ]]; then
  echo "下载immortalwrt成功!"
  echo "正在解压为:immortalwrt-$ISO_VERSION.img"
  gzip -d "$OUTPUT_PATH"
  # 重命名解压后的文件，添加版本号
  mv "imm/$(basename "$FILE_NAME" .gz)" "imm/immortalwrt-$ISO_VERSION.img"
  ls -lh imm/
  echo "准备合成 immortalwrt-$ISO_VERSION 安装器"
else
  echo "下载失败！"
  exit 1
fi

mkdir -p output

# 设置Docker构建缓存目录
DOCKER_CACHE_DIR="$(pwd)/.docker-cache"
mkdir -p "$DOCKER_CACHE_DIR"

echo "使用原始docker命令构建（保持兼容性）..."

# 使用原始的docker run命令，但优化构建过程
docker run --privileged --rm \
  -v $(pwd)/output:/output \
  -v $(pwd)/supportFiles:/supportFiles:ro \
  -v $(pwd)/imm/immortalwrt-$ISO_VERSION.img:/mnt/immortalwrt.img \
  -v "$DOCKER_CACHE_DIR":/docker-cache \
  debian:buster \
  bash -c "
    # 设置APT缓存
    mkdir -p /var/cache/apt/archives/partial
    mkdir -p /var/lib/apt/lists/partial
    echo 'Acquire::Check-Valid-Until \"false\";' > /etc/apt/apt.conf.d/99no-check-valid-until
    
    # 执行构建脚本
    /supportFiles/immortalwrt/build.sh \"$ISO_VERSION\"
  "
