#!/bin/bash

#source_path="./openwrt-source"
#branch=24.10.0-rc7

# env
# REPO_URL=https://github.com/openwrt/openwrt
# REPO_BRANCH=24.10.0-rc7
# CONFIG_FILE=r5s.config
# SOURCE_PATH=$SOURCE_PATH
# BUILDER_PATH=$BUILDER_PATH

function install_dep() {
  docker rmi $(docker images -q)
  sudo rm -rf /usr/share/dotnet /etc/mysql /etc/php /etc/apt/sources.list.d /usr/local/lib/android
  sudo -E apt-get -y purge azure-cli ghc* zulu* hhvm llvm* firefox google* dotnet* powershell openjdk* adoptopenjdk* mysql* php* mongodb* dotnet* moby* snapd* || true
  sudo -E apt-get update
  sudo -E apt-get -y install ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \
                             bzip2 ccache clang cmake cpio curl device-tree-compiler flex gawk gcc-multilib g++-multilib gettext \
                             genisoimage git gperf haveged help2man intltool libc6-dev-i386 libelf-dev libfuse-dev libglib2.0-dev \
                             libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses5-dev libncursesw5-dev libpython3-dev \
                             libreadline-dev libssl-dev libtool llvm lrzsz msmtp ninja-build p7zip p7zip-full patch pkgconf \
                             python3 python3-pyelftools python3-setuptools qemu-utils rsync scons squashfs-tools subversion \
                             swig texinfo uglifyjs upx-ucl vim wget xmlto xxd zlib1g-dev diff find gcc-6+ getopt grep install libc-dev libz-dev \
                             make4.1+ perl python3.7+ unzip which
  sudo -E apt-get -y autoremove --purge
  sudo -E apt-get clean
  df -h
}

function clone_source_code() {
  git clone "$REPO_URL" -b "$REPO_BRANCH" "$SOURCE_PATH"
  cd "$SOURCE_PATH" || exit 1
}

function update_feeds() {
  cd "$SOURCE_PATH" || exit 1
  ./scripts/feeds update -a
  ./scripts/feeds install -a
}

function build_config() {
  cd "$SOURCE_PATH" || exit 1
  cp -f "${BUILDER_PATH}/config/${CONFIG_FILE}" .config
  cat "${BUILDER_PATH}/config/common.seed" >> .config
  echo -e 'CONFIG_DEVEL=y' >> .config
  echo -e 'CONFIG_CCACHE=y' >> .config

  if [ "$REPO_BRANCH" == "openwrt-24.10" ]; then
    echo "OpenWrt 24.10"
    echo 'CONFIG_LINUX_6_6=y' >> .config
  fi
  if [ "$REPO_BRANCH" == "main" ]; then
    echo "OpenWrt SNAPSHOT"
    echo 'CONFIG_LINUX_6_12=y' >> .config
  fi

  if [ -f "${BUILDER_PATH}/script/diy.sh" ]; then
    bash -c "${BUILDER_PATH}/script/diy.sh ${SOURCE_PATH} ${BUILDER_PATH}"
  fi
  du -h --max-depth=2 ./
  echo "当前配置=====start"
  cat .config
  echo "当前配置=====end"
}

function make_download() {
  cd "$SOURCE_PATH" || exit 1
  make defconfig
  make download -j8
  find ./dl/ -size -1024c -exec rm -f {} \;
  df -h
}

function compile_firmware() {
  cd "$SOURCE_PATH" || exit 1
  make -j$(nproc) || make -j1 V=s
  if [ $? -ne 0 ]; then
    echo "编译失败！！！"
    exit 1
  fi
  echo "编译完成"
  echo "======================="
  echo "Space usage:"
  echo "======================="
  df -h
  echo "======================="
  du -h --max-depth=1 ./ --exclude=build_dir --exclude=bin
  du -h --max-depth=1 ./build_dir
  du -h --max-depth=1 ./bin
}

