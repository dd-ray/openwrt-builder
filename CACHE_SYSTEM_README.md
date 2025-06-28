# 🚀 OpenWrt Release-Based Cache System

这是一个基于GitHub Release的OpenWrt构建缓存系统，通过将toolchain和ccache发布到独立的release来实现持久化缓存，突破GitHub Actions缓存的限制。

## 📋 系统概览

### 🔧 组件构成

1. **主构建流程** (`openwrt-ci.yml`) - 主要的固件构建工作流
2. **Toolchain构建器** (`toolchain-builder.yml`) - 独立构建和发布toolchain
3. **CCache构建器** (`ccache-builder.yml`) - 独立构建和发布ccache
4. **缓存管理器** (`script/cache-manager.sh`) - 智能缓存管理脚本

### 🎯 优势特点

- ✅ **持久存储** - 不受GitHub Actions缓存7天限制
- ✅ **跨仓库共享** - 可以在多个项目间共享缓存
- ✅ **智能检测** - 自动检测是否需要更新缓存
- ✅ **增量更新** - 支持ccache增量更新
- ✅ **版本管理** - 基于分支和架构的版本管理
- ✅ **自动维护** - 自动维护过期缓存
- ✅ **无缓存冲突** - 清晰的缓存职责分工，避免版本混乱 ⭐ **最新优化**

## 🛠️ 使用指南

### 🏗️ 初次设置

1. **构建Toolchain**
   ```bash
   # 手动触发toolchain构建
   gh workflow run "toolchain-builder.yml" \
     -f REPO_BRANCH="main" \
     -f FORCE_REBUILD="false"
   ```

2. **构建初始CCache**
   ```bash
   # 为每个设备构建初始ccache
   gh workflow run "ccache-builder.yml" \
     -f REPO_BRANCH="main" \
     -f TARGET_DEVICE="nanopi-r5s" \
     -f INCREMENTAL="false"
   ```

### 🚀 日常构建

运行主构建流程时，系统会自动：
1. 检查并下载对应的toolchain
2. 检查并下载对应的ccache
3. 进行固件构建
4. 自动更新ccache到release

```bash
gh workflow run "openwrt-ci.yml" \
  -f REPO_BRANCH="main" \
  -f CCACHE="true"
```

### 🔧 缓存管理

使用缓存管理脚本进行高级管理：

```bash
# 检查toolchain是否需要更新
./script/cache-manager.sh check-toolchain arm64 /path/to/source

# 检查ccache年龄
./script/cache-manager.sh check-ccache-age arm64 7

# 自动维护模式
./script/cache-manager.sh auto-maintain arm64 nanopi-r5s /path/to/source
```

## 📊 Release标签规范

### Toolchain Release
- **标签格式**: `toolchain-{分支}-{toolchain类型}`
- **示例**: 
  - `toolchain-main-aarch64_cortex-a53` (nanopi-r5s)
  - `toolchain-main-aarch64_generic` (cudy-tr3000)
  - `toolchain-main-x86_64` (x86_64)
- **包含内容**:
  - `build_dir/toolchain-*` - 工具链构建目录
  - `build_dir/host` - 主机工具目录
  - `build_dir/target-*` - 目标架构构建目录 ⭐ **新增**
  - `staging_dir/toolchain-*` - 工具链暂存目录
  - `staging_dir/host*` - 主机暂存目录
  - `staging_dir/target-*` - 目标架构暂存目录 ⭐ **新增**

### CCache Release
- **标签格式**: `ccache-{分支}-{架构}`
- **示例**: `ccache-main-arm64`, `ccache-openwrt-24.10-amd64`
- **包含内容**:
  - `.ccache/` 目录的完整内容

### 🎯 Toolchain类型映射

| 设备 | Toolchain类型 | 架构平台 | 说明 |
|------|---------------|----------|------|
| nanopi-r5s | `aarch64_cortex-a53` | arm64 | Cortex-A53优化 |
| cudy-tr3000 | `aarch64_generic` | arm64 | 通用aarch64 |
| x86_64 | `x86_64` | amd64 | x86_64架构 |

## 🎮 工作流参数

### Toolchain Builder 参数

| 参数 | 描述 | 默认值 | 选项 |
|------|------|--------|------|
| `REPO_URL` | OpenWrt仓库 | `openwrt/openwrt` | - |
| `REPO_BRANCH` | OpenWrt分支 | `main` | `main`, `openwrt-24.10` |
| `FORCE_REBUILD` | 强制重建 | `false` | `true`, `false` |

### CCache Builder 参数

