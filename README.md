# OpenWrt Builder

🚀 一个用于构建 OpenWrt 固件的自动化构建工具，支持多种设备并集成了常用插件和优化配置。

## 📋 项目简介

OpenWrt Builder 是一个简化 OpenWrt 固件构建过程的工具集，提供了完整的本地构建脚本、CI/CD 工具和设备配置模板。项目预配置了多种实用插件，优化了网络设置，并支持多种主流硬件平台。

## 🎯 支持的设备

| 设备名称 | 配置文件 | 架构 | Toolchain 类型 |
|---------|----------|------|----------------|
| NanoPi R5S | `nanopi-r5s.seed` | ARM64 | aarch64_generic |
| Cudy TR3000 | `cudy-tr3000.seed` | ARM64 | aarch64_cortex-a53 |
| x86_64 | `x86_64.seed` | AMD64 | x86_64 |

## ✨ 功能特性

### 🔧 核心功能
- **一键构建**：使用本地构建脚本快速编译固件
- **多设备支持**：支持多种主流硬件平台
- **模块化配置**：通过 seed 文件管理设备配置
- **自动化工具**：提供 CI/CD 构建工具

### 🌐 网络优化
- **默认网关**：192.168.2.1（避免与大多数路由器冲突）
- **时区设置**：Asia/Shanghai (CST-8)
- **DNS 增强**：集成 MosDNS 和 dnsmasq-full
- **流量控制**：支持 QoS、流量监控和带宽限制

### 🎨 界面和主题
- **Argon 主题**：现代化的 Web 界面
- **中文界面**：完整的中文语言包
- **响应式设计**：支持移动设备访问

### 📦 内置插件
- **网络工具**：UPnP、Wake-on-LAN、网络发现
- **系统管理**：ttyd 终端、软件包管理器、定时任务
- **代理工具**：OpenClash、透明代理支持
- **监控工具**：网络带宽监控、系统监控
- **文件传输**：SFTP 服务器、网络共享

### 🔒 安全特性
- **防火墙**：nftables 防火墙配置
- **VPN 支持**：WireGuard 内核模块
- **访问控制**：时间控制、MAC 地址过滤

## 🚀 快速开始

### 系统要求
- **操作系统**：Ubuntu 18.04+ / Debian 10+
- **内存**：建议 8GB 以上
- **磁盘空间**：至少 20GB 可用空间
- **网络**：稳定的互联网连接

### 本地构建

1. **克隆项目**
   ```bash
   git clone https://github.com/your-username/openwrt-builder.git
   cd openwrt-builder
   ```

2. **赋予执行权限**
   ```bash
   chmod +x script/*.sh
   ```

3. **开始构建**
   ```bash
   # 构建 NanoPi R5S 固件（默认）
   ./script/local-build.sh
   
   # 构建指定设备固件
   ./script/local-build.sh nanopi-r5s.seed
   ./script/local-build.sh x86_64.seed
   ./script/local-build.sh cudy-tr3000.seed
   ```

### 使用工具脚本

工具脚本提供了更细粒度的控制，适合 CI/CD 环境：

```bash
# 安装依赖
./script/tool.sh install_dep

# 克隆源码
./script/tool.sh clone

# 更新 feeds
./script/tool.sh update_feeds

# 构建配置
./script/tool.sh build_config

# 下载依赖包
./script/tool.sh make_download

# 编译固件
./script/tool.sh compile_firmware
```

## 📁 项目结构

```
openwrt-builder/
├── config/                    # 设备配置文件
│   ├── common.seed           # 通用配置
│   ├── nanopi-r5s.seed       # NanoPi R5S 配置
│   ├── x86_64.seed           # x86_64 配置
│   └── cudy-tr3000.seed      # Cudy TR3000 配置
├── files/                    # 自定义文件
│   └── etc/                  # 系统配置文件
├── script/                   # 构建脚本
│   ├── local-build.sh        # 本地构建脚本
│   ├── tool.sh               # CI/CD 工具脚本
│   ├── diy.sh                # 自定义配置脚本
│   └── device-toolchain-mapping.sh  # 设备映射
└── README.md                 # 项目说明
```

## 🔧 自定义配置

### 修改网络设置

编辑 `script/diy.sh` 文件，修改以下行：
```bash
# 修改默认网关
sed -i 's/192.168.2.1/你的IP地址/g' package/base-files/files/bin/config_generate
```

### 添加自定义软件包

在 `config/common.seed` 文件中添加：
```bash
CONFIG_PACKAGE_your-package=y
```

### 添加自定义文件

将文件放置在 `files/` 目录中，构建时会自动复制到固件中。

### 修改插件配置

在 `script/diy.sh` 文件中可以：
- 添加第三方插件源
- 修改插件菜单位置
- 自定义主题配置

## 🎛️ 环境变量

构建脚本支持以下环境变量：

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `REPO_URL` | `https://github.com/openwrt/openwrt` | OpenWrt 源码仓库 |
| `REPO_BRANCH` | `main` | 源码分支 |
| `SOURCE_PATH` | `./openwrt-source` | 源码目录 |
| `BUILDER_PATH` | `$(pwd)` | 构建工具目录 |

示例：
```bash
export REPO_BRANCH="openwrt-24.10"
export SOURCE_PATH="/tmp/openwrt-source"
./script/local-build.sh nanopi-r5s.seed
```

## 🔍 常见问题

### Q: 构建失败，提示磁盘空间不足
**A**: 确保至少有 20GB 可用空间，可以使用 `df -h` 检查磁盘使用情况。

### Q: 下载依赖包失败
**A**: 检查网络连接，可能需要使用代理。设置环境变量：
```bash
export HTTP_PROXY=http://proxy.example.com:8080
export HTTPS_PROXY=http://proxy.example.com:8080
```

### Q: 如何添加新的设备支持
**A**: 
1. 在 `config/` 目录创建新的 `.seed` 文件
2. 在 `script/device-toolchain-mapping.sh` 中添加设备映射
3. 测试构建流程

### Q: 编译时间过长
**A**: 
- 使用 SSD 硬盘
- 增加内存（建议 16GB+）
- 使用 `ccache` 缓存（已默认启用）

### Q: 如何更新已有固件
**A**: 
- 使用 Web 界面的系统升级功能
- 确保勾选"保留配置"选项
- 建议先备份当前配置

## 🤝 贡献指南

欢迎贡献代码！请遵循以下步骤：

1. **Fork 项目**
2. **创建特性分支** (`git checkout -b feature/amazing-feature`)
3. **提交更改** (`git commit -m 'Add amazing feature'`)
4. **推送分支** (`git push origin feature/amazing-feature`)
5. **创建 Pull Request**

### 贡献类型
- 🐛 修复 bug
- ✨ 新功能
- 📝 文档改进
- 🔧 配置优化
- 🎨 界面美化

## 📄 许可证

本项目采用 MIT 许可证。详情请参阅 [LICENSE](LICENSE) 文件。

## 🙏 致谢

感谢以下项目和开发者：
- [OpenWrt](https://openwrt.org/) - 开源路由器固件
- [P3TERX](https://github.com/P3TERX) - 构建脚本参考
- [jerrykuku](https://github.com/jerrykuku) - Argon 主题
- [sbwml](https://github.com/sbwml) - MosDNS 和相关插件

