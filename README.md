# NextConnect

> 极简极客 P2P 组网终端工具 — 在手机端高颜值、顺畅地通过 SSH 敲命令行。

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

---

## 📌 项目定位

### 痛点

国内 AI 开发者、高校研究生需要**无脑登录、免翻墙、低延迟**地远程控制本地/公司/实验室的 Linux 终端（WSL2 / 服务器）。现有方案要么需要公网 IP，要么第三方中转延迟高，要么配置复杂劝退。

### 设计哲学

**只做一件事**：手机端优雅地 SSH 连接到你的 Linux 机器。

砍掉一切 WebUI 映射、文件传输等臃肿功能，专注于终端体验。基于 **Headscale (控制面)** + **Tailscale Core (数据面)** 组建 P2P 虚拟网络，平台方服务器只跑控制信号，**绝不中转用户流量**。

---

## 🏗️ 系统架构

```
                       ┌──────────────────────────────────────────┐
                       │         NextConnect 云端控制中心          │
                       │   - 用户数据库 / 手机号微信扫码登录       │
                       │   - Headscale 控制面 (设备握手/授信)     │
                       │   - 审计日志 / 端口 ACL 熔断             │
                       └───────────────────┬──────────────────────┘
                                           │
                            (仅在配对时交互控制信号)
                                           │
          ┌───────────────────────────────┴───────────────────────────────┐
          ▼                                                              ▼
┌─────────────────────────────────────┐              ┌─────────────────────────────────────┐
│        Linux 电脑端 (WSL2/服务器)    │◄────────────►│            手机 App 端               │
│ - 后台常驻 nc-daemon 守护进程        │  (P2P 直连)  │ - 手机号一键登录                     │
│ - 封装 Tailscale 打洞核心            │  零中转流量  │ - 扫码绑定 Linux 设备                │
│ - 一键安装脚本 install.sh            │  加密隧道    │ - 内置 SSH 终端 (dartssh2)          │
└─────────────────────────────────────┘              └─────────────────────────────────────┘
```

### 核心流程

```
手机登录 ──→ 获取 JWT + Namespace ──→ 设备大厅 (空)
                                        │
Linux 运行 install.sh ──→ nc-daemon 启动 ──→ 向云端注册 ──→ 打印二维码
                                        │
手机扫描二维码 ──→ 云端配对确认 ──→ P2P 网络打通
                                        │
点击设备 ──→ SSH 直连 (100.64.0.x:22) ──→ 终端面板
```

---

## 📁 项目结构

```
nextconnect/
├── README.md
├── .gitignore
├── cloud-server/                    # 云端控制中心 (Go)
│   ├── cmd/server/main.go          #   入口
│   ├── internal/
│   │   ├── api/                    #     API 路由与处理器
│   │   │   ├── router.go           #      路由注册
│   │   │   ├── handlers.go         #      请求处理器
│   │   │   ├── middleware.go       #      JWT / 限流 / 安全中间件
│   │   │   ├── types.go            #      请求/响应类型
│   │   │   └── acl_handler.go      #      ACL 策略端点
│   │   ├── db/                     #     数据库层 (SQLite)
│   │   ├── config/                 #     配置加载
│   │   ├── acl/                    #     端口 ACL 熔断
│   │   └── audit/                  #     审计日志模块
│   ├── migrations/                 #   SQL 迁移脚本
│   └── go.mod
├── linux-client/                    # Linux 守护进程 (Go)
│   ├── cmd/nc-daemon/main.go       #   主程序
│   ├── internal/
│   │   ├── daemon/                 #     核心逻辑
│   │   └── install/                #     安装器
│   ├── install.sh                  #   一键安装脚本
│   ├── install-private-derp.sh     #   私有 DERP 中转部署
│   └── go.mod
└── mobile-app/                      # 手机 App (Flutter)
    ├── lib/
    │   ├── main.dart               #   入口与路由
    │   ├── screens/
    │   │   ├── login_screen.dart   #     登录页
    │   │   ├── device_list_screen.dart #  设备大厅
    │   │   ├── scanner_screen.dart #     扫码绑定页
    │   │   └── terminal_screen.dart #     SSH 终端面板
    │   ├── services/
    │   │   ├── api_service.dart    #     HTTP 客户端
    │   │   ├── auth_service.dart   #     JWT 持久化
    │   │   ├── terminal_service.dart #   dartssh2 封装
    │   │   ├── device_service.dart #     设备列表
    │   │   └── vpn_service.dart    #     VPN 隧道存根
    │   └── models/
    │       ├── user.dart
    │       ├── device.dart
    │       └── api_types.dart
    └── pubspec.yaml
```

