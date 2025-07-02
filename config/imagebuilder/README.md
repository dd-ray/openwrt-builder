# ImageBuilder 高级配置指南

本目录包含ImageBuilder的高级配置选项，支持自定义feeds、配置覆盖、文件替换等功能。

## 📁 目录结构

```
config/imagebuilder/
├── feeds.conf              # 自定义feeds配置
├── packages-*.list         # 包列表文件
├── configs/                # 配置文件覆盖
│   ├── network.conf        # 网络配置
│   ├── system.conf         # 系统配置
│   └── wireless.conf       # 无线配置
├── files/                  # 文件覆盖目录
│   └── etc/
│       ├── banner          # 自定义登录横幅
│       ├── config/         # UCI配置文件
│       └── uci-defaults/   # UCI默认脚本
├── scripts/                # 自定义脚本
│   ├── pre-build.sh        # 构建前脚本
│   ├── post-build.sh       # 构建后脚本
│   └── pre-build-*.sh      # 设备特定脚本
└── README.md               # 本文档
```

## 🚀 功能详解

### 1. 自定义Feeds (feeds.conf)

**用途**: 添加第三方软件源，从GitHub克隆包

**配置格式**:
```bash
# 从GitHub克隆
src-git 名称 https://github.com/用户名/仓库名.git [分支]

# 从其他Git源
src-git 名称 https://git.example.com/repo.git

# 本地源
src-link 名称 /path/to/local/packages
```

**示例配置**:
```bash
# 添加PassWall科学上网工具
src-git passwall https://github.com/xiaorouji/openwrt-passwall.git

# 添加自己的私有包
src-git mypkgs https://github.com/your-username/your-packages.git
```

**使用方法**:
1. 编辑 `feeds.conf` 文件
2. 添加需要的feeds源
3. 运行ImageBuilder构建，脚本会自动处理

### 2. 配置文件覆盖 (configs/)

**用途**: 修改OpenWrt默认配置，无需重新编译

**支持的配置类型**:
- `network.conf` - 网络接口配置
- `system.conf` - 系统基本配置
- `wireless.conf` - WiFi配置
- `dhcp.conf` - DHCP/DNS配置
- `firewall.conf` - 防火墙配置

**示例 - 修改LAN IP**:
```bash
# configs/network.conf
config interface 'lan'
    option proto 'static'
    option ipaddr '10.0.0.1'    # 修改为10.0.0.1
    option netmask '255.255.255.0'
```

### 3. 文件覆盖系统 (files/)

**用途**: 直接替换系统文件，实现深度定制

**常用场景**:
- 自定义登录横幅 (`etc/banner`)
- 修改默认配置文件 (`etc/config/*`)
- 添加启动脚本 (`etc/init.d/*`)
- 设置UCI默认配置 (`etc/uci-defaults/*`)
- 添加自定义主题和插件

**目录映射**:
```
files/etc/banner          → /etc/banner
files/etc/config/network  → /etc/config/network
files/etc/uci-defaults/*  → /etc/uci-defaults/*
```

**UCI默认脚本示例**:
```bash
#!/bin/sh
# files/etc/uci-defaults/99-custom

# 设置主机名
uci set system.@system[0].hostname='MyRouter'

# 设置WiFi
uci set wireless.default_radio0.ssid='MyWiFi'
uci set wireless.default_radio0.key='MyPassword'

uci commit
rm -f /etc/uci-defaults/99-custom
exit 0
```

### 4. 自定义脚本 (scripts/)

**构建前脚本 (pre-build.sh)**:
- 在固件构建前执行
- 用于准备环境、更新feeds、复制文件
- 自动集成到构建流程

**构建后脚本 (post-build.sh)**:
- 在固件构建后执行
- 用于验证结果、生成报告、清理文件
- 可以进行后处理操作

**设备特定脚本**:
- `pre-build-nanopi-r5s.sh` - NanoPi R5S专用
- `pre-build-x86_64.sh` - x86_64专用
- `pre-build-cudy-tr3000.sh` - Cudy TR3000专用

## 🔧 使用指南

### 场景1: 添加第三方软件包

1. **编辑feeds配置**:
```bash
# 编辑 feeds.conf
src-git helloworld https://github.com/fw876/helloworld.git
```

2. **添加包到列表**:
```bash
# 编辑 packages-common.list
luci-app-ssr-plus
shadowsocks-libev-ss-local
```

3. **运行构建**:
使用ImageBuilder Build workflow构建固件

### 场景2: 修改默认网络配置

1. **创建网络配置**:
```bash
# configs/network.conf
config interface 'lan'
    option ipaddr '192.168.100.1'  # 自定义IP
    option netmask '255.255.255.0'
```

2. **添加UCI脚本**:
```bash
# files/etc/uci-defaults/90-network
#!/bin/sh
uci set network.lan.ipaddr='192.168.100.1'
uci commit network
rm -f /etc/uci-defaults/90-network
exit 0
```

### 场景3: 自定义WiFi配置

1. **创建无线配置**:
```bash
# configs/wireless.conf
config wifi-iface 'default_radio0'
    option ssid 'MyCustomWiFi'
    option key 'MySecurePassword'
    option encryption 'psk2'
```

2. **添加到文件覆盖**:
```bash
# files/etc/config/wireless
# 完整的无线配置文件
```

### 场景4: 添加自定义主题

1. **添加主题feed**:
```bash
# feeds.conf
src-git mytheme https://github.com/your-username/luci-theme-mytheme.git
```

2. **添加主题包**:
```bash
# packages-common.list
luci-theme-mytheme
```

3. **设置默认主题**:
```bash
# files/etc/uci-defaults/95-theme
#!/bin/sh
uci set luci.main.mediaurlbase='/luci-static/mytheme'
uci commit luci
rm -f /etc/uci-defaults/95-theme
exit 0
```

## ⚠️ 注意事项

### 文件权限
- 脚本文件需要执行权限 (`chmod +x`)
- UCI默认脚本会在首次启动时执行一次

### 包依赖
- 确保添加的包在feeds中可用
- 检查包依赖关系，避免冲突

### 配置冲突
- UCI配置会覆盖默认设置
- 多个配置文件可能产生冲突，需要测试

### 构建顺序
1. 下载ImageBuilder
2. 执行pre-build.sh（更新feeds、复制文件）
3. 准备包列表
4. 构建固件
5. 执行post-build.sh（验证、清理）

## 🔍 调试技巧

### 查看可用包
```bash
# 在ImageBuilder目录执行
make info
```

### 检查feeds状态
```bash
./scripts/feeds list
./scripts/feeds show packagename
```

### 验证配置
```bash
# 检查UCI配置语法
uci show system
uci show network
```

### 查看构建日志
构建过程中的所有输出都会显示在GitHub Actions日志中，包括:
- Pre-build脚本输出
- Feeds更新状态
- 包安装信息
- Post-build验证结果

## 📝 最佳实践

1. **逐步测试**: 先添加少量配置，确认可用后再扩展
2. **备份配置**: 重要配置要做好备份和版本控制
3. **文档记录**: 记录每个配置的用途和依赖关系
4. **定期更新**: 定期更新feeds和包列表，保持最新
5. **设备适配**: 针对不同设备创建专用配置

通过这套配置系统，您可以实现OpenWrt固件的深度定制，满足各种特殊需求！ 