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
sed -i 's/192.168.1.1/192.168.2.1/g' "$SOURCE_PATH/package/base-files/files/bin/config_generate"

echo '修改时区'
sed -i "s/'UTC'/'CST-8'\n        set system.@system[-1].zonename='Asia\/Shanghai'/g" "$SOURCE_PATH/package/base-files/files/bin/config_generate"

echo '修改默认主题为argon'
sed -i 's/config internal themes/config internal themes\n    option Argon  \"\/luci-static\/argon\"/g' "$SOURCE_PATH/feeds/luci/modules/luci-base/root/etc/config/luci"
sed -i 's/option mediaurlbase \/luci-static\/bootstrap/option mediaurlbase \"\/luci-static\/argon\"/g' "$SOURCE_PATH/feeds/luci/modules/luci-base/root/etc/config/luci"

# wechatpush
git clone --depth 1 https://github.com/tty228/luci-app-wechatpush "${SOURCE_PATH}/package/new/luci-app-wechatpush"
git clone --depth 1 https://github.com/nikkinikki-org/OpenWrt-nikki "${SOURCE_PATH}/package/new/openWrt-nikki"
git clone --depth 1 https://github.com/vernesong/OpenClash "${SOURCE_PATH}/package/new/openWrt-OpenClash"

# tcp-brutal
git clone https://github.com/sbwml/package_kernel_tcp-brutal "${SOURCE_PATH}/package/kernel/tcp-brutal"


# Theme
git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon "${SOURCE_PATH}/package/new/luci-theme-argon"
git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config "${SOURCE_PATH}/package/new/luci-app-argon-config"

sed -i '/<a href="https:\/\/github.com\/jerrykuku\/luci-theme-argon" target="_blank">ArgonTheme <%# vPKG_VERSION %><\/a> \//d' package/new/luci-theme-argon/luasrc/view/themes/argon/footer_login.htm
sed -i '/<a href="https:\/\/github.com\/jerrykuku\/luci-theme-argon" target="_blank">ArgonTheme <%# vPKG_VERSION %><\/a> \//d' package/new/luci-theme-argon/luasrc/view/themes/argon/footer.htm

# Mosdns
rm -rf "${SOURCE_PATH}/feeds/packages/net/v2ray-geodata"
git clone https://github.com/sbwml/luci-app-mosdns -b v5 "${SOURCE_PATH}/package/new/mosdns"
git clone https://github.com/sbwml/v2ray-geodata "${SOURCE_PATH}/package/new/v2ray-geodata"


# 修复 rust bootstrap 在 CI 上强制要求 download-ci-llvm=if-unchanged
# 首先修补 rust 包 Makefile 中的 --set=llvm.download-ci-llvm=true
MAKEFILE_PATH="$SOURCE_PATH/feeds/packages/lang/rust/Makefile"
if [ -f "$MAKEFILE_PATH" ]; then
  sed -i 's/--set=llvm.download-ci-llvm=true/--set=llvm.download-ci-llvm="if-unchanged"/g' "$MAKEFILE_PATH"
fi

CFG_FILES=$(grep -rl '^llvm.download-ci-llvm = true' \
            "$SOURCE_PATH/feeds/packages/lang/rust")
for f in $CFG_FILES; do
  sed -i 's/^llvm.download-ci-llvm = true/llvm.download-ci-llvm = "if-unchanged"/' "$f"
done