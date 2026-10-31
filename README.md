# EasyTier KoolShare 插件

专为 ASUS RT-BT86U 路由器打造的 [EasyTier](https://easytier.cn/) 组网插件。

## 🚀 项目特点

- **专用优化**: 针对 RT-BT86U (ARM64) 架构优化
- **即装即用**: 标准 KoolShare 软件中心安装包
- **Web管理**: 完整的路由器 Web 界面支持
- **自动服务**: 开机自启动，配置持久化
- **稳定可靠**: 经过全面测试，生产环境可用

## 📦 快速安装

### 1. 下载安装包

请前往 [Latest Release](https://github.com/azzgo/eastier-merlin/releases/latest) 下载最新版安装包。

### 2. 软件中心安装
1. 登录路由器管理界面
2. 进入 **软件中心** → **离线安装**
3. 上传 `easytier.tar.gz` 文件
4. 等待安装完成

### 3. 配置使用
1. 软件中心找到 **EasyTier** 插件
2. 点击进入配置界面
3. 填写必要参数并启动服务

## ⚙️ 配置说明

### 必填参数
| 参数 | 描述 | 示例 |
|------|------|------|
| **IPv4地址** | 虚拟网络中的IP地址 | `10.0.0.1` |
| **网络名称** | 网络标识符 | `home-vpn` |
| **网络密钥** | 网络加密密码 | `my-secret-2024` |
| **节点地址** | 远程节点连接地址 | `tcp://1.2.3.4:11010` |

### 配置示例
```
IPv4地址: 10.0.0.1
网络名称: home-network
网络密钥: your-strong-password
节点地址: tcp://123.123.123.123:11010,udp://example.com:11011
```

## 🖥️ 使用方法

### Web 界面管理
- 访问: `路由器IP/Module_easytier.asp`
- 功能: 保存配置、启动/停止服务、查看状态
- 特性: 实时状态更新、配置验证、错误提示

### 命令行管理
```bash
# 服务控制
/koolshare/scripts/easytier_config.sh start    # 启动
/koolshare/scripts/easytier_config.sh stop     # 停止  
/koolshare/scripts/easytier_config.sh restart  # 重启
/koolshare/scripts/easytier_config.sh status   # 状态

# 配置管理
/koolshare/scripts/easytier_config.sh save_config  # 保存
/koolshare/scripts/easytier_config.sh get_config   # 获取
```

## 📁 技术架构

### 核心组件
```
/koolshare/
├── bin/easytier-core              # ARM64 主程序
├── scripts/
│   ├── easytier_config.sh        # 主控制脚本
│   └── easytier_status.cgi       # 状态检查API
├── webs/Module_easytier.asp      # Web管理界面
├── configs/easytier.conf         # 配置文件
└── init.d/S99easytier.sh         # 开机启动
```

### API 接口
- **配置API**: `/_api/` + `easytier_config.sh`
- **状态API**: `/cgi-bin/easytier_status.cgi`
- **Web界面**: `/Module_easytier.asp`

## 🔧 开发构建

### 构建环境
```bash
# 打包插件
./build_package.sh

# 运行回归测试（本地需要 docker；busybox ash 模拟路由器 shell）
bash tests/cases.sh
```

### 测试说明
- `tests/cases.sh` — 回归用例，调用契约来自 2026-10-31 真机取证（`tests/fixtures/contract/`）
- `tests/harness.sh` — 隔离沙箱 + mock（dbus / base.sh / easytier-core 假二进制）
- 覆盖：status 轮询不被误判为 web 提交、dbus export 环境污染、start/stop 失败必须真实上报、日志不被轮询清空
- GitHub Actions 在每次脚本改动时自动跑 shellcheck + 回归测试

### 文件结构
- `easytier/` - 插件源码目录
- `build_package.sh` - 构建脚本
- `config.json.js` - 插件元数据

## 🛠️ 故障排除

### 常见问题
| 问题 | 原因 | 解决方案 |
|------|------|----------|
| 安装失败 | 架构不匹配 | 确认为 ARM64 路由器 |
| 启动失败 | 配置错误 | 检查参数格式和网络连通性 |
| Web无法访问 | 插件未正确安装 | 重新安装并检查文件权限 |
| `easytier-cli peer` 中 ipv4 列为空 | 全网没有任何节点拥有虚拟 IP 时，`dhcp = true` 会永远等待（它只在 routes 中存在带 IP 的路由后才分配）。已在 v2.4.5/2.7.0 本地复现验证 | **在配置文件中显式写 `ipv4 = "x.x.x.x/24"`**（no_tun 模式下静态 IP 在 v2.4.5+ 均正常生效），并确保同网其他节点也配置了 IP 且不冲突 |

### 关于 no_tun 模式下的虚拟 IP（重要）
- `dhcp = true` 单独使用在「网络中尚无任何节点持有虚拟 IP」时会互相等待，导致所有节点 ipv4 均为空。
- 推荐做法：给每个节点写静态 `ipv4`（同一网段、互不冲突），例如主路由 `10.126.126.1`、其他节点依次递增。
- 本仓库 easytier-core 版本：**2.7.0**（`easytier/bin/easytier-core`，UPX 压缩的 aarch64 静态二进制，本地可用 `qemu-aarch64-static` 直接运行验证）。

### 日志查看

首先需要登录到路由器
```bash
# 插件日志
tail -f /tmp/upload/easytier_log.txt

# 系统日志
logread | grep easytier

# 服务状态
/koolshare/scripts/easytier_config.sh status
```

### 卸载插件
```bash
# 通过软件中心卸载，或手动清理
/koolshare/scripts/uninstall_easytier.sh
```

## 🎯 版本信息

- **支持平台**: ARM64 (aarch64)
- **兼容固件**: ASUS Merlin + KoolShare
- **目标设备**: RT-BT86U

## 📋 系统要求

- **路由器**: ASUS RT-BT86U 或兼容的 ARM64 设备
- **固件**: ASUS Merlin 官方固件
- **软件中心**: KoolShare 软件中心已安装
- **存储空间**: 至少 5MB 可用空间
- **网络**: 互联网连接用于与其他节点通信

## 🔒 安全说明

- 使用强密码作为网络密钥
- 定期更新网络密钥
- 确保防火墙正确配置
- 监控日志文件以发现异常

---

**注意**: 这是个人使用项目，仅针对特定设备优化。如需技术支持，请参考 `AGENT.md` 获取详细技术信息。
