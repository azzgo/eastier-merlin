# EasyTier RT-BT86U 个人插件开发计划

## 简化需求
- 仅支持ARM64架构（RT-BT86U）
- 固定使用 `--no-tun` 参数
- 个人使用，无需发布
- 最小化开发工作量

## 项目结构
```
easytier-merlin/
├── easytier/
│   ├── bin/easytier-core        # ARM64二进制
│   ├── webs/Module_easytier.asp  # 简单Web界面
│   └── scripts/
│       └── easytier.sh          # 启动脚本
├── build.py                     # 打包脚本
└── config.json.js              # 插件信息
```

## 核心配置项（4个）
- IPv4地址 (`--ipv4`)
- 网络名称 (`--network-name`) 
- 网络密钥 (`--network-secret`)
- 节点地址 (`--peers`)

## 开发阶段（2-3天完成）

### 第1天：基础框架
- [ ] 创建目录结构
- [ ] 编写config.json.js
- [ ] 准备ARM64版easytier-core
- [ ] 创建简单Web界面（4个输入框+启动按钮）

### 第2天：功能实现  
- [ ] 编写easytier.sh启动脚本
- [ ] 实现配置保存/读取
- [ ] 集成--no-tun固定参数
- [ ] 测试基本功能

### 第3天：测试优化
- [ ] 在RT-BT86U上测试
- [ ] 修复问题
- [ ] 创建安装包

## 技术简化
- 固定ARM64架构，无需多架构支持
- 硬编码--no-tun参数，无需配置
- 简单表单验证即可
- 基础状态显示

## 最小可用版本目标
- 能正常启动easytier-core
- 能保存和加载配置
- 能查看运行状态
- 在RT-BT86U上稳定运行