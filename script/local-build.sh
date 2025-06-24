#!/bin/bash

# OpenWrt 本地构建脚本
# 使用方法: ./local-build.sh [设备配置文件]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 默认配置
DEFAULT_REPO_URL="https://github.com/openwrt/openwrt"
DEFAULT_REPO_BRANCH="main"
DEFAULT_CONFIG_FILE="nanopi-r5s.seed"
DEFAULT_SOURCE_PATH="./openwrt-source"
DEFAULT_BUILDER_PATH="$(pwd)"

# 获取配置
REPO_URL="${REPO_URL:-$DEFAULT_REPO_URL}"
REPO_BRANCH="${REPO_BRANCH:-$DEFAULT_REPO_BRANCH}"
CONFIG_FILE="${1:-$DEFAULT_CONFIG_FILE}"
SOURCE_PATH="${SOURCE_PATH:-$DEFAULT_SOURCE_PATH}"
BUILDER_PATH="${BUILDER_PATH:-$DEFAULT_BUILDER_PATH}"

# 检查是否在正确的目录
check_directory() {
    print_info "检查当前目录..."
    if [ ! -f "script/tool.sh" ] || [ ! -d "config" ]; then
        print_error "请在 openwrt-builder 根目录下运行此脚本"
        exit 1
    fi
    print_success "目录检查通过"
}

# 检查配置文件是否存在
check_config_file() {
    print_info "检查配置文件: $CONFIG_FILE"
    if [ ! -f "config/$CONFIG_FILE" ]; then
        print_error "配置文件 config/$CONFIG_FILE 不存在"
        print_info "可用的配置文件:"
        ls -1 config/
        exit 1
    fi
    print_success "配置文件检查通过"
}

# 检查系统依赖
check_dependencies() {
    print_info "检查系统依赖..."
    local missing_deps=()
    
    # 检查必要的命令
    local required_commands=("git" "make" "gcc" "g++" "python3" "wget" "curl")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "缺少必要的依赖: ${missing_deps[*]}"
        print_info "请运行以下命令安装依赖:"
        print_info "sudo apt-get update && sudo apt-get install -y ${missing_deps[*]}"
        exit 1
    fi
    print_success "系统依赖检查通过"
}

# 检查磁盘空间
check_disk_space() {
    print_info "检查磁盘空间..."
    local available_space=$(df . | awk 'NR==2 {print $4}')
    local required_space=20971520  # 20GB in KB
    
    if [ "$available_space" -lt "$required_space" ]; then
        print_warning "可用磁盘空间不足 20GB，可能导致构建失败"
        print_info "当前可用空间: $(df -h . | awk 'NR==2 {print $4}')"
    else
        print_success "磁盘空间充足"
    fi
}

# 清理旧的构建
clean_old_build() {
    print_info "清理旧的构建..."
    if [ -d "$SOURCE_PATH" ]; then
        print_warning "检测到旧的源码目录，正在删除..."
        rm -rf "$SOURCE_PATH"
        print_success "旧的源码目录已删除"
    fi
}

# 克隆源代码
clone_source() {
    print_info "克隆 OpenWrt 源代码..."
    print_info "仓库: $REPO_URL"
    print_info "分支: $REPO_BRANCH"
    print_info "目标目录: $SOURCE_PATH"
    
    git clone "$REPO_URL" -b "$REPO_BRANCH" "$SOURCE_PATH" --depth=1
    if [ $? -eq 0 ]; then
        print_success "源代码克隆成功"
    else
        print_error "源代码克隆失败"
        exit 1
    fi
}

# 更新 feeds
update_feeds() {
    print_info "更新 feeds..."
    cd "$SOURCE_PATH" || exit 1
    
    ./scripts/feeds update -a
    if [ $? -eq 0 ]; then
        print_success "feeds 更新成功"
    else
        print_error "feeds 更新失败"
        exit 1
    fi
    
    ./scripts/feeds install -a
    if [ $? -eq 0 ]; then
        print_success "feeds 安装成功"
    else
        print_error "feeds 安装失败"
        exit 1
    fi
    
    cd - > /dev/null
}

