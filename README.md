<div align="center">

# 🐟 fishtools

### 咸鱼工具箱

[![Version](https://img.shields.io/badge/version-v1.4.8-blue.svg?style=for-the-badge)](https://github.com/qqzhoufan/fishtools)
[![Author](https://img.shields.io/badge/author-咸鱼银河-orange.svg?style=for-the-badge)](https://github.com/qqzhoufan)
[![Language](https://img.shields.io/badge/language-Bash-brightgreen.svg?style=for-the-badge)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

**一站式 VPS 管理与自动化部署工具箱**

将 Linux 服务器上复杂繁琐的命令行操作，汇集于一个清晰、易用的交互式菜单中

[快速开始](#-快速开始) •
[功能一览](#-功能一览) •
[开发者指南](#-开发者指南) •
[致谢](#-致谢)

---

```
    _____ _     _   _____           _     
   |  ___(_)___| |_|_   _|__   ___ | |___ 
   | |_  | / __| '_ \| |/ _ \ / _ \| / __|
   |  _| | \__ \ | | | | (_) | (_) | \__ \
   |_|   |_|___/_| |_|_|\___/ \___/|_|___/
```

</div>

---

## 🧭 设计哲学

| 原则 | 说明 |
|:---:|:---|
| ✨ **简单易用** | 彻底告别记忆繁琐的命令，所有功能均通过直观的菜单驱动 |
| 💪 **强大可靠** | 集成业界经过广泛验证的优秀脚本，并增加备用链接和错误处理 |
| 🛡️ **安全第一** | 高风险操作都会进行醒目的警告提示和二次确认，防止误操作 |
| 🧹 **保持纯净** | 所有临时脚本文件都会在执行完毕后自动清理 |

---

## 🚀 快速开始

### 支持的系统

| 发行版 | 版本 |
|:---|:---|
| Debian | 10 / 11 / 12+ |
| Ubuntu | 20.04 / 22.04 / 24.04+ |
| CentOS | 7 / 8 / Stream 9 |
| Fedora | 38+ |
| RHEL | 8 / 9 |

### 方式一：一键安装 (推荐)

```bash
# 下载并安装 fish 命令
curl -sL -o fishtools.sh https://raw.githubusercontent.com/qqzhoufan/fishtools/main/fishtools.sh && chmod +x fishtools.sh && ./fishtools.sh --install

# 然后就可以直接使用
fish
```

### 方式二：直接运行 (不安装)

```bash
bash <(curl -sL https://raw.githubusercontent.com/qqzhoufan/fishtools/main/fishtools.sh)
```

---

## 📋 功能一览

### 主菜单结构

```
┌─────────────────────── 主菜单 ───────────────────────┐
│                                                      │
│  1. 💻  系统状态监控                                 │
│  2. 🚀  性能/网络测试                                │
│  3. 💿  DD系统/重装系统                              │
│  4. 📦  常用软件安装                                 │
│  5. 🐳  Docker Compose 项目部署                      │
│  6. ⚡  VPS 优化                                     │
│  7. 🔧  系统工具                                     │
│  8. 🌐  网络隧道工具 (Gost)                          │
│  9. 🤖  虾和马                                        │
│ 10. 🩺  全功能巡检                                   │
│                                                      │
└──────────────────────────────────────────────────────┘
```

---

### 1. 💻 系统状态监控

实时掌握服务器的健康状况与资源使用情况。

| 功能 | 说明 |
|:---|:---|
| 📊 VPS 基本信息 | CPU/内存/磁盘、公网IP、运行时间、负载、虚拟化类型 |
| 📈 VPS 实时性能 | CPU/内存/SWAP/磁盘使用率、IO等待、网络连接数 |
| 🌐 网络流量监控 | 实时上传/下载速度，累计流量统计 |
| ⚙️ 进程管理 | CPU/内存占用 TOP 10，支持 PID 终止进程 |
| 🔌 端口查看 | TCP/UDP 监听端口及对应进程 |
| 🔧 系统服务管理 | 查看/启动/停止/重启 systemd 服务 |

---

### 2. 🚀 性能/网络测试

一键运行各类专业测试脚本，全面了解 VPS 性能与网络质量。

| 功能 | 说明 |
|:---|:---|
| 🔥 融合怪测试 | 集成 [spiritLHLS/ecs](https://github.com/spiritLHLS/ecs)，CPU/内存/磁盘性能 + 全球测速 |
| 🐟 **咸鱼 IP 检测 (原创)** | 包含 IP 信息、安全检测、15+ 流媒体平台解锁检测 |
| 🛤️ 路由测试 | 回程路由 (VPS→中国) + 去程路由 (中国→VPS) |
| 📡 Speedtest 测速 | Ookla Speedtest CLI 一键测速 |
| 🌐 三网测速 | 电信/联通/移动三大运营商节点测速 |
| 💾 磁盘 IO 测试 | 顺序读写速度 + 4K 随机 IOPS 测试 |
| 📺 流媒体解锁检测 | Netflix/Disney+/YouTube Premium 等解锁状态 |

#### 🐟 咸鱼 IP 检测 功能详情

**这是 fishtools 的原创功能**，不依赖第三方脚本：

| 模块 | 检测内容 |
|:---|:---|
| 📡 IP 信息 | IPv4/IPv6、国家、城市、ISP、ASN、时区 |
| 🛡️ 安全检测 | DNS 服务器、IPv6 支持 |
| 📺 流媒体解锁 | Netflix, YouTube Premium, Disney+, HBO Max, Amazon Prime, BBC iPlayer, Twitch, DAZN, Spotify, TikTok, ChatGPT, Google, Gemini, Wikipedia, Bilibili, Steam |

---

### 3. 💿 DD系统/重装系统

> [!WARNING]
> **高风险操作警告**：此功能会**彻底清空**服务器硬盘上的**所有数据**！
> - 请仅在完全理解其后果的情况下使用
> - 务必提前备份所有重要数据
> - 错误操作可能导致 VPS 失联

| 功能 | 脚本来源 | 说明 |
|:---|:---|:---|
| 💿 reinstall | [bin456789/reinstall](https://github.com/bin456789/reinstall) | 通用系统重装，支持多种 Linux 发行版 |
| 🐣 LXD小鸡DD | [LloydAsp/OsMutation](https://github.com/LloydAsp/OsMutation) | 专为 LXD 虚拟化容器设计 |

---

### 4. 📦 常用软件安装

快速搭建服务器运行环境。

| 软件 | 说明 |
|:---|:---|
| 🐳 Docker & Compose | 容器化解决方案，现代化应用部署的基石 |
| 🌐 Nginx | 高性能 Web 服务器和反向代理，支持一键配置反向代理和 HTTPS |
| 🔒 Caddy | 自动 HTTPS 证书的现代 Web 服务器 |
| 🛡️ 安全工具 | Fail2Ban 防暴力破解、UFW 防火墙管理、SSH 安全配置 |

#### 🛡️ 安全工具功能详情

| 功能 | 说明 |
|:---|:---|
| 🔐 Fail2Ban | 防暴力破解，自动封禁恶意 IP |
| 🧱 UFW 防火墙 | 端口管理、规则配置、一键开关 |
| 🔑 SSH 安全配置 | 密钥对生成、禁用密码登录、公钥管理 |

> [!TIP]
> SSH 密钥生成功能会自动配置 sshd 服务，生成后只需将私钥复制到本地即可使用！

---

### 5. 🐳 Docker Compose 项目部署

**fishtools 的核心特色功能** —— 一个小型的"应用商店"。

| 项目 | 说明 |
|:---|:---|
| 🏠 Homepage | 精美的个人导航起始页 |
| 🔀 Nginx Proxy Manager | 可视化 Nginx 反向代理管理器 |
| 🎵 Navidrome | 自托管音乐流媒体服务器 |
| 📥 qBittorrent | 功能强大的 BT 下载客户端 |
| 📺 MoonTV | 观影资源聚合平台 |
| 🎬 Jellyfin | 开源媒体服务器 |
| ☁️ Nextcloud | 私有云盘 |
| 📂 Alist | 网盘聚合工具 |
| 🔑 Vaultwarden | 自托管密码管理器 |
| 📊 Uptime Kuma | 轻量级服务监控面板 |
| 🐳 Portainer | Docker 可视化管理 |
| 📷 PhotoPrism | AI 照片管理 |
| 🛡️ AdGuard Home | DNS 广告过滤 |
| 📚 Calibre-Web | 电子书管理 |
| 📁 FileBrowser | Web 文件管理器 |
| 🔄 Syncthing | 文件同步工具 |
| 📥 Transmission | 轻量 BT 下载客户端 |
| 🐙 Gitea | 自托管 Git 服务 |

> [!TIP]
> 所有预设项目都支持一键部署，自动下载配置文件并启动容器！

---

### 6. ⚡ VPS 优化

提升 VPS 性能和网络体验的实用工具。

| 功能 | 说明 |
|:---|:---|
| 🚄 BBR 加速 | 启用 Google BBR 拥塞控制算法，优化网络性能 |
| 💾 SWAP 管理 | 创建/管理虚拟内存，防止内存耗尽导致崩溃 |
| 🌍 WARP 管理 | Cloudflare WARP 服务，增加 IPv4/IPv6 支持 |

---

### 7. 🔧 系统工具

便捷的系统维护和配置工具集。

| 功能 | 说明 |
|:---|:---|
| 🧹 磁盘清理 | APT/DNF/YUM 缓存、系统日志、临时文件、旧内核一键清理 |
| 🌐 修改时区 | 快速切换常用时区 |
| 🏷️ 修改主机名 | 一键修改服务器主机名 |
| 🔌 修改 SSH 端口 | 安全加固，自动同步 fail2ban 和防火墙 |
| 📅 定时任务管理 | Cron 任务的添加/编辑/删除 |
| 🔄 系统重启/关机 | 定时重启、立即关机等 |
| 📦 系统包一键更新 | 一键更新所有已安装软件包 |
| 📋 系统日志查看 | syslog/认证日志/dmesg/实时跟踪/关键词搜索 |
| 📊 流量统计 (vnstat) | 月度/日/小时流量统计与实时监控 |
| 🩺 全功能巡检 | 按主菜单检查依赖、权限、Docker、GitHub、第三方脚本源、AI 工具、磁盘和端口 |
| ♻️ 配置备份恢复 | 恢复工具自动备份的 SSH/Nginx/Caddy 等配置文件 |

---

### 9. 🤖 虾和马

AI Agent 工具集合，集中管理 [OpenClaw](https://github.com/openclaw/openclaw) 和 [Hermes Agent](https://github.com/NousResearch/hermes-agent)。

| 功能 | 说明 |
|:---|:---|
| 🤖 OpenClaw AI 助手 | 保留原 OpenClaw 完整安装、部署、管理菜单 |
| ☤ Hermes Agent | 一键安装 Hermes Agent，并提供 setup、gateway、doctor、迁移配置等常用入口 |

#### OpenClaw 功能

| 功能 | 说明 |
|:---|:---|
| 📦 npm 安装 | 自动检测/安装 Node.js 22+，全局安装 OpenClaw |
| 🐳 Docker 部署 | 生成 docker-compose.yml，配置 API Key，一键启动 |
| ▶️ 启动/停止 | 管理 OpenClaw 网关服务 |
| 📊 状态/日志 | 查看运行状态和最近日志 |
| 🗑️ 卸载 | 支持 Docker 和 npm 两种方式的完整卸载 |

#### Hermes Agent 功能

| 功能 | 说明 |
|:---|:---|
| 📦 一键安装 | 下载并运行 Nous Research 官方安装脚本 |
| 🧭 setup 向导 | 配置模型、工具和消息网关 |
| 💬 终端聊天 | 启动 Hermes CLI |
| 🌉 消息网关 | 启动 Telegram/Discord/Slack 等网关入口 |
| 🩺 doctor 诊断 | 调用 `hermes doctor` 检查运行环境 |
| 🔁 配置迁移 | 调用 `hermes claw migrate` 从 OpenClaw 迁移配置 |

> [!TIP]
> OpenClaw 推荐使用 Docker 方式部署，隔离性好且易于更新。Hermes Agent 推荐用日常登录用户安装，避免装到 root 用户环境。

---

### 🚀 命令行快捷方式

安装后可通过命令行参数快速执行常用操作：

```bash
# 首次使用需安装 fish 命令
./fishtools.sh --install

# 安装后即可使用 fish 命令（若系统已安装 fish shell，命令名自动变为 fishtool）
fish --help      # 显示帮助信息
fish --version   # 显示版本
fish --update    # 检查并更新脚本
fish --info      # 快速查看系统信息
fish --doctor    # 全功能巡检
fish --bbr       # 一键开启 BBR
fish --docker    # 进入 Docker 管理
fish --test      # 进入性能测试菜单
```

> [!TIP]
> 如果系统已安装 fish shell，安装时会自动检测并使用 `fishtool` 作为命令名，避免冲突。

---

### 8. 🌐 网络隧道工具 (Gost)

基于 [Gost](https://github.com/ginuerzh/gost) 的 TLS 加密隧道转发管理。

| 功能 | 说明 |
|:---|:---|
| 🖥️ 本地配置 | 一键将本机配置为落地鸡或线路鸡 |
| 📡 中心化管理 | 集中管理多节点，批量生成配置脚本 |
| 🔗 节点关联 | 线路鸡与落地鸡的灵活关联/取消 |
| ⚙️ 自动部署 | 生成一键部署脚本，systemd 服务托管 |

> 单文件运行时如果缺少 Gost 辅助脚本，工具会自动从本仓库下载并加载。

---

## 👨‍💻 开发者指南

### 源码结构

`fishtools.sh` 是面向用户的一键发布文件；日常开发请修改 `src/` 下的模块文件，然后重新生成发布脚本：

```bash
bash scripts/build-release.sh
```

Windows PowerShell 环境也可以运行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build-release.ps1
```

推荐发布前检查：

```bash
bash -n fishtools.sh scripts/*.sh
shellcheck fishtools.sh src/**/*.sh scripts/*.sh
```

### 如何添加新的预设项目

<details>
<summary>点击展开详细步骤</summary>

#### 第一步：添加预设文件

```
fishtools/
├── fishtools.sh
├── README.md
├── src/
│   ├── core/
│   ├── ui/
│   └── modules/
└── presets/
    ├── homepage/
    │   └── docker-compose.yaml
    └── your-app/                    # 新增
        └── docker-compose.yml       # 新增
```

#### 第二步：修改脚本

1. 打开 `src/modules/70_deploy.sh`
2. 找到 `show_preset_deployment_menu` 函数
3. 在菜单中添加新选项
4. 在 `case` 语句中添加对应处理
5. 运行 `bash scripts/build-release.sh` 重新生成 `fishtools.sh`

#### 第三步：提交更改

将修改推送到 GitHub 即可生效。

</details>

---

## 🌟 致谢

本工具箱的强大功能得益于以下开源项目的无私贡献：

| 项目 | 作者 |
|:---|:---|
| [ecs.sh (融合怪)](https://github.com/spiritLHLS/ecs) | spiritLHLS |
| [reinstall.sh](https://github.com/bin456789/reinstall) | bin456789 |
| [OsMutation.sh](https://github.com/LloydAsp/OsMutation) | LloydAsp |
| [回程路由测试](https://github.com/zhanghanyun/backtrace) | zhanghanyun |
| [NextTrace](https://github.com/nxtrace/NTrace-core) | nxtrace |
| [BBR/TCP 优化](http://sh.nekoneko.cloud/) | nekoneko.cloud |
| [SWAP 管理](https://www.moerats.com/) | Moerats |
| [WARP 管理](https://gitlab.com/fscarmen/warp) | fscarmen |
| [Hermes Agent](https://github.com/NousResearch/hermes-agent) | Nous Research |

以及 [**NodeSeek 论坛**](https://www.nodeseek.com/) 和其他技术社区的网友们！

---

## 📝 更新日志

### v1.4.8

**巡检入口优化:**
- 主菜单新增 `10. 全功能巡检`，打开工具箱第一屏即可看到
- `fish --doctor` / 系统工具内入口继续保留

### v1.4.7

**全功能巡检:**
- 系统工具中新增/升级「全功能巡检」，按主菜单逐项检查运行条件
- 新增 `fish --doctor` / `fish --check` 命令行入口
- 巡检覆盖权限、核心依赖、GitHub 更新源、Docker/Compose、第三方脚本源、AI 工具、磁盘/inode/内存和常用端口

### v1.4.6

**部署输出修复:**
- Docker 项目部署成功后，访问地址自动显示 VPS 公网 IP，不再硬编码 `服务器IP`
- OpenClaw Docker 部署成功后的访问地址也同步改为自动取服务器 IP
- SSH 密钥登录提示里的服务器地址也改为统一自动识别

### v1.4.5

**AI 工具菜单:**
- 主菜单第 9 项改为「虾和马」，作为 AI Agent 工具集合入口
- OpenClaw 移入「虾和马」菜单，原有 OpenClaw 管理功能保持不变
- 新增 Hermes Agent 一键安装、setup、gateway、doctor、OpenClaw 配置迁移入口

### v1.4.4

**GitHub Raw 缓存修复:**
- 更新器优先通过 GitHub API 获取 `main` 最新 commit SHA，再下载固定 commit 的 `fishtools.sh`
- 避免 `raw.githubusercontent.com/.../main/...` 分支缓存滞后导致 VPS 一直停留在旧版本

### v1.4.3

**更新可靠性修复:**
- `--update` 使用 no-cache 请求和时间戳链接，避免 VPS 拿到 GitHub Raw 旧缓存
- 更新时显示当前脚本路径与远端版本，便于判断是否更新到了实际运行的 `fish` 命令
- 更新提醒框改为 ASCII 样式，减少终端兼容问题

### v1.4.2

**界面兼容性修复:**
- 默认使用 ASCII 边框，避免部分 SSH 终端显示 `�` 乱码
- 菜单项默认隐藏 emoji 图标，修复不同终端 emoji 宽度导致的对齐问题
- 支持 `FISHTOOLS_EMOJI=1 fish` 开启 emoji，`FISHTOOLS_UNICODE=1 fish` 开启 Unicode 边框

### v1.4.1

**热修复:**
- 修复模块化构建后启动入口未进入主菜单的问题
- `--update` 支持同版本内容更新，避免热修复因版本号相同被跳过

### v1.4

**安全与稳定性修复:**
- 移除全局 `set -eo pipefail`，修复交互式菜单中子命令返回非 0 导致脚本退出的问题
- 修复 BBR 优化脚本使用 HTTP 明文下载的安全隐患 (改为 HTTPS)
- 修复 Docker Compose 部署后 `cd` 污染全局工作目录的问题
- 增加 ufw 端口输入格式验证，防止命令注入
- 增加主机名格式校验 (RFC 1123)
- Docker 卸载改用通用 `pkg_remove()` 适配多发行版
- 磁盘清理适配 apt/dnf/yum 多包管理器
- 启动时增加 root 权限检测与提示

**新功能:**
- 新增 Docker Hub 镜像加速配置 (DaoCloud/南京大学/官方中国镜像/自定义)
- 新增系统包一键更新 (apt upgrade / dnf upgrade / yum update)
- 新增系统日志查看器 (syslog/auth/dmesg/实时跟踪/关键词搜索)
- 新增 vnstat 流量统计 (月/日/时/实时监控)
- SSH 端口修改后自动同步更新 fail2ban 配置

### v1.3

- **修复** fail2ban 在 Debian 12+/Ubuntu 22.04+ (journald) 系统上安装后无法工作的问题
- **修复** fail2ban 现已支持 CentOS/RHEL 系统 (`/var/log/secure`)
- **修复** Gost 隧道管理中多端口转发只生成单一端口的 bug
- **修复** Gost 本地配置 relay 模式无法正确生成多参数命令的 bug
- **修复** Navidrome 预设 Docker Compose 文件 YAML 语法错误
- **修复** qBittorrent 预设中残留的私人路径配置
- **修复** Gost 节点列表中引用不存在字段 (ssh_port) 导致显示 null
- **优化** 新增通用包管理器适配 (apt/dnf/yum)，软件安装不再仅限 Debian/Ubuntu
- **优化** `--install` 自动检测 fish shell 避免命令冲突
- **优化** 颜色变量定义前移，提升代码结构健壮性
- **优化** 清理 Docker Compose 预设中已废弃的 `version` 字段
- **优化** 完善 README，补全 18 个预设项目列表和 Gost 隧道功能说明

### v1.2

- 新增命令行参数支持
- 新增 Gost 隧道管理 (本地配置 + 中心化管理)
- 新增 Docker Compose 预设项目部署

### v1.0

- 初始版本发布

---

## 🤝 如何贡献

欢迎任何形式的贡献！

1. **Fork** 本仓库
2. 创建功能分支：`git checkout -b feature/AmazingFeature`
3. 提交更改：`git commit -m 'Add AmazingFeature'`
4. 推送分支：`git push origin feature/AmazingFeature`
5. 提交 **Pull Request**

---

## 📄 许可证

本项目采用 [MIT License](https://opensource.org/licenses/MIT) 开源许可证。

---

<div align="center">

**Made with ❤️ by [咸鱼银河](https://github.com/qqzhoufan)**

</div>