---

## 🚀 快速开始

### 环境要求

| 组件 | 工具链 |
|------|--------|
| cloud-server | Go 1.22+, SQLite (内置) |
| linux-client | Go 1.22+ (编译)，或直接下载二进制 |
| mobile-app | Flutter 3.0+, Dart 3.0+ |

### 1. 启动云端控制中心

```bash
cd cloud-server

# 安装依赖
go mod tidy

# 运行开发服务器 (默认 :8080)
go run ./cmd/server/

# 可选：环境变量配置
export NC_LISTEN_ADDR=":8080"
export NC_DB_PATH="./data/nextconnect.db"
export NC_JWT_SECRET="your-secret-key"
```

服务器启动后自动完成 SQLite 数据库迁移，创建 `nc_users`、`nc_pairing_tokens`、`nc_audit_logs` 三张表。

验证：

```bash
curl http://localhost:8080/api/v1/health
# {"status":"ok","service":"nextconnect-cloud"}

curl http://localhost:8080/api/v1/acl/policy
# {"acls":[...]}  — SSH 22 only policy
```

### 2. 编译 Linux 客户端

```bash
cd linux-client
go mod tidy
go build -o nc-daemon ./cmd/nc-daemon/
```

### 3. 运行 Linux 守护进程

```bash
./nc-daemon

# 输出示例：
# ╔══════════════════════════════════════════╗
# ║        NextConnect Linux Daemon         ║
# ╚══════════════════════════════════════════╝
# ✓ Machine keys ready
# ✓ Pairing token: NC-A3X9K2
#
# ┌─ Scan this QR code with NextConnect App ─┐
# [QR CODE ASCII ART]
# └──────────────────────────────────────────┘
# Waiting for mobile approval...
```

> 也可以使用 `install.sh` 一键安装并注册为系统服务。

### 4. 手机 App

```bash
cd mobile-app

# 安装依赖
flutter pub get

# 运行
flutter run
```

---

## 📋 API 参考

所有端点位于 `/api/v1/` 前缀下。

### 健康检查

```
GET /health
→ 200 {"status":"ok","service":"nextconnect-cloud"}
```

### ACL 策略

```
GET /acl/policy
→ 200 { SSH 22 only ACL policy }
```

### 用户登录

```
POST /auth/login
Content-Type: application/json

{"phone_number": "13800138000"}

→ 200 {
  "token": "eyJ...",
  "namespace": "nc_a1b2c3d4",
  "user_id": 1
}
```

首次登录自动注册，分配唯一 Namespace。返回 JWT Token (24h 有效)。

### 设备注册

```
POST /pair/register
Content-Type: application/json

{"machine_key": "mkey:...", "node_key": "nodekey:..."}

→ 200 {
  "pairing_token": "NC-A3X9K2",
  "poll_url": "/api/v1/pair/poll?token=NC-A3X9K2"
}
```

Linux 端调用，生成 6 位配对码 Token（10 分钟有效期）。

### 配对确认

```
POST /pair/confirm
Authorization: Bearer <jwt>
Content-Type: application/json

{"pairing_token": "NC-A3X9K2"}

→ 200 {"status": "approved", "namespace": "nc_a1b2c3d4"}
```

手机端扫码后调用（需 JWT 认证）。云端完成设备授信。

### 轮询状态

```
GET /pair/poll?token=NC-A3X9K2

→ 200 {"status": "approved", "namespace": "nc_a1b2c3d4"}
```

Linux 端每 2 秒轮询，直到状态变为 `approved` 或 `expired`。

### 设备列表

```
GET /devices
Authorization: Bearer <jwt>

→ 200 {"devices": [...]}
```

JWT 保护，返回当前用户 Namespace 下的所有 Linux 设备。

---

## 🛡️ 安全策略

### 端口熔断 (ACL)

虚拟网络内**仅放行 22 端口（SSH）**，显式禁止：

