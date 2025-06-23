#!/bin/bash
#=================================================
# Description: DIY script
# Lisence: MIT
# Author: P3TERX
# Blog: https://p3terx.com
#=================================================
SOURCE_PATH=$1
echo "源码所在路径: $SOURCE_PATH"
echo '修改网关地址'
cat "$SOURCE_PATH/package/base-files/files/bin/config_generate"

function use_shortcut_fe() {

    mirror=https://github.com/dd-ray/r5s_build_script/raw/refs/heads/main
    # Shortcut Forwarding Engine
    git clone https://github.com/dd-ray/shortcut-fe package/new/shortcut-fe

    # firewall4
    sed -i 's|$(PROJECT_GIT)/project|https://github.com/openwrt|g' package/network/config/firewall4/Makefile
    mkdir -p package/network/config/firewall4/patches
    # fix ct status dnat

    curl -sL $mirror/openwrt/patch/firewall4/firewall4_patches/990-unconditionally-allow-ct-status-dnat.patch >package/network/config/firewall4/patches/990-unconditionally-allow-ct-status-dnat.patch
    # fullcone
    curl -sL $mirror/openwrt/patch/firewall4/firewall4_patches/999-01-firewall4-add-fullcone-support.patch >package/network/config/firewall4/patches/999-01-firewall4-add-fullcone-support.patch
    # bcm fullcone
    curl -sL $mirror/openwrt/patch/firewall4/firewall4_patches/999-02-firewall4-add-bcm-fullconenat-support.patch >package/network/config/firewall4/patches/999-02-firewall4-add-bcm-fullconenat-support.patch
    # kernel version
    curl -sL $mirror/openwrt/patch/firewall4/firewall4_patches/002-fix-fw4.uc-adept-kernel-version-type-of-x.x.patch >package/network/config/firewall4/patches/002-fix-fw4.uc-adept-kernel-version-type-of-x.x.patch
    # fix flow offload
    curl -sL $mirror/openwrt/patch/firewall4/firewall4_patches/001-fix-fw4-flow-offload.patch >package/network/config/firewall4/patches/001-fix-fw4-flow-offload.patch
    # add custom nft command support
    curl -sL $mirror/openwrt/patch/firewall4/100-openwrt-firewall4-add-custom-nft-command-support.patch | patch -p1
    # libnftnl
    mkdir -p package/libs/libnftnl/patches
    curl -sL $mirror/openwrt/patch/firewall4/libnftnl/0001-libnftnl-add-fullcone-expression-support.patch >package/libs/libnftnl/patches/0001-libnftnl-add-fullcone-expression-support.patch
    curl -sL $mirror/openwrt/patch/firewall4/libnftnl/0002-libnftnl-add-brcm-fullcone-support.patch >package/libs/libnftnl/patches/0002-libnftnl-add-brcm-fullcone-support.patch
    # nftables
    mkdir -p package/network/utils/nftables/patches
    curl -sL $mirror/openwrt/patch/firewall4/nftables/0001-nftables-add-fullcone-expression-support.patch >package/network/utils/nftables/patches/0001-nftables-add-fullcone-expression-support.patch
    curl -sL $mirror/openwrt/patch/firewall4/nftables/0002-nftables-add-brcm-fullconenat-support.patch >package/network/utils/nftables/patches/0002-nftables-add-brcm-fullconenat-support.patch
    curl -sL $mirror/openwrt/patch/firewall4/nftables/0003-drop-rej-file.patch >package/network/utils/nftables/patches/0003-drop-rej-file.patch

    # FullCone module
    git clone https://github.com/dd-ray/nft-fullcone package/new/nft-fullcone

    # IPv6 NAT
    git clone https://github.com/sbwml/packages_new_nat6 package/new/nat6

    # natflow
    git clone https://github.com/sbwml/package_new_natflow package/new/natflow

    # Patch Luci add nft_fullcone/bcm_fullcone & shortcut-fe & natflow & ipv6-nat & custom nft command option
    pushd feeds/luci
    curl -sL $mirror/openwrt/patch/firewall4/luci-24.10/0001-luci-app-firewall-add-nft-fullcone-and-bcm-fullcone-.patch | patch -p1
    curl -sL $mirror/openwrt/patch/firewall4/luci-24.10/0002-luci-app-firewall-add-shortcut-fe-option.patch | patch -p1
    curl -sL $mirror/openwrt/patch/firewall4/luci-24.10/0003-luci-app-firewall-add-ipv6-nat-option.patch | patch -p1
    curl -sL $mirror/openwrt/patch/firewall4/luci-24.10/0004-luci-add-firewall-add-custom-nft-rule-support.patch | patch -p1
    curl -sL $mirror/openwrt/patch/firewall4/luci-24.10/0005-luci-app-firewall-add-natflow-offload-support.patch | patch -p1
    curl -sL $mirror/openwrt/patch/firewall4/luci-24.10/0006-luci-app-firewall-enable-hardware-offload-only-on-de.patch | patch -p1
    curl -sL $mirror/openwrt/patch/firewall4/luci-24.10/0007-luci-app-firewall-add-fullcone6-option-for-nftables-.patch | patch -p1
    

}

function use_mosdns() {
    # Mosdns
    rm -rf "feeds/packages/net/v2ray-geodata"
    git clone https://github.com/sbwml/luci-app-mosdns -b v5 package/new/mosdns
    git clone https://github.com/sbwml/v2ray-geodata package/new/v2ray-geodata
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

sed -i '/<a href="https:\/\/github.com\/jerrykuku\/luci-theme-argon" target="_blank">ArgonTheme <%# vPKG_VERSION %><\/a> \//d' package/new/luci-theme-argon/luasrc/view/themes/argon/footer_login.htm
sed -i '/<a href="https:\/\/github.com\/jerrykuku\/luci-theme-argon" target="_blank">ArgonTheme <%# vPKG_VERSION %><\/a> \//d' package/new/luci-theme-argon/luasrc/view/themes/argon/footer.htm

# Mosdns
rm -rf "feeds/packages/net/v2ray-geodata"
git clone https://github.com/sbwml/luci-app-mosdns -b v5 package/new/mosdns
git clone https://github.com/sbwml/v2ray-geodata package/new/v2ray-geodata

# 修补 rust 包 Makefile 中的 --set=llvm.download-ci-llvm=true
sed -i 's/--set=llvm\.download-ci-llvm=true/--set=llvm.download-ci-llvm=false/' feeds/packages/lang/rust/Makefile
use_shortcut_fe
popd