# 应用配置和补丁
apply_config() {
    print_info "应用配置和补丁..."
    cd "$SOURCE_PATH" || exit 1
    
    # 复制配置文件
    cp -f "${BUILDER_PATH}/config/${CONFIG_FILE}" ".config"
    print_success "配置文件复制成功"
    
    # 添加开发者选项
    echo -e 'CONFIG_DEVEL=y\nCONFIG_CCACHE=y' >> .config
    
    # 运行自定义脚本
    if [ -f "${BUILDER_PATH}/script/diy.sh" ]; then
        print_info "运行自定义脚本..."
        chmod +x "${BUILDER_PATH}/script/diy.sh"
        bash -c "${BUILDER_PATH}/script/diy.sh ${SOURCE_PATH} ${BUILDER_PATH}"
        print_success "自定义脚本运行完成"
    fi
    
    cd - > /dev/null
}

# 下载依赖
download_packages() {
    print_info "下载依赖包..."
    cd "$SOURCE_PATH" || exit 1
    
    make defconfig
    if [ $? -eq 0 ]; then
        print_success "defconfig 生成成功"
    else
        print_error "defconfig 生成失败"
        exit 1
    fi
    
    make download -j8
    if [ $? -eq 0 ]; then
        print_success "依赖包下载成功"
    else
        print_error "依赖包下载失败"
        exit 1
    fi
    
    # 清理小文件
    find ./dl/ -size -1024c -exec rm -f {} \;
    
    cd - > /dev/null
}

# 编译固件
compile_firmware() {
    print_info "开始编译固件..."
    cd "$SOURCE_PATH" || exit 1
    
    local start_time=$(date +%s)
    
    # 先尝试多线程编译
    print_info "尝试多线程编译 (使用 $(nproc) 个线程)..."
    make -j$(nproc) || {
        print_warning "多线程编译失败，切换到单线程详细模式..."
        make -j1 V=s
    }
    
    if [ $? -eq 0 ]; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        print_success "固件编译成功！耗时: $((duration / 60)) 分钟 $((duration % 60)) 秒"
    else
        print_error "固件编译失败"
        exit 1
    fi
    
    cd - > /dev/null
}

# 显示构建结果
show_build_results() {
    print_info "构建结果:"
    print_info "======================="
    
    if [ -d "$SOURCE_PATH/bin" ]; then
        print_success "固件文件位置: $SOURCE_PATH/bin"
        print_info "固件列表:"
        find "$SOURCE_PATH/bin" -name "*.bin" -o -name "*.img" -o -name "*.tar.gz" | head -10
    else
        print_error "未找到固件文件"
    fi
    
    print_info "======================="
    print_info "磁盘使用情况:"
    df -h
    print_info "======================="
}

# 显示使用帮助
show_help() {
    echo "OpenWrt 本地构建脚本"
    echo ""
    echo "使用方法:"
    echo "  $0 [配置文件名]"
    echo ""
    echo "参数:"
    echo "  配置文件名    可选，默认为 $DEFAULT_CONFIG_FILE"
    echo ""
    echo "环境变量:"
    echo "  REPO_URL      OpenWrt 仓库地址，默认: $DEFAULT_REPO_URL"
    echo "  REPO_BRANCH   OpenWrt 分支，默认: $DEFAULT_REPO_BRANCH"
    echo "  SOURCE_PATH   源码目录，默认: $DEFAULT_SOURCE_PATH"
    echo "  BUILDER_PATH  构建脚本目录，默认: 当前目录"
    echo ""
    echo "示例:"
    echo "  $0                    # 使用默认配置"
    echo "  $0 cudy-tr3000.seed   # 使用指定配置"
    echo ""
    echo "可用的配置文件:"
    if [ -d "config" ]; then
        ls -1 config/
    fi
}

# 主函数
main() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        show_help
        exit 0
    fi
    
    print_info "开始 OpenWrt 本地构建..."
    print_info "配置文件: $CONFIG_FILE"
    print_info "源码分支: $REPO_BRANCH"
    print_info "源码目录: $SOURCE_PATH"
    
    # 执行构建步骤
    check_directory
    check_config_file
    check_dependencies
    check_disk_space
    clean_old_build
    clone_source
    update_feeds
    apply_config
    download_packages
    compile_firmware
    show_build_results
    
    print_success "构建完成！"
}

# 运行主函数
main "$@" 