function build_imagebuilder_config() {
  cd "$SOURCE_PATH" || exit 1
  cp -f "${BUILDER_PATH}/config/${CONFIG_FILE}" .config
  cat "${BUILDER_PATH}/config/common.seed" >> .config
  echo -e 'CONFIG_DEVEL=y' >> .config
  echo -e 'CONFIG_CCACHE=y' >> .config
  # 启用ImageBuilder构建
  echo -e 'CONFIG_IB=y' >> .config

  if [ "$REPO_BRANCH" == "openwrt-24.10" ]; then
    echo "OpenWrt 24.10"
    echo 'CONFIG_LINUX_6_6=y' >> .config
  fi
  if [ "$REPO_BRANCH" == "main" ]; then
    echo "OpenWrt SNAPSHOT"
    echo 'CONFIG_LINUX_6_12=y' >> .config
  fi

  if [ -f "${BUILDER_PATH}/script/diy.sh" ]; then
    bash -c "${BUILDER_PATH}/script/diy.sh ${SOURCE_PATH} ${BUILDER_PATH}"
  fi
  du -h --max-depth=2 ./
  echo "当前ImageBuilder配置=====start"
  cat .config
  echo "当前ImageBuilder配置=====end"
}

function compile_imagebuilder() {
  cd "$SOURCE_PATH" || exit 1
  make -j$(nproc) || make -j1 V=s
  if [ $? -ne 0 ]; then
    echo "ImageBuilder编译失败！！！"
    exit 1
  fi
  echo "ImageBuilder编译完成"
  echo "======================="
  echo "Space usage:"
  echo "======================="
  df -h
  echo "======================="
  du -h --max-depth=1 ./ --exclude=build_dir --exclude=bin
  du -h --max-depth=1 ./build_dir
  du -h --max-depth=1 ./bin
}

function download_imagebuilder() {
  echo "开始下载ImageBuilder..."
  
  # 根据设备类型确定ImageBuilder文件名
  case "$DEVICE" in
    "nanopi-r5s")
      IMAGEBUILDER_FILE="openwrt-imagebuilder-rockchip-armv8.Linux-x86_64.tar.zst"
      ;;
    "cudy-tr3000")
      IMAGEBUILDER_FILE="openwrt-imagebuilder-mediatek-filogic.Linux-x86_64.tar.zst"
      ;;
    "x86_64")
      IMAGEBUILDER_FILE="openwrt-imagebuilder-x86-64.Linux-x86_64.tar.zst"
      ;;
    *)
      echo "不支持的设备类型: $DEVICE"
      exit 1
      ;;
  esac
  
  # 构建GitHub Release下载URL
  RELEASE_TAG="imagebuilder-${REPO_BRANCH}-${DEVICE}"
  GITHUB_REPO="${GITHUB_REPOSITORY:-dd-ray/openwrt-builder}"
  DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/${RELEASE_TAG}/${IMAGEBUILDER_FILE}"
  
  echo "从GitHub Release下载ImageBuilder..."
  echo "设备: $DEVICE"
  echo "分支: $REPO_BRANCH"
  echo "Release标签: $RELEASE_TAG"
  echo "文件: $IMAGEBUILDER_FILE"
  echo "下载URL: $DOWNLOAD_URL"
  
  # 下载ImageBuilder
  cd "$BUILDER_PATH" || exit 1
  echo "开始下载..."
  
  # 检查文件格式并使用相应的文件名
  if [[ "$IMAGEBUILDER_FILE" == *.tar.zst ]]; then
    OUTPUT_FILE="imagebuilder.tar.zst"
  else
    OUTPUT_FILE="imagebuilder.tar.xz"
  fi
  
  wget -O "$OUTPUT_FILE" "$DOWNLOAD_URL"
  
  if [ $? -ne 0 ]; then
    echo "从GitHub Release下载失败，尝试从官方源下载..."
    
    # 备用：从官方源下载
    case "$DEVICE" in
      "nanopi-r5s")
        TARGET="rockchip/armv8"
        ;;
      "cudy-tr3000")
        TARGET="mediatek/filogic"
        ;;
      "x86_64")
        TARGET="x86/64"
        ;;
    esac
    
    if [ "$REPO_BRANCH" == "main" ]; then
      BASE_URL="https://downloads.openwrt.org/snapshots/targets"
    elif [ "$REPO_BRANCH" == "openwrt-24.10" ]; then
      BASE_URL="https://downloads.openwrt.org/releases/24.10-SNAPSHOT/targets"
    else
      echo "不支持的分支: $REPO_BRANCH"
      exit 1
    fi
    
    OFFICIAL_URL="${BASE_URL}/${TARGET}"
    OFFICIAL_FILE=$(curl -s "$OFFICIAL_URL/" | grep -o 'openwrt-imagebuilder-.*\.tar\.xz' | head -1)
    
    if [ -n "$OFFICIAL_FILE" ]; then
      echo "从官方源下载: ${OFFICIAL_URL}/${OFFICIAL_FILE}"
      wget -O imagebuilder.tar.xz "${OFFICIAL_URL}/${OFFICIAL_FILE}"
      
      if [ $? -ne 0 ]; then
        echo "官方源下载也失败！"
        exit 1
      fi
    else
      echo "未找到官方ImageBuilder文件！"
      exit 1
    fi
  fi
  
  echo "ImageBuilder下载完成"
}

