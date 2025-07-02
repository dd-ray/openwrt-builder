# OpenWrt Builder

一个用于构建自定义OpenWrt固件和ImageBuilder的自动化工具集合。

## 功能特性

### 🚀 三种构建模式

1. **完整固件构建** (`openwrt-ci.yml`) - 从源码编译完整的OpenWrt固件
2. **ImageBuilder构建** (`openwrt-imagebuilder-ci.yml`) - 构建预编译的ImageBuilder工具包
3. **快速固件构建** (`openwrt-imagebuilder-build.yml`) - 使用ImageBuilder快速生成自定义固件 ⭐

### 📱 支持设备

- **NanoPi R5S** - ARM64架构，Rockchip RK3568处理器
- **Cudy TR3000** - ARM64架构，MediaTek MT7986A处理器，WiFi 6支持
- **x86_64** - x86_64架构，适用于PC和虚拟机

### 🌿 支持分支

- `main` - OpenWrt主线开发版本
- `openwrt-24.10` - OpenWrt 24.10稳定版本

## 构建流程详解

### 1. 完整固件构建 (推荐用于定制内核)

**适用场景**: 需要修改内核配置、添加内核模块、完全自定义系统

**特点**:
- ✅ 完全可定制
- ✅ 支持内核修改
- ❌ 构建时间长(2-4小时)
- ❌ 资源消耗大

**使用方法**:
1. 进入 Actions 选项卡
2. 选择 "OpenWrt-CI" workflow
3. 点击 "Run workflow"
4. 选择仓库、分支参数
5. 等待构建完成

### 2. ImageBuilder构建 (推荐用于制作工具包)

**适用场景**: 为快速固件构建准备预编译工具包

**特点**:
- ✅ 一次构建，多次使用
- ✅ 包含完整工具链
- ✅ 自动发布到GitHub Release
- ✅ 支持zstd压缩，体积更小
- ⚠️ 需要定期更新
- ❌ 构建时间较长(1-2小时)

**使用方法**:
1. 进入 Actions 选项卡
2. 选择 "OpenWrt-ImageBuilder-CI" workflow
3. 点击 "Run workflow"
4. 选择仓库、分支参数
5. 等待构建完成，ImageBuilder将发布到Release

**Release说明**: 详见 [`config/imagebuilder/RELEASE_USAGE.md`](config/imagebuilder/RELEASE_USAGE.md)

### 3. 🌟 快速固件构建 (推荐日常使用)

**适用场景**: 快速生成包含特定软件包的固件，无需编译

**特点**:
- ✅ 构建速度极快(5-15分钟)
- ✅ 可自定义软件包
- ✅ 基于预编译组件
- ✅ 使用GitHub Release中的ImageBuilder
- ✅ 支持zstd压缩格式，文件更小
- ❌ 无法修改内核

**使用方法**:

#### 🚀 基础使用
1. 进入 Actions 选项卡
2. 选择 "OpenWrt-ImageBuilder-Build" workflow
3. 点击 "Run workflow"
4. 配置参数:
   - **设备类型**: 选择目标设备
   - **OpenWrt分支**: 选择版本分支
   - **自定义包列表**: 添加要安装的软件包(可选)
   - **移除包列表**: 移除不需要的软件包(可选)

#### 📦 软件包配置示例

**添加常用工具**:
```
wget curl nano htop tcpdump iperf3
```

**添加Docker支持**:
```
docker dockerd docker-compose luci-app-dockerman
```

**添加科学上网工具**:
```
shadowsocks-libev-ss-local shadowsocks-libev-ss-redir luci-app-shadowsocks-libev
```

**移除默认包**:
```
-dnsmasq -odhcpd -uhttpd
```

#### 🔧 高级配置

**预设包列表**:
- `config/imagebuilder/packages-common.list` - 所有设备通用包
- `config/imagebuilder/packages-nanopi-r5s.list` - NanoPi R5S专用包
- `config/imagebuilder/packages-x86_64.list` - x86_64专用包
- `config/imagebuilder/packages-cudy-tr3000.list` - Cudy TR3000专用包

