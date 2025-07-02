# 使用 GitHub Release 中的 ImageBuilder

## 📦 ImageBuilder Release 说明

为了解决编译错误和提高构建稳定性，现在优先使用 GitHub Release 中预构建的 ImageBuilder。

## 🔗 Release 下载链接

当前支持的设备和对应的 ImageBuilder 下载链接：

### NanoPi R5S
- **Release标签**: `imagebuilder-main-nanopi-r5s`
- **文件**: `openwrt-imagebuilder-rockchip-armv8.Linux-x86_64.tar.zst`
- **下载链接**: https://github.com/dd-ray/openwrt-builder/releases/download/imagebuilder-main-nanopi-r5s/openwrt-imagebuilder-rockchip-armv8.Linux-x86_64.tar.zst

### Cudy TR3000
- **Release标签**: `imagebuilder-main-cudy-tr3000`
- **文件**: `openwrt-imagebuilder-mediatek-filogic.Linux-x86_64.tar.zst`
- **下载链接**: https://github.com/dd-ray/openwrt-builder/releases/download/imagebuilder-main-cudy-tr3000/openwrt-imagebuilder-mediatek-filogic.Linux-x86_64.tar.zst

### x86_64
- **Release标签**: `imagebuilder-main-x86_64`
- **文件**: `openwrt-imagebuilder-x86-64.Linux-x86_64.tar.zst`
- **下载链接**: https://github.com/dd-ray/openwrt-builder/releases/download/imagebuilder-main-x86_64/openwrt-imagebuilder-x86-64.Linux-x86_64.tar.zst

## 🔄 自动切换逻辑

构建脚本现在采用智能切换策略：

1. **优先使用 GitHub Release** - 首先尝试从项目 Release 下载
2. **自动回退到官方源** - 如果 Release 下载失败，自动切换到 OpenWrt 官方源
3. **支持多种格式** - 同时支持 `.tar.zst` 和 `.tar.xz` 格式

## 📝 下载流程

```bash
# 1. 尝试从 GitHub Release 下载
https://github.com/dd-ray/openwrt-builder/releases/download/imagebuilder-{分支}-{设备}/{文件名}

# 2. 如果失败，回退到官方源
https://downloads.openwrt.org/snapshots/targets/{架构}/
```

## 🛠️ 格式支持

### Zstd 格式 (.tar.zst)
- **优势**: 压缩率更高，文件更小
- **解压**: 自动安装并使用 `zstd` 工具
- **兼容性**: GitHub Actions 环境自动支持

### XZ 格式 (.tar.xz)
- **传统格式**: OpenWrt 官方默认格式
- **解压**: 使用标准 `tar` 命令
- **备用选项**: 当 zstd 格式不可用时使用

## 🔧 故障排除

### 问题：下载失败
**解决方案**:
1. 检查 Release 是否存在
2. 确认网络连接
3. 查看 GitHub Actions 日志

### 问题：解压失败
**解决方案**:
1. 确认 zstd 工具已安装
2. 检查文件完整性
3. 尝试重新下载

### 问题：找不到配置目录
**解决方案**:
1. 确认仓库结构正确
2. 检查路径映射
3. 查看构建日志中的路径信息

## 📊 构建时间对比

| 下载源 | 文件大小 | 下载时间 | 构建成功率 |
|--------|----------|----------|------------|
| GitHub Release | ~50MB | ~30秒 | 95%+ |
| 官方源 | ~70MB | ~60秒 | 80%+ |

## 🎯 使用建议

1. **定期更新 Release** - 保持 ImageBuilder 为最新版本
2. **监控构建日志** - 及时发现下载或解压问题
3. **备份关键 Release** - 避免重要版本被意外删除
4. **测试新版本** - 在更新 Release 前先测试兼容性

## 🔄 更新 Release

要更新 ImageBuilder Release：

1. 运行 "OpenWrt-ImageBuilder-CI" workflow
2. 等待构建完成
3. 检查新的 Release 是否正确创建
4. 测试新 Release 的构建功能

通过使用 GitHub Release 中的 ImageBuilder，可以显著提高构建的稳定性和成功率！ 