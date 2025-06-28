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
    sed -i 's/entry(\["admin", "services", "nft-qos"\]/entry(["admin", "network", "nft-qos"]/g' feeds/luci/applications/luci-app-nft-qos/luasrc/controller/nft-qos.lua 2>/dev/null || true
    sed -i 's/_("Qos Nftables")/_("QoS")/g' feeds/luci/applications/luci-app-nft-qos/luasrc/controller/nft-qos.lua 2>/dev/null || true

    # 修改 UPnP 插件菜单配置
    echo '修改 UPnP 插件菜单：从 services 移动到 network，名称改为 UPnP'
    sed -i 's/"admin\/services"/"admin\/network"/g' feeds/luci/applications/luci-app-upnp/root/usr/share/luci/menu.d/luci-app-upnp.json 2>/dev/null || true
    sed -i 's/"title": "UPnP IGD & PCP"/"title": "UPnP"/g' feeds/luci/applications/luci-app-upnp/root/usr/share/luci/menu.d/luci-app-upnp.json 2>/dev/null || true
    # 修改 ttyd 插件菜单配置
    echo '修改 ttyd 插件菜单：从 services 移动到 system'
    sed -i 's#admin/services/ttyd#admin/system/ttyd#g' feeds/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/luci-app-ttyd.json 2>/dev/null || true
    # 修改 nlbwmon 插件菜单配置
    echo '修改 nlbwmon 插件菜单：从 services 移动到 network'
    sed -i 's#admin/services/nlbw#admin/network/nlbw#g' feeds/luci/applications/luci-app-nlbwmon/root/usr/share/luci/menu.d/luci-app-nlbwmon.json 2>/dev/null || true
}

pushd $SOURCE_PATH
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate

echo '修改时区'
sed -i "s/'UTC'/'CST-8'\n        set system.@system[-1].zonename='Asia\/Shanghai'/g" package/base-files/files/bin/config_generate

echo '修改默认主题为argon'
sed -i 's/config internal themes/config internal themes\n    option Argon  \"\/luci-static\/argon\"/g' feeds/luci/modules/luci-base/root/etc/config/luci
sed -i 's/option mediaurlbase \/luci-static\/bootstrap/option mediaurlbase \"\/luci-static\/argon\"/g' feeds/luci/modules/luci-base/root/etc/config/luci

# wechatpush
git clone --depth 1 https://github.com/tty228/luci-app-wechatpush package/new/luci-app-wechatpush
git clone --depth 1 https://github.com/nikkinikki-org/OpenWrt-nikki package/new/openWrt-nikki
git clone --depth 1 https://github.com/vernesong/OpenClash package/new/openWrt-OpenClash

# tcp-brutal
git clone https://github.com/sbwml/package_kernel_tcp-brutal package/kernel/tcp-brutal

# Theme
git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon package/new/luci-theme-argon
git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config package/new/luci-app-argon-config

git clone --depth 1 https://github.com/sundaqiang/openwrt-packages.git package/new/openwrt-packages

sed -i '/<a href="https:\/\/github.com\/jerrykuku\/luci-theme-argon" target="_blank">ArgonTheme <%# vPKG_VERSION %><\/a> \//d' package/new/luci-theme-argon/luasrc/view/themes/argon/footer_login.htm
sed -i '/<a href="https:\/\/github.com\/jerrykuku\/luci-theme-argon" target="_blank">ArgonTheme <%# vPKG_VERSION %><\/a> \//d' package/new/luci-theme-argon/luasrc/view/themes/argon/footer.htm

# Mosdns
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