function extract_imagebuilder() {
  echo "解压ImageBuilder..."
  cd "$BUILDER_PATH" || exit 1
  
  # 检查存在的ImageBuilder文件格式
  IMAGEBUILDER_ARCHIVE=""
  if [ -f "imagebuilder.tar.zst" ]; then
    IMAGEBUILDER_ARCHIVE="imagebuilder.tar.zst"
    echo "发现zstd格式的ImageBuilder文件"
  elif [ -f "imagebuilder.tar.xz" ]; then
    IMAGEBUILDER_ARCHIVE="imagebuilder.tar.xz"
    echo "发现xz格式的ImageBuilder文件"
  else
    echo "错误：未找到ImageBuilder文件！"
    echo "查找的文件: imagebuilder.tar.zst 或 imagebuilder.tar.xz"
    ls -la imagebuilder.* 2>/dev/null || echo "没有找到任何imagebuilder.*文件"
    exit 1
  fi
  
  echo "开始解压: $IMAGEBUILDER_ARCHIVE"
  
  # 根据文件格式选择解压命令
  if [[ "$IMAGEBUILDER_ARCHIVE" == *.tar.zst ]]; then
    # 检查是否安装了zstd
    if ! command -v zstd >/dev/null 2>&1; then
      echo "安装zstd解压工具..."
      if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y zstd
      elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y zstd
      elif command -v brew >/dev/null 2>&1; then
        brew install zstd
      else
        echo "错误：无法安装zstd工具，请手动安装"
        exit 1
      fi
    fi
    
    # 使用zstd解压
    zstd -d "$IMAGEBUILDER_ARCHIVE" -o imagebuilder.tar
    if [ $? -ne 0 ]; then
      echo "zstd解压失败！"
      exit 1
    fi
    tar -xf imagebuilder.tar
    rm -f imagebuilder.tar
  else
    # 使用标准tar命令解压xz格式
    tar -xf "$IMAGEBUILDER_ARCHIVE"
  fi
  
  if [ $? -ne 0 ]; then
    echo "ImageBuilder解压失败！"
    exit 1
  fi
  
  # 重命名解压目录
  IMAGEBUILDER_DIR=$(find . -maxdepth 1 -name "openwrt-imagebuilder-*" -type d | head -1)
  if [ -z "$IMAGEBUILDER_DIR" ]; then
    echo "解压后未找到ImageBuilder目录！"
    echo "当前目录内容："
    ls -la
    exit 1
  fi
  
  echo "找到ImageBuilder目录: $IMAGEBUILDER_DIR"
  mv "$IMAGEBUILDER_DIR" "imagebuilder-$DEVICE"
  echo "ImageBuilder解压完成: imagebuilder-$DEVICE"
  
  # 清理下载的压缩文件
  rm -f "$IMAGEBUILDER_ARCHIVE"
  echo "已清理压缩文件: $IMAGEBUILDER_ARCHIVE"
}

