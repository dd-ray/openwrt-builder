#!/bin/bash
#=================================================
# Description: DIY script
# Lisence: MIT
# Author: P3TERX
# Blog: https://p3terx.com
#=================================================

SOURCE_PATH=$1
BUILDER_PATH=$2
echo "源码所在路径: $SOURCE_PATH"
echo "脚本所在路径: $BUILDER_PATH"
echo '修改网关地址'

function use_turboacc() {
    pushd $SOURCE_PATH
    # 支持 turboacc 带 shortcut-fe
    curl -sSL https://raw.githubusercontent.com/chenmozhijin/turboacc/luci/add_turboacc.sh -o add_turboacc.sh && bash add_turboacc.sh
    popd
}

function update_luci_app_menu() {
    # 修改 QoS Nftables 插件菜单配置
    echo '修改 QoS Nftables 插件菜单：从 services 移动到 network，名称改为 QoS'
    sed -i 's#entry({"admin", "services", "nft-qos"}#entry({"admin", "network", "nft-qos"}#g' feeds/luci/applications/luci-app-nft-qos/luasrc/controller/nft-qos.lua 2>/dev/null || true
    sed -i 's#QoS over Nftables#QoS#g' feeds/luci/applications/luci-app-nft-qos/luasrc/controller/nft-qos.lua 2>/dev/null || true

    # 修改 UPnP 插件菜单配置
    echo '修改 UPnP 插件菜单：从 services 移动到 network，名称改为 UPnP'
    sed -i 's#admin/services#admin/network#g' feeds/luci/applications/luci-app-upnp/root/usr/share/luci/menu.d/luci-app-upnp.json 2>/dev/null || true
    sed -i 's/"title": "UPnP IGD & PCP"/"title": "UPnP"/g' feeds/luci/applications/luci-app-upnp/root/usr/share/luci/menu.d/luci-app-upnp.json 2>/dev/null || true
    # 修改 ttyd 插件菜单配置
    echo '修改 ttyd 插件菜单：从 services 移动到 system'
    sed -i 's#admin/services/ttyd#admin/system/ttyd#g' feeds/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/luci-app-ttyd.json 2>/dev/null || true
    # 修改 nlbwmon 插件菜单配置
    echo '修改 nlbwmon 插件菜单：从 services 移动到 network'
    sed -i 's#admin/services#admin/network#g' feeds/luci/applications/luci-app-nlbwmon/root/usr/share/luci/menu.d/luci-app-nlbwmon.json 2>/dev/null || true
    # 修改 udpxy 插件菜单配置
    echo '修改 udpxy 插件菜单：从 services 移动到 network'
    sed -i 's#admin/services#admin/network#g' feeds/luci/applications/luci-app-udpxy/root/usr/share/luci/menu.d/luci-app-udpxy.json 2>/dev/null || true

}

function detect_device() {
    if [ -n "${DEVICE:-}" ]; then
        echo "$DEVICE"
        return 0
    fi

    if [ -n "${CONFIG_FILE:-}" ]; then
        echo "${CONFIG_FILE%.seed}"
        return 0
    fi

    if [ -f "$SOURCE_PATH/.config" ]; then
        if grep -q '^CONFIG_TARGET_x86_64=y' "$SOURCE_PATH/.config"; then
            echo "x86_64"
            return 0
        fi

        if grep -q '^CONFIG_TARGET_rockchip_armv8_DEVICE_friendlyarm_nanopi-r5s=y' "$SOURCE_PATH/.config"; then
            echo "nanopi-r5s"
            return 0
        fi

        if grep -q '^CONFIG_TARGET_mediatek_filogic_DEVICE_cudy_tr3000-v1-ubootmod=y' "$SOURCE_PATH/.config"; then
            echo "cudy-tr3000"
            return 0
        fi
    fi

    return 1
}

