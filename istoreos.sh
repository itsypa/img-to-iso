#!/bin/bash
mkdir -p openwrt

# 定义仓库信息
REPO_OWNER="istoreos"
REPO_NAME="istoreos"

# 获取最新Release信息的函数
get_latest_release() {
    local owner=$1
    local repo=$2
    echo "正在从GitHub API获取 $owner/$repo 的最新Release信息..."
    
    # 使用curl获取最新Release信息，添加超时和重试机制
    local release_info=$(curl -s -m 10 -L "https://api.github.com/repos/$owner/$repo/releases/latest")
    
    # 检查返回内容
    if [[ -z "$release_info" || "$release_info" == *"Not Found"* || "$release_info" == *"API rate limit exceeded"* ]]; then
        echo "错误：无法获取最新Release信息，尝试使用备用方法..."
        return 1
    fi
    
    echo "$release_info"
    return 0
}

# 从Release中查找合适的img.gz文件
find_img_gz() {
    local release_info=$1
    echo "正在查找合适的img.gz文件..."
    
    # 使用jq查找包含x86-64和squashfs-combined-efi的img.gz文件
    local file_info=$(echo "$release_info" | jq -r '.assets[] | select(.name | contains("x86") and contains("64") and contains("squashfs") and contains("combined") and contains("efi") and endswith(".img.gz")) | {name, browser_download_url}' | head -n 1)
    
    if [[ -z "$file_info" || "$file_info" == "null" ]]; then
        echo "错误：未找到合适的img.gz文件"
        return 1
    fi
    
    echo "$file_info"
    return 0
}

# 主逻辑
echo "=== iStoreOS 安装器构建脚本 ==="

# 尝试获取最新Release信息
RELEASE_INFO=$(get_latest_release "$REPO_OWNER" "$REPO_NAME")

# 如果失败，尝试使用备用仓库
if [[ $? -ne 0 ]]; then
    REPO_NAME="downloads"
    RELEASE_INFO=$(get_latest_release "$REPO_OWNER" "$REPO_NAME")
    
    if [[ $? -ne 0 ]]; then
        echo "错误：无法从GitHub API获取最新Release信息，使用备用下载链接..."
        # 使用已知的下载链接作为最后的fallback
        DOWNLOAD_URL="https://fw.koolcenter.com/iStoreOS/x86_64/istoreos-24.10.1-2025060614-x86-64-squashfs-combined-efi.img.gz"
        FILE_NAME=$(basename "$DOWNLOAD_URL")
    else
        # 从Release中查找img.gz文件
        FILE_INFO=$(find_img_gz "$RELEASE_INFO")
        if [[ $? -ne 0 ]]; then
            echo "错误：无法找到合适的img.gz文件，使用备用下载链接..."
            DOWNLOAD_URL="https://fw.koolcenter.com/iStoreOS/x86_64/istoreos-24.10.1-2025060614-x86-64-squashfs-combined-efi.img.gz"
            FILE_NAME=$(basename "$DOWNLOAD_URL")
        else
            # 提取文件名和下载地址
            FILE_NAME=$(echo "$FILE_INFO" | jq -r '.name')
            DOWNLOAD_URL=$(echo "$FILE_INFO" | jq -r '.browser_download_url')
        fi
    fi
else
    # 从Release中查找img.gz文件
    FILE_INFO=$(find_img_gz "$RELEASE_INFO")
    if [[ $? -ne 0 ]]; then
        echo "错误：无法找到合适的img.gz文件，使用备用下载链接..."
        DOWNLOAD_URL="https://fw.koolcenter.com/iStoreOS/x86_64/istoreos-24.10.1-2025060614-x86-64-squashfs-combined-efi.img.gz"
        FILE_NAME=$(basename "$DOWNLOAD_URL")
    else
        # 提取文件名和下载地址
        FILE_NAME=$(echo "$FILE_INFO" | jq -r '.name')
        DOWNLOAD_URL=$(echo "$FILE_INFO" | jq -r '.browser_download_url')
    fi
fi

# 输出信息
echo "最终使用："
echo "- 文件名：$FILE_NAME"
echo "- 下载链接：$DOWNLOAD_URL"
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
