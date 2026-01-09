#!/bin/bash
mkdir -p openwrt

# 使用正确的istoreos仓库地址
REPO="istoreos/istoreos"

# 获取最新Release的信息，并添加调试信息
echo "正在获取仓库 $REPO 的最新Release信息..."
LATEST_RELEASE=$(curl -s https://api.github.com/repos/$REPO/releases/latest)

# 检查API返回是否成功
if [[ $? -ne 0 ]]; then
  echo "错误：无法连接到GitHub API"
  exit 1
fi

# 检查返回内容是否有效
if [[ -z "$LATEST_RELEASE" || "$LATEST_RELEASE" == *"Not Found"* ]]; then
  echo "错误：API返回无效内容或仓库不存在"
  echo "尝试使用备用仓库地址..."
  REPO="istoreos/downloads"
  LATEST_RELEASE=$(curl -s https://api.github.com/repos/$REPO/releases/latest)
  
  if [[ -z "$LATEST_RELEASE" || "$LATEST_RELEASE" == *"Not Found"* ]]; then
    echo "错误：备用仓库也无法访问"
    exit 1
  fi
fi

# 输出调试信息，查看API返回内容
echo "API返回内容（前1000字符）："
echo $LATEST_RELEASE | head -c 1000
echo -e "\n"

# 首先检查assets是否存在
ASSETS_COUNT=$(echo $LATEST_RELEASE | jq -r '.assets | length')
if [[ "$ASSETS_COUNT" == "null" || "$ASSETS_COUNT" -eq 0 ]]; then
  echo "错误：当前Release没有任何资产文件"
  # 尝试获取所有Release，找到有assets的Release
  echo "正在尝试获取所有Release..."
  ALL_RELEASES=$(curl -s https://api.github.com/repos/$REPO/releases)
  
  # 遍历所有Release，找到第一个有assets的
  for i in $(seq 0 9); do
    RELEASE=$(echo $ALL_RELEASES | jq -r "[$i]")
    ASSETS_COUNT=$(echo $RELEASE | jq -r '.assets | length')
    if [[ "$ASSETS_COUNT" != "null" && "$ASSETS_COUNT" -gt 0 ]]; then
      echo "找到有资产的Release：$(echo $RELEASE | jq -r '.tag_name')"
      LATEST_RELEASE=$RELEASE
      break
    fi
  done
  
  # 再次检查assets
  ASSETS_COUNT=$(echo $LATEST_RELEASE | jq -r '.assets | length')
  if [[ "$ASSETS_COUNT" == "null" || "$ASSETS_COUNT" -eq 0 ]]; then
    echo "错误：所有Release都没有资产文件"
    exit 1
  fi
fi

# 查找最新的x86_64 squashfs combined efi img.gz文件
# 使用更宽松的过滤条件，不使用test而是使用contains
FILE_INFO=$(echo $LATEST_RELEASE | jq -r '.assets[] | select(.name | contains("x86") and contains("64") and contains("squashfs") and contains("combined") and contains("efi") and endswith(".img.gz")) | {name, browser_download_url}' | head -n 1)

# 输出调试信息，查看匹配到的文件信息
echo "匹配到的文件信息："
echo $FILE_INFO
echo -e "\n"

FILE_NAME=$(echo $FILE_INFO | jq -r '.name')
DOWNLOAD_URL=$(echo $FILE_INFO | jq -r '.browser_download_url')

# 输出调试信息，查看提取的文件名和下载地址
echo "提取的文件名：$FILE_NAME"
echo "提取的下载地址：$DOWNLOAD_URL"
echo -e "\n"

if [[ -z "$DOWNLOAD_URL" || -z "$FILE_NAME" || "$FILE_NAME" == "null" || "$DOWNLOAD_URL" == "null" ]]; then
  echo "错误：未找到合适的img.gz文件"
  # 尝试直接使用特定格式的文件名
  echo "尝试使用直接下载链接..."
  # 使用istoreos的已知下载链接格式
  DOWNLOAD_URL="https://github.com/istoreos/istoreos/releases/download/latest/istoreos-x86-64-squashfs-combined-efi.img.gz"
  FILE_NAME=$(basename "$DOWNLOAD_URL")
  
  echo "使用直接链接：$DOWNLOAD_URL"
  echo "使用文件名：$FILE_NAME"
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