| 参数 | 描述 | 默认值 | 选项 |
|------|------|--------|------|
| `REPO_URL` | OpenWrt仓库 | `openwrt/openwrt` | - |
| `REPO_BRANCH` | OpenWrt分支 | `main` | `main`, `openwrt-24.10` |
| `TARGET_DEVICE` | 目标设备 | `nanopi-r5s` | `nanopi-r5s`, `cudy-tr3000`, `x86_64` |
| `INCREMENTAL` | 增量更新 | `true` | `true`, `false` |

## 🔄 缓存更新策略

### 自动更新触发条件

**Toolchain更新**:
- OpenWrt源码commit发生变化
- feeds配置文件变化
- 手动强制重建

**CCache更新**:
- 每次主构建后自动更新
- ccache数据大小超过阈值
- 手动触发增量/完整更新

### 智能检测机制

系统会智能检测以下变化：
- 📝 OpenWrt源码版本变化
- 🔧 构建配置变化
- ⏰ 缓存年龄超限
- 📊 缓存使用统计

## 🛡️ 最佳实践

### 🎯 推荐用法

1. **首次使用**: 先构建toolchain，再构建ccache，最后进行正常构建
2. **定期维护**: 使用auto-maintain模式定期检查和更新缓存
3. **多分支管理**: 为不同分支维护独立的缓存
4. **增量更新**: 优先使用增量更新来节省时间和资源

### ⚠️ 注意事项

1. **存储限制**: GitHub Release有存储限制，大型缓存可能需要清理
2. **网络带宽**: 下载大型缓存文件需要稳定网络
3. **Toolchain兼容性**: ⚠️ **重要** - 不同设备使用不同的toolchain类型，不可混用：
   - `nanopi-r5s` 使用 `aarch64_cortex-a53`
   - `cudy-tr3000` 使用 `aarch64_generic`
   - `x86_64` 使用 `x86_64`
4. **权限要求**: 需要有仓库的release写入权限
5. **首次构建**: 第一次使用时需要先构建对应的toolchain release

## 🔧 缓存系统架构改进

### ✨ 最新优化 (v2.0)

我们对缓存系统进行了重大改进，解决了之前存在的缓存冲突问题：

#### 🔄 缓存职责重新分工

| 缓存类型 | 负责内容 | 更新策略 | 持久性 |
|----------|----------|----------|--------|
| **Toolchain Release** | 完整构建环境 | 按需构建 | 永久 |
| **CCache Release** | 编译结果缓存 | 每次构建后 | 永久 |
| **GitHub Actions Cache** | 包构建临时文件 | 每次构建后 | 7天 |

#### 📦 Toolchain 完整性增强

修复前的 toolchain 包只包含基础工具链，现在包含：
```
✅ build_dir/toolchain-*    # 工具链核心
✅ build_dir/host           # 主机工具 (如 e2fsprogs)
✅ build_dir/target-*       # 目标构建环境 🆕
✅ staging_dir/toolchain-*  # 工具链暂存
✅ staging_dir/host*        # 主机暂存
✅ staging_dir/target-*     # 目标暂存 🆕
```

#### 🚫 消除缓存冲突

**问题**: 之前 GitHub Actions Cache 和 Toolchain Release 都试图缓存相同的目录，导致版本冲突

**解决**: 
- Toolchain Release 负责提供完整构建环境
- GitHub Actions Cache 只缓存包构建的临时文件：
  - `build_dir/target-*/linux-*/tmp` - 包构建临时文件
  - `dl` - 下载的源码包
  - `feeds` - feeds 源码

#### 🎯 修复效果

- ✅ **解决编译错误**: 如 `unknown type name 'blkid_probe'`
- ✅ **避免版本混乱**: 每种缓存有明确的用途
- ✅ **提高可靠性**: 一致的构建环境
- ✅ **减少存储**: 消除重复缓存

## 🐛 故障排除

### 常见问题

**问题**: Toolchain下载失败
**解决**: 检查release是否存在，或手动触发toolchain构建

**问题**: CCache解压失败
**解决**: 删除对应的ccache release，重新构建

**问题**: 构建时间没有明显减少
**解决**: 检查ccache命中率和toolchain是否正确加载

### 调试命令

```bash
# 检查release状态
gh release list --limit 20

# 查看具体release信息
gh release view toolchain-main-arm64

# 手动下载测试
wget https://github.com/user/repo/releases/download/tag/file.tar.gz
```

## 📈 性能对比

| 构建阶段 | 无缓存 | 传统缓存 | Release缓存 |
|----------|--------|----------|-------------|
| Toolchain构建 | 30-40分钟 | 5-10分钟 | 2-3分钟 |
| 包编译 | 60-90分钟 | 20-30分钟 | 15-20分钟 |
| 总构建时间 | 120-150分钟 | 40-60分钟 | 25-35分钟 |
| 缓存持久性 | - | 7天 | 永久 |

---

💡 **提示**: 这个缓存系统特别适合频繁构建、多设备支持的OpenWrt项目，可以显著减少构建时间和资源消耗。 