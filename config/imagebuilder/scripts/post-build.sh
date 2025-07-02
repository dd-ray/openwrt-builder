#!/bin/bash
# ImageBuilder 构建后脚本
# 此脚本在ImageBuilder构建固件之后执行

echo "===== ImageBuilder 构建后脚本开始 ====="

# 获取当前工作目录
IMAGEBUILDER_DIR="$PWD"

echo "当前目录: $IMAGEBUILDER_DIR"

# 1. 显示构建结果
echo "1. 构建结果统计..."
if [ -d "bin/targets" ]; then
    echo "固件文件列表:"
    find bin/targets -name "*.bin" -o -name "*.img" -o -name "*.img.gz" | while read file; do
        size=$(du -h "$file" | cut -f1)
        echo "  $file ($size)"
    done
    
    echo "构建信息文件:"
    find bin/targets -name "*.buildinfo" -o -name "*.manifest" | while read file; do
        echo "  $file"
    done
else
    echo "未找到构建输出目录"
fi

# 2. 验证关键文件
echo "2. 验证构建结果..."
error_count=0

# 检查是否有固件文件生成
if ! find bin/targets -name "*.bin" -o -name "*.img" | grep -q .; then
    echo "错误: 未找到固件文件!"
    error_count=$((error_count + 1))
fi

# 检查manifest文件
if ! find bin/targets -name "*.manifest" | grep -q .; then
    echo "警告: 未找到manifest文件"
fi

# 3. 清理临时文件
echo "3. 清理临时文件..."
# 清理一些不需要的临时文件
rm -rf tmp/ build_dir/hostpkg/ 2>/dev/null || true

# 4. 生成构建报告
echo "4. 生成构建报告..."
report_file="build-report-$(date +%Y%m%d-%H%M%S).txt"
{
    echo "ImageBuilder构建报告"
    echo "===================="
    echo "构建时间: $(date)"
    echo "设备: ${DEVICE:-未指定}"
    echo "分支: ${REPO_BRANCH:-未指定}"
    echo ""
    echo "构建结果:"
    find bin/targets -name "*.bin" -o -name "*.img" -o -name "*.img.gz" 2>/dev/null || echo "无固件文件"
    echo ""
    echo "包列表:"
    find bin/targets -name "*.manifest" -exec cat {} \; 2>/dev/null | head -20
} > "$report_file"

echo "构建报告已生成: $report_file"

# 5. 执行设备特定的后构建脚本
echo "5. 执行设备特定脚本..."
CONFIG_DIR="../config/imagebuilder"
if [ -n "$DEVICE" ] && [ -f "$CONFIG_DIR/scripts/post-build-${DEVICE}.sh" ]; then
    echo "执行设备特定脚本: post-build-${DEVICE}.sh"
    bash "$CONFIG_DIR/scripts/post-build-${DEVICE}.sh"
fi

if [ $error_count -gt 0 ]; then
    echo "构建完成，但发现 $error_count 个错误"
    exit 1
else
    echo "===== ImageBuilder 构建后脚本完成 ====="
fi 