| 端口 | 协议 | 策略 |
|------|------|------|
| 22 | SSH | ✅ 允许 |
| 80 | HTTP | ❌ 禁止 |
| 443 | HTTPS | ❌ 禁止 |
| 8080 | HTTP 代理 | ❌ 禁止 |
| 8443 | HTTPS 备用 | ❌ 禁止 |
| 3389 | RDP | ❌ 禁止 |
| 5900/5901 | VNC | ❌ 禁止 |
| ICMP | Ping | ✅ 允许 |

> 这从底层技术上证明了平台「纯粹是生产力终端，不具备搭网站能力」，满足国内网安合规要求。

### 审计日志

所有操作记录结构化日志（不含敲键内容）：

| 操作 | 记录字段 |
|------|----------|
| 登录 | user_id, phone, namespace, timestamp |
| 设备注册 | machine_key, namespace, timestamp |
| 配对确认 | user_id, phone, machine_key, namespace |
| 轮询 | machine_key, status, namespace |

面对网安调查时可秒级提供完整追溯链。

### 传输加密

- 控制面：HTTPS + JWT
- 数据面：WireGuard 端到端加密隧道
- 平台方无法解密用户通讯内容

### 限流保护

| 端点 | 频率限制 |
|------|----------|
| `/auth/login` | 5 次/分钟/IP |
| `/pair/register` | 5 次/分钟/IP |
| `/pair/poll` | 30 次/分钟/IP |

---

## 🔧 部署指南

### 生产部署 (cloud-server)

```bash
# 编译
cd cloud-server
CGO_ENABLED=1 go build -o nc-server ./cmd/server/

# 运行 (推荐使用 systemd 或 supervisord)
export NC_LISTEN_ADDR=":443"
export NC_DB_PATH="/data/nextconnect.db"
export NC_JWT_SECRET="<strong-random-secret>"
./nc-server
```

建议配合 Nginx 反向代理 + Let's Encrypt 证书使用：

```nginx
server {
    listen 443 ssl;
    server_name api.nextconnect.com;

    ssl_certificate /etc/letsencrypt/live/api.nextconnect.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.nextconnect.com/privkey.pem;

    location /api/v1/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 私有 DERP 中转

当 P2P 打洞失败时，可部署私有 DERP 中转节点：

```bash
# 在你的公网服务器上运行
curl -fsSL https://api.nextconnect.com/scripts/install-derp.sh \
  | sh -s -- --secret=sk_abc123 --domain=derp.example.com
```

脚本会自动完成：安装 derper、配置 SSL 证书、开放端口、注册 systemd 服务。

---

## 🔄 完整使用流程

### 首次使用

1. 部署云端控制中心（见部署指南）
2. 在 Linux 机器上运行 `install.sh` 或 `nc-daemon`
3. 打开手机 App，输入手机号登录
4. 点击右上角扫码图标
5. 扫描终端打印的二维码
6. 在设备大厅点击在线设备 → 进入终端

### 日常使用

1. 手机 App 打开 → 自动登录 → 设备大厅
2. 在线设备亮绿灯，点击即可 SSH
3. 使用底部工具栏输入命令，Ctrl/Alt 修饰键通过弹出菜单发送

### Linux 端管理

```bash
# 查看状态
systemctl status nextconnect-daemon

# 查看日志
journalctl -u nextconnect-daemon -f

# 无 systemd 环境
tail -f ~/.config/nextconnect/nc-daemon.log

# 手动重新配对
sudo /usr/local/bin/nc-daemon
```

---

## 🗺️ 开发路线

| 阶段 | 模块 | 状态 | 说明 |
|------|------|------|------|
| 一 | 云端控制中心 | ✅ 完成 | Go + Gin + SQLite，JWT 认证，配对 API |
| 二 | Linux 客户端 | ✅ 完成 | nc-daemon 守护进程，二维码，一键安装 |
| 三 | 手机 App | ✅ 完成 | Flutter 三页面，SSH 终端，扫码绑定 |
| 四 | 安全与合规 | ✅ 完成 | ACL 熔断，审计日志，限流，安全头 |
| — | Headscale 集成 | 📋 待办 | 对接 Headscale API 完成真实设备授信 |
| — | 微信登录 | 📋 待办 | OAuth 流程接入 |
| — | CI/CD | 📋 待办 | 自动编译与发布流水线 |
| — | 生产 DERP | 📋 待办 | 官方中转节点部署 |

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.