function install_openclash_core() {
    local device release_json tag_name asset_name download_url amd64_level
    local asset_name_prefix archive_file extracted_file
    local target_dir="$SOURCE_PATH/files/etc/openclash/core"
    local target_file="$target_dir/clash_meta"
    local link_path="$SOURCE_PATH/files/etc/openclash/clash"
    local tmp_dir

    if ! grep -q '^CONFIG_PACKAGE_luci-app-openclash=y' "$SOURCE_PATH/.config"; then
        echo "未启用 luci-app-openclash，跳过内置 mihomo 内核"
        return 0
    fi

    device=$(detect_device) || {
        echo "错误: 无法识别当前设备，无法下载 mihomo 内核"
        return 1
    }

    case "$device" in
        "nanopi-r5s"|"cudy-tr3000")
            asset_name_prefix="mihomo-linux-arm64"
            ;;
        "x86_64")
            amd64_level="${MIHOMO_AMD64_LEVEL:-default}"
            case "$amd64_level" in
                "default")
                    asset_name_prefix="mihomo-linux-amd64"
                    ;;
                "v1"|"v2"|"v3")
                    asset_name_prefix="mihomo-linux-amd64-${amd64_level}"
                    ;;
                *)
                    echo "错误: 不支持的 MIHOMO_AMD64_LEVEL=${amd64_level}，可选值: default, v1, v2, v3"
                    return 1
                    ;;
            esac
            ;;
        *)
            echo "错误: 不支持的设备 ${device}"
            return 1
            ;;
    esac

    echo "下载 OpenClash Meta 内核，设备: ${device}"
    if [ "$device" = "x86_64" ]; then
        echo "x86_64 默认使用普通 amd64 资产，可通过 MIHOMO_AMD64_LEVEL=v1/v2/v3 覆盖"
    fi

    release_json=$(curl -fsSL --retry 3 --connect-timeout 20 "https://api.github.com/repos/MetaCubeX/mihomo/releases/latest") || {
        echo "错误: 获取 mihomo 最新 release 失败"
        return 1
    }

    tag_name=$(printf '%s\n' "$release_json" | sed -n 's/.*"tag_name": "\(v[^"]*\)".*/\1/p' | head -n1)
    if [ -z "$tag_name" ]; then
        echo "错误: 无法解析 mihomo 最新 release tag"
        return 1
    fi

    asset_name="${asset_name_prefix}-${tag_name}.gz"
    if ! printf '%s\n' "$release_json" | grep -q "\"name\": \"${asset_name}\""; then
        echo "错误: 最新 release ${tag_name} 中未找到资产 ${asset_name}"
        return 1
    fi

    download_url="https://github.com/MetaCubeX/mihomo/releases/download/${tag_name}/${asset_name}"
    tmp_dir=$(mktemp -d) || {
        echo "错误: 无法创建临时目录"
        return 1
    }
    archive_file="$tmp_dir/${asset_name}"
    extracted_file="$tmp_dir/clash_meta"

    mkdir -p "$target_dir" || {
        rm -rf "$tmp_dir"
        echo "错误: 无法创建 OpenClash 目标目录"
        return 1
    }
    mkdir -p "$(dirname "$link_path")" || {
        rm -rf "$tmp_dir"
        echo "错误: 无法创建 OpenClash 软链目录"
        return 1
    }

    if ! curl -fL --retry 3 --connect-timeout 20 --retry-delay 2 -o "$archive_file" "$download_url"; then
        rm -rf "$tmp_dir"
        echo "错误: 下载 mihomo 资产失败: ${download_url}"
        return 1
    fi

    if ! gzip -t "$archive_file"; then
        rm -rf "$tmp_dir"
        echo "错误: mihomo 下载文件不是有效的 gzip 包: ${asset_name}"
        return 1
    fi

    if ! gzip -dc "$archive_file" > "$extracted_file"; then
        rm -rf "$tmp_dir"
        echo "错误: 解压 mihomo 资产失败"
        return 1
    fi

    if [ ! -s "$extracted_file" ]; then
        rm -rf "$tmp_dir"
        echo "错误: 解压后的 mihomo 内核为空文件"
        return 1
    fi

    chmod 0755 "$extracted_file"
    mv "$extracted_file" "$target_file" || {
        rm -rf "$tmp_dir"
        echo "错误: 写入 OpenClash 内核文件失败"
        return 1
    }
    ln -snf /etc/openclash/core/clash_meta "$link_path"
    rm -rf "$tmp_dir"

    echo "已内置 mihomo 内核: ${target_file}"
    echo "已创建软链: ${link_path} -> /etc/openclash/core/clash_meta"
}

