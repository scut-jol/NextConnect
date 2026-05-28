我强烈建议你采用 **Monorepo（单代码仓库）** 的架构。在一个 Git 仓库里，通过文件夹把云端、Linux 端、手机端隔开。这样 Claude Code 可以一眼通观全局，当你改了云端 API 时，它能自动把手机端的请求格式也一起改掉，效率直接起飞。

### 📂 你的 Git 仓库目录结构设计：

```text
nextconnect/ (主仓库)
├── .gitignore
├── README.md
├── cloud-server/     # 阶段一：云端控制中心 (Go 语言)
├── linux-client/     # 阶段二：Linux 一键脚本与守护进程 (Shell + Go/Rust)
└── mobile-app/       # 阶段三：手机 App 端 (Flutter)

---

# 🧱 阶段一详细设计：云端控制中心（Control Plane）技术方案

## 1. 技术选型与运行环境

* **核心语言**：Go (Golang)，与开源的 Headscale 保持一致，方便直接调用其内部包或进行二次开发。
* **数据库**：SQLite（前期 MVP 阶段足够，单文件易备份）/ PostgreSQL（后期商业化扩展）。
* **部署环境**：国内轻量应用服务器（如腾讯云/阿里云），1核2G，固定公网 IP。

## 2. 核心改写逻辑：如何“阉割并重塑” Headscale

Headscale 原生是用命令行（`headscale user create`）或者 OIDC（海外第三方登录）来创建用户和给设备授权的。我们需要编写一个**自定义的桥接服务（Bridge Service）**，接管它的路由。

### A. 数据库表结构扩展 (schema.sql)

在 Headscale 原有表的基础上，我们需要新增一张用户表，用来绑定国内的账号体系：

```sql
-- 用户主表
CREATE TABLE nc_users (
    id INTEGER PRIMARY KEY AUTO_INCREMENT,
    phone_number VARCHAR(11) UNIQUE NOT NULL, -- 国内手机号
    wechat_open_id VARCHAR(64) UNIQUE,        -- 微信登录标识
    nc_namespace VARCHAR(64) UNIQUE NOT NULL, -- 映射到 Headscale 的 Namespace 名称
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 设备绑定暂存表（用于扫码配对验证）
CREATE TABLE nc_pairing_tokens (
    token VARCHAR(64) PRIMARY KEY,           -- 终端打印出来的随机 Token
    machine_key VARCHAR(255) NOT NULL,       -- Tailscale 客户端生成的 MachineKey
    namespace VARCHAR(64) NOT NULL,          -- 属于哪个用户
    status VARCHAR(20) DEFAULT 'pending',    -- pending, approved, expired
    expires_at TIMESTAMP NOT NULL
);

```

### B. 核心 API 路由设计 (RESTful API)

你需要让 Claude Code 在 Go 后端实现以下几个对内/对外接口：

#### ① `POST /api/v1/auth/login` (手机端登录)

* **功能**：处理手机号验证码或微信登录请求。
* **逻辑**：如果是新用户，在 `nc_users` 表里为其创建一条记录，并生成一个全局唯一的 `nc_namespace`（例如：`nc_usr_77a28f`）。同时在 Headscale 中通过代码调用其创建 Namespace 的方法。
* **返回**：JWT Token（包含用户的 Namespace 权限），供手机 App 后续请求使用。

#### ② `POST /api/v1/pair/register` (Linux 客户端发起注册)

* **功能**：Linux 端的一键脚本启动时，向云端报到。
* **请求体**：
```json
{
  "machine_key": "mkey:xxxxxxxxxxxxxxxx",
  "node_key": "nodekey:xxxxxxxxxxxxxxxx"
}

```


* **逻辑**：云端收到请求后，生成一个临时的、带过期时间的随机 `PairingToken`（如 `NC-789231`）。存入 `nc_pairing_tokens` 表，状态为 `pending`。
* **返回**：`{"pairing_token": "NC-789231", "poll_url": "/api/v1/pair/poll?token=..."}`。

#### ③ `POST /api/v1/pair/confirm` (手机端扫码确认绑定)

* **功能**：手机 App 扫描 Linux 屏幕上的二维码后，向云端发送确认请求。
* **Header**：携带手机端 JWT Token。
* **请求体**：`{"pairing_token": "NC-789231"}`。
* **逻辑**：
1. 校验手机端 JWT，获取该用户的 `namespace`。
2. 查询 `nc_pairing_tokens` 表中对应的 Token。
3. **关键核心操作**：调用 Headscale 内部的 `protocol.ApproveNode()` 方法，将该 `machine_key` 的设备，强制强制划归到该用户的 `namespace` 之下。
4. 将 `nc_pairing_tokens` 状态改为 `approved`。



#### ④ `GET /api/v1/pair/poll` (Linux 客户端轮询结果)

* **功能**：Linux 端脚本挂起等待，直到手机端确认。
* **逻辑**：检查 Token 状态。一旦变为 `approved`，通知 Linux 客户端：“绑定成功，可以起飞”。

---

## 💻 3. 给 Claude Code 的第一步标准指令（Prompt）

你可以把下面这段话复制，直接丢给 Claude Code 让它开始干活：

```text
你现在是一个精通 Go 语言和网络协议的高级架构师。我们要开始开发 NextConnect 项目的 cloud-server 部分。
请在当前目录的 `cloud-server/` 文件夹下完成以下任务：

1. 初始化一个 Go 项目，引入 Headscale 作为依赖库（或者提取其核心的节点授信、控制面协商代码）。
2. 使用 Gin 框架（或原生 net/http）搭建 API 路由，实现以下 3 个核心接口：
   - `POST /api/v1/auth/login`：模拟手机号登录，在 SQLite 数据库中为用户划分独立的 Headscale Namespace。
   - `POST /api/v1/pair/register`：接收 Linux 客户端传来的 MachineKey，生成一个临时配对 Token。
   - `POST /api/v1/pair/confirm`：接收手机端发来的配对 Token，在内部调用 Headscale API 完成设备授信（Approve）和绑定。
3. 请使用 SQLite 作为底层数据库，并写好自动初始化表结构的初始化代码（包含 nc_users 和 nc_pairing_tokens 表）。

请先输出项目的基础骨架代码和数据库设计，并向我解释你是如何将自定义的用户系统与 Headscale 的设备授信逻辑结合在一起的。
