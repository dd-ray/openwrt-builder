#!/bin/bash
# NanoPi R5S 设备特定的构建前脚本

echo "===== NanoPi R5S 设备特定配置开始 ====="

# ARM64优化设置
echo "设置ARM64优化选项..."

# 确保有必要的内核模块
echo "检查ARM64相关包..."

# 添加设备特定的文件覆盖
if [ -d "../config/imagebuilder/files-nanopi-r5s" ]; then
    echo "复制NanoPi R5S特定文件..."
    cp -r ../config/imagebuilder/files-nanopi-r5s/* files/ 2>/dev/null || true
fi

# 设置性能调节器
echo "配置CPU性能调节器为performance..."
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/98-nanopi-r5s-performance << 'EOF'
#!/bin/sh
# 设置CPU性能调节器
echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
echo performance > /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor
echo performance > /sys/devices/system/cpu/cpu2/cpufreq/scaling_governor
echo performance > /sys/devices/system/cpu/cpu3/cpufreq/scaling_governor
exit 0
EOF
chmod +x files/etc/uci-defaults/98-nanopi-r5s-performance

# 优化网络接口配置
echo "优化网络接口配置..."
mkdir -p files/etc/config
cat > files/etc/config/network << 'EOF'
config interface 'loopback'
	option ifname 'lo'
	option proto 'static'
	option ipaddr '127.0.0.1'
	option netmask '255.0.0.0'

config globals 'globals'
	option ula_prefix 'fd12:3456:789a::/48'

config interface 'lan'
	option type 'bridge'
	option ifname 'eth0'
	option proto 'static'
	option ipaddr '192.168.2.1'
	option netmask '255.255.255.0'
	option ip6assign '60'

config interface 'wan'
	option ifname 'eth1'
	option proto 'dhcp'

config interface 'wan6'
	option ifname 'eth1'
	option proto 'dhcpv6'
EOF

echo "===== NanoPi R5S 设备特定配置完成 =====" 