#!/bin/bash
# ImageBuilder 构建前脚本
# 此脚本在ImageBuilder构建固件之前执行

echo "===== ImageBuilder 构建前脚本开始 ====="

# 获取当前工作目录
IMAGEBUILDER_DIR="$PWD"
CONFIG_DIR="../config/imagebuilder"

echo "当前目录: $IMAGEBUILDER_DIR"
echo "配置目录: $CONFIG_DIR"
echo "设备: ${DEVICE:-未指定}"
echo "分支: ${REPO_BRANCH:-未指定}"

# 检查配置目录是否存在
if [ ! -d "$CONFIG_DIR" ]; then
    echo "警告: 配置目录不存在: $CONFIG_DIR"
    echo "当前工作目录内容:"
    ls -la ../ 2>/dev/null || true
    
    # 尝试其他可能的路径
    if [ -d "../../config/imagebuilder" ]; then
        CONFIG_DIR="../../config/imagebuilder"
        echo "找到配置目录: $CONFIG_DIR"
    elif [ -d "${BUILDER_PATH}/config/imagebuilder" ]; then
        CONFIG_DIR="${BUILDER_PATH}/config/imagebuilder"
        echo "找到配置目录: $CONFIG_DIR"
    else
        echo "错误: 无法找到配置目录，跳过自定义配置"
        CONFIG_DIR=""
    fi
fi

# 1. 更新自定义feeds
echo "1. 处理自定义feeds..."
if [ -n "$CONFIG_DIR" ] && [ -f "$CONFIG_DIR/feeds.conf" ]; then
    echo "添加自定义feeds..."
    # 备份原始feeds.conf
    [ -f "feeds.conf.default" ] && cp feeds.conf.default feeds.conf.default.bak
    
    # 添加自定义feeds（去掉注释行和空行）
    grep -v '^#' "$CONFIG_DIR/feeds.conf" | grep -v '^$' >> feeds.conf.default
    
    echo "更新feeds..."
    ./scripts/feeds update -a
    ./scripts/feeds install -a
    echo "Feeds更新完成"
else
    echo "未找到自定义feeds配置，跳过"
fi

# 2. 应用配置文件覆盖
echo "2. 应用配置文件覆盖..."
if [ -n "$CONFIG_DIR" ] && [ -d "$CONFIG_DIR/configs" ]; then
    for config_file in "$CONFIG_DIR/configs"/*.conf; do
        if [ -f "$config_file" ]; then
            config_name=$(basename "$config_file" .conf)
            echo "应用配置: $config_name"
            # 这里可以根据需要处理特定的配置文件
            # 例如：cp "$config_file" "files/etc/config/$config_name"
        fi
    done
else
    echo "未找到配置覆盖目录，跳过"
fi

# 3. 复制自定义文件
echo "3. 复制自定义文件..."
if [ -n "$CONFIG_DIR" ] && [ -d "$CONFIG_DIR/files" ]; then
    echo "复制自定义文件到files目录..."
    cp -r "$CONFIG_DIR/files/"* files/ 2>/dev/null || true
    
    # 设置正确的权限
    find files -name "*.sh" -type f -exec chmod +x {} \;
    find files -path "*/etc/uci-defaults/*" -type f -exec chmod +x {} \;
    echo "自定义文件复制完成"
else
    echo "未找到自定义files目录，跳过"
fi

# 4. 执行设备特定的预构建脚本
echo "4. 执行设备特定脚本..."
if [ -n "$DEVICE" ] && [ -n "$CONFIG_DIR" ] && [ -f "$CONFIG_DIR/scripts/pre-build-${DEVICE}.sh" ]; then
    echo "执行设备特定脚本: pre-build-${DEVICE}.sh"
    bash "$CONFIG_DIR/scripts/pre-build-${DEVICE}.sh"
fi

# 5. 显示当前配置信息
echo "5. 显示构建信息..."
echo "设备: ${DEVICE:-未指定}"
echo "可用包列表示例:"
make info | head -20

echo "===== ImageBuilder 构建前脚本完成 =====" 