function prepare_packages() {
  echo "准备包列表..."
  cd "$BUILDER_PATH" || exit 1
  
  # 读取基础包列表
  BASE_PACKAGES=""
  if [ -f "config/imagebuilder/packages-${DEVICE}.list" ]; then
    echo "使用设备专用包列表: config/imagebuilder/packages-${DEVICE}.list"
    BASE_PACKAGES=$(cat "config/imagebuilder/packages-${DEVICE}.list" | grep -v '^#' | grep -v '^$' | tr '\n' ' ')
  elif [ -f "config/imagebuilder/packages-common.list" ]; then
    echo "使用通用包列表: config/imagebuilder/packages-common.list"
    BASE_PACKAGES=$(cat "config/imagebuilder/packages-common.list" | grep -v '^#' | grep -v '^$' | tr '\n' ' ')
  fi
  
  # 合并自定义包
  ALL_PACKAGES="$BASE_PACKAGES $CUSTOM_PACKAGES"
  
  # 添加要移除的包
  if [ -n "$REMOVE_PACKAGES" ]; then
    ALL_PACKAGES="$ALL_PACKAGES $REMOVE_PACKAGES"
  fi
  
  echo "最终包列表: $ALL_PACKAGES"
  echo "$ALL_PACKAGES" > package_list.txt
}

function build_with_imagebuilder() {
  echo "使用ImageBuilder构建固件..."
  cd "$BUILDER_PATH/imagebuilder-$DEVICE" || exit 1
  
  # 执行构建前脚本
  echo "执行构建前脚本..."
  if [ -f "$BUILDER_PATH/config/imagebuilder/scripts/pre-build.sh" ]; then
    export DEVICE="$DEVICE"
    export REPO_BRANCH="$REPO_BRANCH"
    bash "$BUILDER_PATH/config/imagebuilder/scripts/pre-build.sh"
    if [ $? -ne 0 ]; then
      echo "构建前脚本执行失败！"
      exit 1
    fi
  else
    echo "未找到构建前脚本，跳过"
  fi
  
  # 读取包列表
  PACKAGES=""
  if [ -f "../package_list.txt" ]; then
    PACKAGES=$(cat ../package_list.txt)
  fi
  
  echo "构建包列表: $PACKAGES"
  
  # 设置根文件系统大小
  case "$DEVICE" in
    "nanopi-r5s")
      ROOTFS_SIZE="944"
      ;;
    "cudy-tr3000")
      ROOTFS_SIZE="512"
      ;;
    "x86_64")
      ROOTFS_SIZE="1024"
      ;;
    *)
      ROOTFS_SIZE="512"
      ;;
  esac
  
  # 构建固件
  echo "开始构建固件..."
  if [ -n "$PACKAGES" ]; then
    make image PACKAGES="$PACKAGES" CONFIG_TARGET_ROOTFS_PARTSIZE=$ROOTFS_SIZE
  else
    make image CONFIG_TARGET_ROOTFS_PARTSIZE=$ROOTFS_SIZE
  fi
  
  if [ $? -ne 0 ]; then
    echo "ImageBuilder构建固件失败！"
    exit 1
  fi
  
  echo "ImageBuilder构建固件完成"
  
  # 执行构建后脚本
  echo "执行构建后脚本..."
  if [ -f "$BUILDER_PATH/config/imagebuilder/scripts/post-build.sh" ]; then
    export DEVICE="$DEVICE"
    export REPO_BRANCH="$REPO_BRANCH"
    bash "$BUILDER_PATH/config/imagebuilder/scripts/post-build.sh"
  else
    echo "未找到构建后脚本，跳过"
  fi
  
  echo "构建结果:"
  find bin/targets/ -name "*.bin" -o -name "*.img" -o -name "*.img.gz" | head -10
}

function parse_env() {
  case "$1" in
  install_dep)
    install_dep $2
    ;;
  clone)
    clone_source_code $2
    ;;
  update_feeds)
    update_feeds $2
    ;;
  build_config)
    build_config $2
    ;;
  build_imagebuilder_config)
    build_imagebuilder_config $2
    ;;
  make_download)
    make_download $2
    ;;
  compile_firmware)
    compile_firmware $2
    ;;
  compile_imagebuilder)
    compile_imagebuilder $2
    ;;
  download_imagebuilder)
    download_imagebuilder $2
    ;;
  extract_imagebuilder)
    extract_imagebuilder $2
    ;;
  prepare_packages)
    prepare_packages $2
    ;;
  build_with_imagebuilder)
    build_with_imagebuilder $2
    ;;
  *)
    echo "Usage: tool [install_dep|clone|update_feeds|build_config|build_imagebuilder_config|make_download|compile_firmware|compile_imagebuilder|download_imagebuilder|extract_imagebuilder|prepare_packages|build_with_imagebuilder]" >&2
    exit 1
    ;;
  esac
}
parse_env $@