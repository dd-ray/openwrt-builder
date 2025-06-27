#!/bin/bash

# OpenWrt设备到Toolchain类型映射表
# 用于确定不同设备使用的具体toolchain类型

function get_toolchain_type() {
    local device="$1"
    
    case "$device" in
        "nanopi-r5s")
            echo "aarch64_cortex-a53"
            ;;
        "cudy-tr3000")
            echo "aarch64_generic"
            ;;
        "x86_64")
            echo "x86_64"
            ;;
        *)
            echo "unknown"
            return 1
            ;;
    esac
}

function get_device_platform() {
    local device="$1"
    
    case "$device" in
        "nanopi-r5s"|"cudy-tr3000")
            echo "arm64"
            ;;
        "x86_64")
            echo "amd64"
            ;;
        *)
            echo "unknown"
            return 1
            ;;
    esac
}

function get_compatible_devices() {
    local toolchain_type="$1"
    
    case "$toolchain_type" in
        "aarch64_cortex-a53")
            echo "nanopi-r5s"
            ;;
        "aarch64_generic")
            echo "cudy-tr3000"
            ;;
        "x86_64")
            echo "x86_64"
            ;;
        *)
            echo ""
            return 1
            ;;
    esac
}

function list_all_mappings() {
    echo "📋 设备到Toolchain类型映射表："
    echo "┌─────────────────┬────────────────────┬──────────────┐"
    echo "│ 设备名称        │ Toolchain类型      │ 架构平台     │"
    echo "├─────────────────┼────────────────────┼──────────────┤"
    echo "│ nanopi-r5s      │ aarch64_cortex-a53 │ arm64        │"
    echo "│ cudy-tr3000     │ aarch64_generic    │ arm64        │"
    echo "│ x86_64          │ x86_64             │ amd64        │"
    echo "└─────────────────┴────────────────────┴──────────────┘"
    echo ""
    echo "💡 说明："
    echo "  - nanopi-r5s使用Cortex-A53优化的toolchain"
    echo "  - cudy-tr3000使用通用aarch64 toolchain"
    echo "  - 不同toolchain类型不兼容，需要分别构建"
}

function validate_device() {
    local device="$1"
    local toolchain_type
    
    toolchain_type=$(get_toolchain_type "$device")
    if [ "$toolchain_type" = "unknown" ]; then
        echo "❌ 不支持的设备: $device"
        echo "🔍 支持的设备列表："
        list_all_mappings
        return 1
    fi
    
    echo "✅ 设备: $device -> Toolchain: $toolchain_type"
    return 0
}

# 如果直接运行此脚本
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    case "$1" in
        "get-toolchain-type")
            get_toolchain_type "$2"
            ;;
        "get-device-platform")
            get_device_platform "$2"
            ;;
        "get-compatible-devices")
            get_compatible_devices "$2"
            ;;
        "list-mappings")
            list_all_mappings
            ;;
        "validate-device")
            validate_device "$2"
            ;;
        *)
            echo "用法: $0 {get-toolchain-type|get-device-platform|get-compatible-devices|list-mappings|validate-device} [设备名称]"
            echo ""
            echo "命令："
            echo "  get-toolchain-type <设备>     - 获取设备的toolchain类型"
            echo "  get-device-platform <设备>    - 获取设备的架构平台"
            echo "  get-compatible-devices <类型>  - 获取兼容的设备列表"
            echo "  list-mappings                  - 显示所有映射关系"
            echo "  validate-device <设备>         - 验证设备是否支持"
            echo ""
            echo "示例："
            echo "  $0 get-toolchain-type nanopi-r5s"
            echo "  $0 get-device-platform cudy-tr3000"
            echo "  $0 validate-device x86_64"
            echo "  $0 list-mappings"
            exit 1
            ;;
    esac
fi 