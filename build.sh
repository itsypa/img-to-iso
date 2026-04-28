#!/bin/bash
set -euo pipefail

TARGET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 --target <imm|istoreos>"
  exit 1
fi

case "$TARGET" in
  imm)
    DIR_NAME="imm"
    NAME_PATTERN="immortalwrt"
    MOUNT_NAME="immortalwrt.img"
    SUPPORT_DIR="immortalwrt"
    ;;
  istoreos)
    DIR_NAME="openwrt"
    NAME_PATTERN="istoreos"
    MOUNT_NAME="istoreos.img"
    SUPPORT_DIR="istoreos"
    ;;
  *)
    echo "Error: Unknown target '$TARGET'. Use 'imm' or 'istoreos'."
    exit 1
    ;;
esac

mkdir -p "$DIR_NAME"

REPO="${GITHUB_REPOSITORY:-itsypa/img-to-iso}"

echo "查找最新的 ${NAME_PATTERN} img.gz Release..."

HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/releases.json "https://api.github.com/repos/$REPO/releases")
if [[ "$HTTP_CODE" != "200" ]]; then
  echo "错误：GitHub API 请求失败，HTTP 状态码: $HTTP_CODE"
  cat /tmp/releases.json
  exit 1
fi

LATEST_RELEASE=$(jq -r "[.[] | select(.tag_name | test(\"^${NAME_PATTERN}-.*[.]img[.]gz$\"))] | sort_by(.published_at) | reverse | .[0]" /tmp/releases.json)

if [[ -z "$LATEST_RELEASE" || "$LATEST_RELEASE" == "null" ]]; then
  echo "错误：未找到 ${NAME_PATTERN} img.gz Release"
  exit 1
fi

TAG_NAME=$(echo "$LATEST_RELEASE" | jq -r '.tag_name')
PUBLISHED_AT=$(echo "$LATEST_RELEASE" | jq -r '.published_at')
echo "最新 Release tag: $TAG_NAME (发布时间: $PUBLISHED_AT)"

FILE_NAME=$(echo "$LATEST_RELEASE" | jq -r ".assets[] | select(.name | test(\"^${NAME_PATTERN}.*[.]img[.]gz$\")) | .name" | head -1)

if [[ -z "$FILE_NAME" || "$FILE_NAME" == "null" ]]; then
  echo "错误：Release $TAG_NAME 中未找到 img.gz 文件"
  exit 1
fi

ISO_VERSION=$(echo "$FILE_NAME" | sed -E "s/^${NAME_PATTERN}[+-]?([0-9.]+)\.img\.gz$/\1/")
if [[ ! "$ISO_VERSION" =~ ^[0-9]+\.[0-9] ]]; then
  echo "错误：无法从文件名 $FILE_NAME 中提取版本号"
  exit 1
fi

DOWNLOAD_URL=$(echo "$LATEST_RELEASE" | jq -r ".assets[] | select(.name == \"$FILE_NAME\") | .browser_download_url")

if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "错误：未找到文件 $FILE_NAME 的下载地址"
  exit 1
fi

OUTPUT_PATH="$DIR_NAME/$FILE_NAME"
echo "下载地址: $DOWNLOAD_URL"
echo "下载文件: $FILE_NAME -> $OUTPUT_PATH"

if ! curl -Lf --retry 3 --retry-delay 5 --retry-all-errors -o "$OUTPUT_PATH" "$DOWNLOAD_URL"; then
  echo "下载失败！"
  exit 1
fi

echo "下载${NAME_PATTERN}成功!"
echo "正在解压为:${NAME_PATTERN}-$ISO_VERSION.img"
gzip -d "$OUTPUT_PATH"
mv "$DIR_NAME/$(basename "$FILE_NAME" .gz)" "$DIR_NAME/${NAME_PATTERN}-$ISO_VERSION.img"
ls -lh "$DIR_NAME/"
echo "准备合成 ${NAME_PATTERN}-$ISO_VERSION 安装器"

mkdir -p output

DOCKER_CACHE_DIR="$(pwd)/.docker-cache"
mkdir -p "$DOCKER_CACHE_DIR"

echo "使用 Docker 构建..."

docker run --privileged --rm \
  -v "$(pwd)/output:/output" \
  -v "$(pwd)/supportFiles:/supportFiles:ro" \
  -v "$(pwd)/${DIR_NAME}/${NAME_PATTERN}-${ISO_VERSION}.img:/mnt/${MOUNT_NAME}" \
  -v "${DOCKER_CACHE_DIR}:/docker-cache" \
  debian:buster \
  bash -c "
    /supportFiles/build.sh \"$SUPPORT_DIR\" \"$ISO_VERSION\"
  "
