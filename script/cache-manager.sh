#!/bin/bash

# OpenWrt Toolchain & CCache Manager
# 用于检测和管理toolchain、ccache的版本更新

REPO="${GITHUB_REPOSITORY:-dd-ray/openwrt-builder}"
REPO_BRANCH="${REPO_BRANCH:-main}"

function get_openwrt_commit() {
    local source_path="$1"
    if [ -d "$source_path/.git" ]; then
        cd "$source_path" && git rev-parse --short HEAD
    else
        echo "unknown"
    fi
}

function get_feeds_hash() {
    local source_path="$1"
    if [ -f "$source_path/feeds.conf.default" ]; then
        md5sum "$source_path/feeds.conf.default" | cut -d' ' -f1
    else
        echo "unknown"
    fi
}

function check_toolchain_update_needed() {
    local toolchain_type="$1"
    local source_path="$2"
    
    echo "🔍 Checking if toolchain update is needed..."
    echo "📋 Toolchain type: $toolchain_type"
    
    # 获取当前OpenWrt commit和feeds配置哈希
    local current_commit=$(get_openwrt_commit "$source_path")
    local current_feeds_hash=$(get_feeds_hash "$source_path")
    
    # 检查固定的toolchain release中是否存在对应的文件
    local toolchain_tag="toolchain"
    local toolchain_file="toolchain-${REPO_BRANCH}-${toolchain_type}.tar.gz"
    
    if gh release view "$toolchain_tag" >/dev/null 2>&1; then
        # 检查具体的toolchain文件是否存在
        if gh release view "$toolchain_tag" --json assets | jq -e ".assets[] | select(.name == \"$toolchain_file\")" >/dev/null 2>&1; then
            echo "📊 Toolchain Status:"
            echo "  Found: $toolchain_file in release $toolchain_tag"
            echo "  Current commit: $current_commit"
            echo "  Current feeds hash: $current_feeds_hash"
            
            # 获取文件的更新时间
            local file_date=$(gh release view "$toolchain_tag" --json assets | jq -r ".assets[] | select(.name == \"$toolchain_file\") | .updatedAt")
            echo "  File date: $file_date"
            
            # 简单检查：如果当前commit未知，或者想要强制重建，则需要更新
            if [ "$current_commit" == "unknown" ]; then
                echo "🚀 Toolchain update needed (unknown commit)"
                return 0
            else
                echo "✅ Toolchain file exists, assuming up to date"
                return 1
            fi
        else
            echo "🆕 Toolchain file not found: $toolchain_file, build needed"
            return 0
        fi
    else
        echo "🆕 No toolchain release found, build needed"
        return 0
    fi
}

function check_ccache_age() {
    local device_platform="$1"
    local max_age_days="$2"
    
    echo "🔍 Checking ccache age..."
    
    local ccache_tag="ccache"
    local ccache_file="ccache-${REPO_BRANCH}-${device_platform}.tar.gz"
    
    if gh release view "$ccache_tag" >/dev/null 2>&1; then
        # 检查具体的ccache文件是否存在
        if gh release view "$ccache_tag" --json assets | jq -e ".assets[] | select(.name == \"$ccache_file\")" >/dev/null 2>&1; then
            local file_date=$(gh release view "$ccache_tag" --json assets | jq -r ".assets[] | select(.name == \"$ccache_file\") | .updatedAt")
            local file_timestamp=$(date -d "$file_date" +%s)
            local current_timestamp=$(date +%s)
            local age_days=$(( (current_timestamp - file_timestamp) / 86400 ))
            
            echo "📊 CCache Status:"
            echo "  Found: $ccache_file in release $ccache_tag"
            echo "  File date: $file_date"
            echo "  Age: $age_days days"
            echo "  Max age: $max_age_days days"
            
            if [ $age_days -gt $max_age_days ]; then
                echo "🔄 CCache is old, refresh recommended"
                return 0
            else
                echo "✅ CCache is fresh"
                return 1
            fi
        else
            echo "🆕 CCache file not found: $ccache_file"
            return 0
        fi
    else
        echo "🆕 No ccache release found"
        return 0
    fi
}

function trigger_toolchain_build() {
    local toolchain_type="$1"
    local force_rebuild="${2:-false}"
    
    echo "🚀 Triggering toolchain build for $toolchain_type..."
    
    gh workflow run "toolchain-builder.yml" \
        -f REPO_URL="openwrt/openwrt" \
        -f REPO_BRANCH="$REPO_BRANCH" \
        -f FORCE_REBUILD="$force_rebuild"
}

function trigger_ccache_build() {
    local target_device="$1"
    local incremental="${2:-true}"
    
    echo "🚀 Triggering ccache build for $target_device..."
    
    gh workflow run "ccache-builder.yml" \
        -f REPO_URL="openwrt/openwrt" \
        -f REPO_BRANCH="$REPO_BRANCH" \
        -f TARGET_DEVICE="$target_device" \
        -f INCREMENTAL="$incremental"
}

