#!/bin/bash

#source_path="./openwrt-source"
#branch=24.10.0-rc7

# env
# REPO_URL=https://github.com/openwrt/openwrt
# REPO_BRANCH=24.10.0-rc7
# CONFIG_FILE=r5s.config
source_path=$SOURCE_PATH


function install_dep() {
  docker rmi `docker images -q`
  sudo rm -rf /usr/share/dotnet /etc/mysql /etc/php /etc/apt/sources.list.d /usr/local/lib/android
  sudo -E apt-get -y purge azure-cli ghc* zulu* hhvm llvm* firefox google* dotnet* powershell openjdk* adoptopenjdk* mysql* php* mongodb* dotnet* moby* snapd* || true
  sudo -E apt-get update
  sudo -E apt-get -y install install -y ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \
                             bzip2 ccache clang cmake cpio curl device-tree-compiler flex gawk gcc-multilib g++-multilib gettext \
                             genisoimage git gperf haveged help2man intltool libc6-dev-i386 libelf-dev libfuse-dev libglib2.0-dev \
                             libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses5-dev libncursesw5-dev libpython3-dev \
                             libreadline-dev libssl-dev libtool llvm lrzsz msmtp ninja-build p7zip p7zip-full patch pkgconf \
                             python3 python3-pyelftools python3-setuptools qemu-utils rsync scons squashfs-tools subversion \
                             swig texinfo uglifyjs upx-ucl unzip vim wget xmlto xxd zlib1g-dev
  sudo -E apt-get -y autoremove --purge
  sudo -E apt-get clean
  df -h
}

function clone_source_code() {
  git clone $REPO_URL -b $REPO_BRANCH $source_path
  cd $source_path || exit 1
}

function update_feeds() {
  cd $source_path || exit 1
  ./scripts/feeds update -a
  ./scripts/feeds install -a
}

function build_config() {
  cd $source_path || exit 1
  cp -f "../config/${CONFIG_FILE}" ".config"
  chmod +x ../script/diy.sh
  ../script/diy.sh "$(pwd)"
  du -h --max-depth=2 ./
  echo "当前配置=====start"
  cat '.config'
  echo "当前配置=====end"
}

function make_download() {
  cd $source_path || exit 1
  make defconfig
  make download -j8
  find ./dl/ -size -1024c -exec rm -f {} \;
  df -h
}

function compile_firmware() {
  cd $source_path || exit 1
  make -j$(nproc) || make -j1 V=s
  if [ $? -eq 0 ]; then
    echo "编译完成"
  else
    echo "编译完成！"
  fi
  echo "======================="
  echo "Space usage:"
  echo "======================="
  df -h
  echo "======================="
  du -h --max-depth=1 ./ --exclude=build_dir --exclude=bin
  du -h --max-depth=1 ./build_dir
  du -h --max-depth=1 ./bin
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
  make_download)
    make_download $2
    ;;
  compile_firmware)
    compile_firmware $2
    ;;
  *)
    echo "Usage: tool [install_dep|clone|update_feeds|build_config|make_download|compile_firmware]" >&2
    exit 1
    ;;
  esac
}
parse_env $@