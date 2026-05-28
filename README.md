# NextConnect

> 极简极客 P2P 组网终端工具 — 在手机端高颜值、顺畅地通过 SSH 敲命令行。

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## 痛点定位

国内 AI 开发者、高校研究生需要**无脑登录、免翻墙、低延迟**地远程控制本地/公司/实验室的 Linux 终端（WSL2 / 服务器）。现有的方案要么需要公网 IP，要么走第三方中转延迟高，要么配置复杂劝退。

**NextConnect 只做一件事：手机端优雅地 SSH 连接到你的 Linux 机器。**

## 设计哲学

**极简主义。** 砍掉一切 WebUI 映射、文件传输等臃肿功能，只专注于终端体验。

**P2P 直连。** 基于 Headscale + Tailscale Core 组建虚拟网络，平台方服务器只跑控制信号，流量直连不中转。

## 系统架构

```
                       ┌────────────────────────────────────────┐
                       │     NextConnect 平台控制中心 (云端)     │
                       │   - 用户数据库 / 手机号微信扫码登录     │
                       │   - Headscale 控制面 (设备握手/授信)   │
                       └───────────────────┬────────────────────┘
                                           │
                            (仅在配对时交互)
                                           │
          ┌───────────────────────────────┴───────────────────────────────┐
          ▼                                                              ▼
┌─────────────────────────────────────┐                ┌─────────────────────────────────────┐
│        Linux 电脑端 (WSL2/服务器)    │◄──────────────►│            手机 App 端               │
│ - 后台常驻 nc-daemon 守护进程        │  (P2P 直连)    │ - 手机号/微信一键登录                │
│ - 封装 Tailscale 打洞核心            │  0中转流量费    │ - 扫码绑定 Linux 设备                │
│ - 一键安装脚本 install.sh            │  WireGuard 加密 │ - 内置终端 SSH 客户端                │
└─────────────────────────────────────┘                └─────────────────────────────────────┘
```

## 项目结构 (Monorepo)

```
nextconnect/
├── README.md
├── .gitignore
├── cloud-server/           # 阶段一：云端控制中心 (Go)
│   ├── cmd/server/         #   入口
│   ├── internal/           #   内部模块
│   │   ├── api/            #     RESTful API 路由与处理器
│   │   ├── db/             #     数据库初始化与迁移
│   │   ├── config/         #     配置加载
│   │   ├── acl/            #     端口 ACL (仅放行 22 端口)
│   │   └── audit/          #     审计日志
│   └── migrations/         #   SQL 迁移脚本
├── linux-client/           # 阶段二：Linux 守护进程 (Go)
│   ├── cmd/nc-daemon/      #   主程序
│   ├── internal/
│   │   ├── daemon/         #     核心逻辑 (注册/二维码/轮询/隧道)
│   │   └── install/        #     安装器
│   ├── install.sh          #   一键安装脚本
│   └── install-private-derp.sh  # 私有 DERP 中转部署脚本
└── mobile-app/             # 阶段三：手机 App (Flutter)
    ├── lib/
    │   ├── screens/        #   页面 (登录/设备列表/终端)
    │   ├── services/       #   API 与 VPN 服务
    │   └── widgets/        #   通用组件
    └── pubspec.yaml
```

## 核心流程

1. **用户登录** — 手机 App 通过手机号/微信登录，云端分配虚拟 Namespace
2. **Linux 端注册** — 运行 `install.sh`，`nc-daemon` 启动并向云端注册，终端打印配对二维码
3. **手机扫码绑定** — 手机扫描二维码，云端完成设备授信，P2P 网络打通
4. **SSH 连接** — App 通过虚拟内网 IP 直连 Linux 机器的 22 端口，流量走 P2P 隧道

## 快速开始

```bash
# 1. 克隆仓库
git clone https://github.com/scut-jol/NextConnect.git
cd NextConnect

# 2. 启动云端控制中心 (开发模式)
cd cloud-server
go run ./cmd/server/

# 3. 在 Linux 机器上运行客户端
cd ../linux-client
bash install.sh
```

> 详细部署指南请参考各子目录的说明文档。

## 安全策略

- **端口熔断**：虚拟网络内仅放行 22 端口（SSH），从底层杜绝用户搭建 Web 服务
- **实名追溯**：所有配对与连接操作记录审计日志，满足网安合规要求
- **端到端加密**：WireGuard 加密隧道，通讯内容平台方不可见

## 开发路线

| 阶段 | 模块 | 状态 |
|------|------|------|
| 一 | 云端控制中心 (Go + Headscale) | 骨架搭建 |
| 二 | Linux 客户端 (Go + Tailscale) | 骨架搭建 |
| 三 | 手机 App (Flutter) | 骨架搭建 |
| 四 | 安全加固与合规 | 骨架搭建 |

## License

MIT License. See [LICENSE](LICENSE) for details.