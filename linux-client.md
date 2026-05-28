Monorepo 的第一部分（云端控制中心）骨架搭建好后，下一步就是开发 **`linux-client/`** 目录下的内容。

这一阶段的核心任务是**编写给用户复制粘贴的一键安装脚本，并在 Linux 后台跑一个守护进程（Daemon）**。它要负责在复杂的公司/学校网络下静默打洞，并吐出二维码让手机扫描。

---

# 💻 阶段二详细设计：Linux 客户端（Daemon）技术方案

## 1. 核心运行流程

用户在你的网站/App 上登录后，复制一行命令到 Linux（如 WSL2 或实验室 Ubuntu）中运行：

1. `install.sh` 脚本检测环境，下载专用的二进制包。
2. 守护进程 `nc-daemon` 启动，在后台拉起裁剪版的 Tailscale 内核。
3. 自动向你的云端控制中心发送注册请求，拿到配对 Token。
4. **在终端直接打印出漂亮的二维码和字符 Token**，并开始挂起轮询云端状态。
5. 手机扫码确认后，云端授信，Linux 端收到轮询成功的信号，网络正式打通。

## 2. 关键核心开发项

### A. 环境与依赖检测（WSL2 特殊优化）

国内极客和打工人大量使用 Windows 下的 WSL2。WSL2 有一个致命痛点：默认不支持 `systemd` 服务管理（虽然新版支持，但很多人的没开启）。

* **你的策略**：`nc-daemon` 不要强制依赖系统的 `systemctl start`。最好直接用 Go 语言的 `os/exec` 包在进程内部启动、管理和监控 Tailscale 内核进程（`tailscaled`），做成**自包含的守护进程**。

### B. 二进制内核裁剪

原生的 Tailscale 包含了大量路由、DNS 劫持、SSH 服务的复杂功能，体积较大（接近 40MB）。

* **你的策略**：让 Claude Code 在编译客户端时，通过 Go 的编译裁剪参数（如剪掉不需要的控制面板等），或者直接使用其编译好的开源 `tailscaled` 核心。我们只需要它的 **WireGuard 隧道打洞能力**，其余一律关掉。

### C. 终端二维码渲染

在纯黑框的 Linux 终端里，如何让用户无脑扫码？

* **技术选型**：在 Go 语言中使用开源库 `github.com/skip2/go-qrcode`。它支持直接在 Linux 命令行（CLI）中用黑白方块字符**肉眼可见地渲染出标准的二维码**。

---

## 3. 核心代码逻辑与 API 交互（Daemon 伪代码逻辑）

你需要让 Claude Code 实现的 `nc-daemon` 核心 Go 代码逻辑如下：

1. **第一步：初始化并生成本地密钥**
检查本地 `~/.config/nextconnect/` 路径，如果没有，则生成 Tailscale 所需的随机 `MachineKey` 和 `NodeKey`。
2. **第二步：向云端报到（调用阶段一的接口）**
发送 `POST https://api.nextconnect.com/api/v1/pair/register`，提交本地的 `machine_key`。
3. **第三步：接收 Token 并打印二维码**
云端返回 `pairing_token`（如 `NC-789231`）后：
* 将链接 `https://nextconnect.com/bind?token=NC-789231` 转化为终端二维码打印出来。
* 界面提示：“请打开 NextConnect 手机 App 扫描下方二维码完成设备绑定”。


4. **第四步：死循环轮询（Poll）**
每隔 2 秒请求一次 `GET https://api.nextconnect.com/api/v1/pair/poll?token=NC-789231`。
5. **第五步：启动隧道**
一旦云端返回 `status: "approved"`，守护进程立刻在后台执行：
```bash
# 强制指向你的自建云端控制中心（Headscale）
tailscaled --tun=userspace-networking --listen-addr=localhost:1055
tailscale up --login-server=https://api.nextconnect.com --accept-routes=false

```


*注意：`--tun=userspace-networking` 是神仙参数，可以让用户在**没有 Linux Root/Sudo 权限**的情况下，依然能在应用层实现完美的虚拟网络连接！*

---

## 📋 4. 给 Claude Code 的第二步标准指令（Prompt）

```text
你现在是一个精通 Linux 系统编程、网络隧道（WireGuard/Tailscale）以及 Go 语言的专家。我们要开始开发 NextConnect 项目的 linux-client 部分。
请在主仓的 `linux-client/` 文件夹下完成以下任务：

1. 编写一个独立运行的 Go 程序 `nc-daemon` 作为 Linux 端的守护进程。
2. 内部逻辑要求：
   - 启动时自动检查或生成本地的 Tailscale 密钥对（MachineKey/NodeKey）。
   - 调用云端接口 `POST /api/v1/pair/register` 发起设备注册。
   - 引入 `github.com/skip2/go-qrcode` 库，将云端返回的配对链接在 Linux 终端（CLI）中以标准字符画的形式渲染成清晰的二维码。
   - 开启一个 Time 轮询器，每 2 秒请求一次 `GET /api/v1/pair/poll`。收到成功信号后，正式拉起后台的虚拟网络隧道，强制绑定 `--login-server` 为我们的云端地址。
3. 在 `linux-client/` 根目录下编写一个极简的 `install.sh` 脚本，用于自动化下载编译好的 `nc-daemon` 并将其设置为开机自启（兼顾支持 Systemd 和普通的 nohup 后台挂起模式，以完美兼容 WSL2 环境）。

请先输出 `nc-daemon` 的核心网络连接与二维码渲染状态机代码。

```