**自定义包列表**:
1. 编辑对应的 `.list` 文件
2. 每行一个包名
3. 以 `#` 开头的行为注释
4. 空行会被忽略

#### 🔧 高级配置选项

ImageBuilder支持更多高级配置，详见 [`config/imagebuilder/README.md`](config/imagebuilder/README.md)

**自定义Feeds**: 从GitHub等源克隆第三方软件包
```bash
# config/imagebuilder/feeds.conf
src-git passwall https://github.com/xiaorouji/openwrt-passwall.git
src-git helloworld https://github.com/fw876/helloworld.git
```

**配置覆盖**: 修改系统默认设置
```bash
# config/imagebuilder/files/etc/uci-defaults/99-custom
uci set system.@system[0].hostname='MyRouter'
uci set network.lan.ipaddr='10.0.0.1'
uci commit
```

**文件替换**: 覆盖系统文件
```
config/imagebuilder/files/
└── etc/
    ├── banner          # 自定义登录横幅
    └── config/         # 配置文件覆盖
```

## 配置文件说明

### 设备配置文件 (`config/*.seed`)
- `nanopi-r5s.seed` - NanoPi R5S设备配置
- `cudy-tr3000.seed` - Cudy TR3000设备配置  
- `x86_64.seed` - x86_64平台配置
- `common.seed` - 通用配置，包含基础软件包和系统设置

### 包列表文件 (`config/imagebuilder/packages-*.list`)
定义ImageBuilder构建时要安装的软件包列表，支持设备专用配置。

## 脚本工具

### `script/tool.sh` - 核心构建脚本

**完整固件构建命令**:
```bash
./script/tool.sh clone                # 克隆源码
./script/tool.sh update_feeds         # 更新软件源
./script/tool.sh build_config         # 生成配置
./script/tool.sh make_download        # 下载依赖
./script/tool.sh compile_firmware     # 编译固件
```

**ImageBuilder构建命令**:
```bash
./script/tool.sh build_imagebuilder_config  # 生成ImageBuilder配置
./script/tool.sh compile_imagebuilder       # 编译ImageBuilder
```

**快速固件构建命令**:
```bash
./script/tool.sh download_imagebuilder   # 下载ImageBuilder
./script/tool.sh extract_imagebuilder    # 解压ImageBuilder
./script/tool.sh prepare_packages        # 准备包列表
./script/tool.sh build_with_imagebuilder # 构建固件
```

## 最佳实践建议

### 🎯 选择合适的构建方式

1. **首次使用** → 选择"快速固件构建"，使用默认配置
2. **需要特定软件** → 使用"快速固件构建"，在自定义包列表中添加
3. **需要内核修改** → 使用"完整固件构建"
4. **频繁构建** → 先构建ImageBuilder，再使用快速构建

### ⚡ 加速技巧

1. **启用ccache缓存** - 可以显著减少重复编译时间
2. **定期更新ImageBuilder** - 保持工具包为最新版本
3. **并行构建** - 利用GitHub Actions的矩阵构建功能

### 🔧 故障排除

1. **构建失败** - 检查软件包名称是否正确，查看构建日志
2. **ImageBuilder下载失败** - 可能是版本不匹配，尝试重新构建ImageBuilder
3. **固件无法启动** - 检查设备配置文件，确认硬件支持

## 贡献指南

欢迎提交Issue和Pull Request来改进这个项目！

### 添加新设备支持

1. 在 `config/` 目录添加设备配置文件 (`设备名.seed`)
2. 在 `config/imagebuilder/` 目录创建设备专用包列表 (`packages-设备名.list`)
3. 在workflow文件中添加设备选项
4. 更新 `script/tool.sh` 中的设备映射关系

## 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 致谢

- [OpenWrt项目](https://openwrt.org/) - 开源路由器固件
- [GitHub Actions](https://github.com/features/actions) - CI/CD平台
- [dd-ray/github-actions](https://github.com/dd-ray/github-actions) - OpenWrt构建工具