function generate_build_cache_key() {
    local repo_branch="$1"
    local toolchain_type="$2"
    local config_path="${3:-config}"
    
    if [ -d "$config_path" ]; then
        local config_hash=$(find "$config_path" -name "*.seed" -type f -exec cat {} \; | md5sum | cut -d' ' -f1)
        echo "build-dir-${repo_branch}-${toolchain_type}-${config_hash}"
    else
        echo "build-dir-${repo_branch}-${toolchain_type}-unknown"
    fi
}

function validate_cache_system() {
    echo "🔍 Validating cache system configuration..."
    
    # 检查必要的脚本和配置文件
    local required_files=(
        "script/device-toolchain-mapping.sh"
        "config/nanopi-r5s.seed"
        "config/cudy-tr3000.seed"
        "config/x86_64.seed"
    )
    
    local missing_files=()
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        echo "❌ Missing required files:"
        printf "   %s\n" "${missing_files[@]}"
        return 1
    fi
    
    # 验证设备映射脚本
    source script/device-toolchain-mapping.sh
    local devices=("nanopi-r5s" "cudy-tr3000" "x86_64")
    
    for device in "${devices[@]}"; do
        local toolchain_type=$(get_toolchain_type "$device")
        local platform=$(get_device_platform "$device")
        
        if [ "$toolchain_type" = "unknown" ] || [ "$platform" = "unknown" ]; then
            echo "❌ Invalid mapping for device: $device"
            return 1
        fi
        
        echo "✅ $device -> $toolchain_type ($platform)"
    done
    
    echo "✅ Cache system validation passed"
    return 0
}

function main() {
    case "$1" in
        check-toolchain)
            check_toolchain_update_needed "$2" "$3"
            ;;
        check-ccache-age)
            check_ccache_age "$2" "${3:-7}"
            ;;
        build-toolchain)
            trigger_toolchain_build "$2" "${3:-false}"
            ;;
        build-ccache)
            trigger_ccache_build "$2" "${3:-true}"
            ;;
        generate-cache-key)
            generate_build_cache_key "$2" "$3" "$4"
            ;;
        validate)
            validate_cache_system
            ;;
        auto-maintain)
            # 自动维护模式：检查并更新过期的缓存
            local toolchain_type="$2"
            local target_device="$3"
            local source_path="$4"
            
            echo "🔧 Auto maintenance mode for $toolchain_type ($target_device)"
            
            # 检查toolchain
            if check_toolchain_update_needed "$toolchain_type" "$source_path"; then
                echo "⚡ Auto-triggering toolchain build..."
                trigger_toolchain_build "$toolchain_type" "false"
            fi
            
            # 检查ccache（超过3天就更新）
            # ccache仍然按设备架构分组，因为它们可以在相同toolchain间共享
            local device_platform
            case "$toolchain_type" in
                "aarch64_cortex-a53"|"aarch64_generic") device_platform="arm64" ;;
                "x86_64") device_platform="amd64" ;;
                *) device_platform="unknown" ;;
            esac
            
            if check_ccache_age "$device_platform" "3"; then
                echo "⚡ Auto-triggering ccache update..."
                trigger_ccache_build "$target_device" "true"
            fi
            ;;
        *)
            echo "Usage: $0 {check-toolchain|check-ccache-age|build-toolchain|build-ccache|generate-cache-key|validate|auto-maintain}"
            echo ""
            echo "Commands:"
            echo "  check-toolchain <toolchain_type> <source_path>     - Check if toolchain needs update"
            echo "  check-ccache-age <platform> [max_days]             - Check ccache age"
            echo "  build-toolchain <toolchain_type> [force]           - Trigger toolchain build"
            echo "  build-ccache <device> [incremental]                - Trigger ccache build"
            echo "  generate-cache-key <branch> <toolchain> [config]   - Generate build_dir cache key"
            echo "  validate                                            - Validate cache system configuration"
            echo "  auto-maintain <toolchain_type> <device> <source>   - Auto maintenance mode"
            echo ""
            echo "Toolchain Types:"
            echo "  aarch64_cortex-a53  - For nanopi-r5s and similar cortex-a53 devices"
            echo "  aarch64_generic     - For cudy-tr3000 and generic aarch64 devices"
            echo "  x86_64              - For x86_64 devices"
            echo ""
            echo "Examples:"
            echo "  $0 check-toolchain aarch64_cortex-a53 /openwrt/openwrt-source"
            echo "  $0 check-ccache-age arm64 7"
            echo "  $0 build-toolchain aarch64_generic false"
            echo "  $0 build-ccache nanopi-r5s true"
            echo "  $0 generate-cache-key main aarch64_cortex-a53 config"
            echo "  $0 validate"
            echo "  $0 auto-maintain aarch64_cortex-a53 nanopi-r5s /openwrt/openwrt-source"
            exit 1
            ;;
    esac
}

main "$@" 