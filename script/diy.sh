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
    # 支持 turboacc
    curl -sSL https://raw.githubusercontent.com/dd-ray/turboacc/luci/add_turboacc.sh -o add_turboacc.sh && bash add_turboacc.sh --no-sfe
    popd
}

function config_enabled() {
    awk -v package_key="CONFIG_PACKAGE_${1}" -v config_key="CONFIG_${1}" '
        $0 == package_key "=y" || $0 == config_key "=y" { enabled = 1 }
        $0 == "# " package_key " is not set" || $0 == "# " config_key " is not set" { enabled = 0 }
        END { exit enabled ? 0 : 1 }
    ' "$SOURCE_PATH/.config"
}

function target_enabled() {
    grep -Eq "^CONFIG_TARGET_${1}=y$" "$SOURCE_PATH/.config"
}

function copy_files_overlay() {
    local overlay_path="$1"

    [ -d "$overlay_path" ] || return 0
    mkdir -p "$SOURCE_PATH/files"
    cp -a "$overlay_path/." "$SOURCE_PATH/files/"
}

function default_lan_ip() {
    if target_enabled mediatek_filogic_DEVICE_cudy_tr3000-v1-ubootmod; then
        echo "192.168.10.1"
    else
        echo "192.168.2.1"
    fi
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

pushd $SOURCE_PATH
LAN_IP="$(default_lan_ip)"
echo "默认 LAN IP: ${LAN_IP}"
sed -i "s/192.168.1.1/${LAN_IP}/g" package/base-files/files/bin/config_generate

echo '修改时区'
sed -i "s/'UTC'/'CST-8'\n        set system.@system[-1].zonename='Asia\/Shanghai'/g" package/base-files/files/bin/config_generate

echo '修改默认主题为argon'
sed -i 's/config internal themes/config internal themes\n    option Argon  \"\/luci-static\/argon\"/g' feeds/luci/modules/luci-base/root/etc/config/luci
sed -i 's/option mediaurlbase \/luci-static\/bootstrap/option mediaurlbase \"\/luci-static\/argon\"/g' feeds/luci/modules/luci-base/root/etc/config/luci

## 复制通用文件，再按目标设备叠加专属文件
copy_files_overlay "${BUILDER_PATH}/files"
if target_enabled mediatek_filogic_DEVICE_cudy_tr3000-v1-ubootmod; then
    echo '应用 Cudy TR3000 专属 LED 配置'
    copy_files_overlay "${BUILDER_PATH}/device-files/cudy-tr3000"
fi

if config_enabled luci-app-wechatpush; then
    git clone --depth 1 https://github.com/tty228/luci-app-wechatpush package/new/luci-app-wechatpush
fi
if config_enabled luci-app-nikki || config_enabled nikki; then
    git clone --depth 1 https://github.com/nikkinikki-org/OpenWrt-nikki package/new/openWrt-nikki
fi
if config_enabled luci-app-openclash; then
    git clone --depth 1 https://github.com/vernesong/OpenClash package/new/openWrt-OpenClash
fi

if config_enabled kmod-tcp-brutal; then
    git clone https://github.com/sbwml/package_kernel_tcp-brutal package/kernel/tcp-brutal
fi

if config_enabled luci-app-temp-status; then
    git clone --depth 1 https://github.com/gSpotx2f/luci-app-temp-status package/new/luci-app-temp-status
fi

if config_enabled luci-theme-argon; then
    git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon package/new/luci-theme-argon
fi
if config_enabled luci-app-argon-config; then
    git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config package/new/luci-app-argon-config
fi
# 移除 luci-theme-argon 版本信息
sed -i '/ArgonTheme.*vPKG_VERSION/d' package/new/luci-theme-argon/ucode/template/themes/argon/footer.ut 2>/dev/null || true
sed -i '/ArgonTheme.*vPKG_VERSION/d' package/new/luci-theme-argon/ucode/template/themes/argon/footer_login.ut 2>/dev/null || true

if config_enabled luci-app-wolplus; then
    git clone --depth 1 https://github.com/sundaqiang/openwrt-packages.git package/new/openwrt-packages
fi

if config_enabled luci-app-mosdns || config_enabled mosdns || config_enabled v2ray-geoip || config_enabled v2ray-geosite; then
    if [ "$REPO_BRANCH" == "openwrt-24.10" ]; then
        rm -rf feeds/packages/lang/golang
        git clone https://github.com/sbwml/packages_lang_golang -b 24.x feeds/packages/lang/golang
    fi
    rm -rf "feeds/packages/net/v2ray-geodata"
    git clone https://github.com/sbwml/luci-app-mosdns -b v5 package/new/mosdns
    git clone https://github.com/sbwml/v2ray-geodata package/new/v2ray-geodata
fi

# 修补 rust 包 Makefile 中的 --set=llvm.download-ci-llvm=true
sed -i 's/--set=llvm\.download-ci-llvm=true/--set=llvm.download-ci-llvm=false/' feeds/packages/lang/rust/Makefile
if config_enabled luci-app-turboacc; then
    use_turboacc
fi
# The --no-sfe mode still leaves optional SFE dependencies in some generated
# luci-app-turboacc Makefiles. Remove them so package index generation stays
# clean on current OpenWrt branches where these kmods are not present.
sed -i 's/ +kmod-fast-classifier//g; s/ +kmod-shortcut-fe-cm//g; s/ +kmod-shortcut-fe-drv//g' package/turboacc/luci-app-turboacc/Makefile 2>/dev/null || true
# 修复 turboacc 的 luci-nginx 依赖
sed -i 's/+luci +luci-compat/+luci-nginx +luci-compat/g' package/turboacc/luci-app-turboacc/Makefile
update_luci_app_menu

popd
