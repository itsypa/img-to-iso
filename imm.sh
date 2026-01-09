#!/bin/bash
mkdir -p imm

# 获取当前仓库的最新release信息
REPO="$GITHUB_REPOSITORY"
if [[ -z "$REPO" ]]; then
  # 如果未在GitHub Actions环境中，使用默认仓库
  REPO="wukongdaily/img-installer"
fi

# 获取最新release的资产信息
LATEST_RELEASE=$(curl -s https://api.github.com/repos/$REPO/releases/latest)

# 查找immortalwrt镜像文件，匹配模式：immortalwrt-*.img.gz
FILE_NAME=$(echo "$LATEST_RELEASE" | jq -r '.assets[] | select(.name | startswith("immortalwrt-") and endswith(".img.gz")) | .name' | head -1)

if [[ -z "$FILE_NAME" ]]; then
  echo "错误：未找到immortalwrt镜像文件"
  exit 1
fi

DOWNLOAD_URL=$(echo "$LATEST_RELEASE" | jq -r '.assets[] | select(.name == "'"$FILE_NAME"'") | .browser_download_url')
OUTPUT_PATH="imm/immortalwrt.img.gz"

echo "下载地址: $DOWNLOAD_URL"
echo "下载文件: $FILE_NAME -> $OUTPUT_PATH"
curl -L -o "$OUTPUT_PATH" "$DOWNLOAD_URL"

if [[ $? -eq 0 ]]; then
  echo "下载$FILE_NAME成功!"
  file imm/immortalwrt.img.gz
  echo "正在解压为:immortalwrt.img"
  gzip -d imm/immortalwrt.img.gz
  ls -lh imm/
  echo "准备合成 immortalwrt 安装器"
else
  echo "下载失败！"
  exit 1
fi

mkdir -p output
docker run --privileged --rm \
        -v $(pwd)/output:/output \
        -v $(pwd)/supportFiles:/supportFiles:ro \
        -v $(pwd)/imm/immortalwrt.img:/mnt/immortalwrt.img \
        debian:buster \
        /supportFiles/immortalwrt/build.sh