pushd $SOURCE_PATH
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate

echo '修改时区'
sed -i "s/'UTC'/'CST-8'\n        set system.@system[-1].zonename='Asia\/Shanghai'/g" package/base-files/files/bin/config_generate

echo '修改默认主题为argon'
sed -i 's/config internal themes/config internal themes\n    option Argon  \"\/luci-static\/argon\"/g' feeds/luci/modules/luci-base/root/etc/config/luci
sed -i 's/option mediaurlbase \/luci-static\/bootstrap/option mediaurlbase \"\/luci-static\/argon\"/g' feeds/luci/modules/luci-base/root/etc/config/luci

## 复制文件
cp -r "${BUILDER_PATH}/files" ./
install_openclash_core || exit 1

# wechatpush
git clone --depth 1 https://github.com/tty228/luci-app-wechatpush package/new/luci-app-wechatpush
git clone --depth 1 https://github.com/nikkinikki-org/OpenWrt-nikki package/new/openWrt-nikki
git clone --depth 1 https://github.com/vernesong/OpenClash package/new/openWrt-OpenClash

# tcp-brutal
git clone https://github.com/sbwml/package_kernel_tcp-brutal package/kernel/tcp-brutal

# Theme
git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon package/new/luci-theme-argon
git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config package/new/luci-app-argon-config
sed -i 's#<a href="https://github.com/jerrykuku/luci-theme-argon" target="_blank">ArgonTheme <%\# vPKG_VERSION %></a> |##g' package/new/luci-theme-argon/luasrc/view/themes/argon/footer_login.htm
sed -i 's#<a href="https://github.com/jerrykuku/luci-theme-argon" target="_blank">ArgonTheme <%\# vPKG_VERSION %></a>#<span class="footer-separator">|</span>#g' package/new/luci-theme-argon/luasrc/view/themes/argon/footer.htm
sed -i 's#<span class="footer-separator">|</span>##g' package/new/luci-theme-argon/luasrc/view/themes/argon/footer.htm

git clone --depth 1 https://github.com/sundaqiang/openwrt-packages.git package/new/openwrt-packages

sed -i '/<a href="https:\/\/github.com\/jerrykuku\/luci-theme-argon" target="_blank">ArgonTheme <%# vPKG_VERSION %><\/a> \//d' package/new/luci-theme-argon/luasrc/view/themes/argon/footer_login.htm
sed -i '/<a href="https:\/\/github.com\/jerrykuku\/luci-theme-argon" target="_blank">ArgonTheme <%# vPKG_VERSION %><\/a> \//d' package/new/luci-theme-argon/luasrc/view/themes/argon/footer.htm

# Mosdns
if [ "$REPO_BRANCH" == "openwrt-24.10" ]; then
    rm -rf feeds/packages/lang/golang
    git clone https://github.com/sbwml/packages_lang_golang -b 24.x feeds/packages/lang/golang
fi
rm -rf "feeds/packages/net/v2ray-geodata"
git clone https://github.com/sbwml/luci-app-mosdns -b v5 package/new/mosdns
git clone https://github.com/sbwml/v2ray-geodata package/new/v2ray-geodata

# 修补 rust 包 Makefile 中的 --set=llvm.download-ci-llvm=true
sed -i 's/--set=llvm\.download-ci-llvm=true/--set=llvm.download-ci-llvm=false/' feeds/packages/lang/rust/Makefile
use_turboacc
# 修复 turboacc 的 luci-nginx 依赖
sed -i 's/+luci +luci-compat/+luci-nginx +luci-compat/g' package/turboacc/luci-app-turboacc/Makefile
update_luci_app_menu

popd
