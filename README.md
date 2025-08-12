# fishtools (咸鱼工具箱) 🧰

[![Version](https://img.shields.io/badge/version-v1.0-blue.svg)](https://github.com/qqzhoufan/fishtools)
[![Author](https://img.shields.io/badge/author-咸鱼银河-orange.svg)](https://github.com/qqzhoufan)
[![Language](https://img.shields.io/badge/language-Bash-brightgreen.svg)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

一款由 **咸鱼银河** 开发的 **一站式VPS管理与自动化部署工具箱**。`fishtools` 致力于将Linux服务器上复杂繁琐的命令行操作，汇集于一个清晰、易用的交互式菜单中，无论是Linux新手还是资深玩家，都能通过它轻松完成对VPS的性能监控、环境配置、应用部署和系统优化等一系列工作，真正实现“化繁为简”。

---

## 🧭 设计哲学

`fishtools` 的开发遵循以下核心原则：

* **✨ 简单易用 (Simplicity):** 彻底告别记忆繁琐的命令。所有功能均通过直观的菜单驱动，只需根据提示选择数字即可完成操作。
* **💪 强大可靠 (Powerful & Reliable):** 工具箱内集成的所有第三方脚本，均为在业界经过广泛验证、功能强大的优秀作品。我们通过增加备用下载链接和错误处理，进一步提升了其可靠性。
* **🛡️ 安全第一 (Safety First):** 对于所有高风险操作（如DD重装系统），脚本都会进行醒目的警告提示和二次确认，最大限度地防止误操作。
* **🧹 保持纯净 (Keep Clean):** 所有通过本工具箱下载的临时脚本文件，都会在执行完毕后自动清理，保持您的系统目录干净整洁。

-----

## 🚀 安装与运行

为了保证脚本中所有交互功能的正常使用，我们强烈推荐使用第一种方式启动。

### 方式一：完整下载 (官方推荐)

这种方式将脚本完整下载到本地再运行，兼容性最好，可以完全避免各类因环境不同导致的意外问题。

```bash
# 1. 下载脚本
curl -sL -o fishtools.sh https://raw.githubusercontent.com/qqzhoufan/fishtools/main/fishtools.sh

# 2. 赋予执行权限
chmod +x fishtools.sh

# 3. 运行脚本
./fishtools.sh
```

### 方式二：一键流式 (便捷)

如果您确认您的终端环境支持 `bash <(...)` 语法，也可以使用此命令来快速启动。

```bash
bash <(curl -sL https://raw.githubusercontent.com/qqzhoufan/fishtools/main/fishtools.sh)
```

-----

## 🛠️ 功能详解

`fishtools` 将所有核心功能都整合到了主菜单中，让您可以轻松访问。

### 1\. 💻 系统状态监控 (System Status Monitoring)

通过一个独立的子菜单，随时掌握您服务器的健康状况。

* **显示VPS基本信息:** 提供一份服务器的静态“体检报告”，就像电脑的配置清单。它会清晰地列出CPU型号、核心数、内存总量、系统架构、精确的操作系统版本和Linux内核版本。
* **显示VPS实时性能:** 获取服务器在当前时刻的动态负载快照，帮助您判断服务器是否繁忙。它会显示CPU的实时使用率、内存的已用/剩余情况以及系统根目录的磁盘空间占用。

### 2\. ⚡ 性能与网络测试 (Bench & Network Tests)

想知道您的VPS性能究竟如何？网络是“CN2 GIA”还是“普通线路”？这个模块集成了强大的测试脚本，一键为您揭晓答案。

* **融合怪 (ecs.sh) 综合测试:** 集成了广受好评的 `ecs.sh` 融合怪脚本。它能提供包括系统信息、CPU/内存/磁盘性能、以及到全球各地（特别是中国大陆各地区）的网络速度、延迟和路由跟踪在内的全方位测试报告。

### 3\. 💿 DD系统/重装系统 (System Reinstallation)

> [\!WARNING]
> **高风险操作警告：** 这是本工具箱中风险最高的功能，会 **彻底清空** 您服务器硬盘上的 **所有数据**！
>
>   * 请仅在您完全理解其后果的情况下使用。
>   * 务必提前备份好所有重要数据。
>   * 错误的操作可能导致VPS失联，届时需要联系服务商进行救援。

此模块集成了强大的网络重装脚本，可以为您更换为全新的、纯净的Linux操作系统。

* **reinstall (通用系统重装):** 来自 `bin456789` 的强大脚本，支持多种主流Linux发行版的全自动网络重装。
* **LXD小鸡DD (NS酒神脚本):** 专为LXD虚拟化架构的容器（俗称“LXD小鸡”）设计的系统重装脚本。

### 4\. 📦 常用软件安装 (Essential Software Installation)

为您快速搭建最常用的服务器运行环境。

* **Docker & Docker Compose:** 一键安装当前业界最主流的容器化解决方案，是现代化应用部署的基石。
* **Nginx:** 高性能、极其稳定的Web服务器和反向代理软件。
* **Caddy:** 一款现代化的、默认开启并自动续签HTTPS证书的Web服务器，配置简单。

### 5\. ✨ Docker Compose 项目部署 (特色功能)

这不仅仅是一个功能，更是一个小型的“应用商店”，也是 `fishtools` 的核心特色。

* **一键部署精选项目 (推荐): 从作者预设的菜单中选择热门应用，如 Homepage、Nginx-Proxy-Manager、Navidrome、qBittorrent、MoonTV 等，实现全自动下载、配置和启动。

### 6\. 🚀 VPS 优化 (VPS Optimization)

提供一系列经过验证的优化脚本，用于改善您VPS的性能和网络体验。

* **开启BBR加速和TCP调优:** 通过启用Google BBR等现代网络拥塞控制算法，显著改善网络连接质量，降低延迟、提升速度，尤其适合访问海外资源。
* **添加/管理 SWAP:** 当您的VPS物理内存（RAM）较小时，创建SWAP（虚拟内存）可以作为一个临时的缓冲，防止因内存耗尽而导致应用程序或系统崩溃。
* **安装/管理 WARP:** 集成了Cloudflare的WARP服务脚本。它可以为您的VPS增加IPv4或IPv6网络接口，解决某些网络环境下连接不畅或特定服务无法访问的问题。

-----

## 🧑‍💻 开发者指南：如何扩充“精选项目”

作为本脚本的维护者 **(咸鱼银河)**，您可以非常轻松地扩充您的“应用商店”。

**第一步：在项目中添加预设文件**

1.  在您的 `fishtools` 项目根目录中，确保有一个名为 `presets` 的文件夹。
2.  当您想新增一个应用（如`alist`）时，只需在 `presets` 文件夹内创建一个同名的新文件夹 `alist`。
3.  将为 `alist` 准备好的 `docker-compose.yml` 或 `.yaml` 文件放入 `presets/alist/` 中。

项目结构应如下所示：

```
fishtools/
├── fishtools.sh
├── README.md
└── presets/
    ├── homepage/
    │   └── docker-compose.yaml
    └── alist/
        └── docker-compose.yml
```

**第二步：修改 `fishtools.sh`**

1.  打开 `fishtools.sh` 脚本文件, 找到 `show_preset_deployment_menu` 函数。
2.  在菜单的 `echo` 列表中增加一行，用于显示新项目。
3.  在 `case` 逻辑中为新项目增加对应的处理分支。

**第三步：提交更改**

将您所有的修改（包括新增的 `presets` 文件和改动的 `fishtools.sh`）提交到 GitHub 即可。

-----

## 🌟 致谢

本工具箱的许多强大功能，都得益于以下开源项目作者的无私贡献，在此表示衷心的感谢：

* **ecs.sh (融合怪):** [spiritLHLS](https://github.com/spiritLHLS/ecs)
* **reinstall.sh:** [bin456789](https://github.com/bin456789/reinstall)
* **OsMutation.sh (LXD DD):** [LloydAsp](https://github.com/LloydAsp/OsMutation)
* **BBR/TCP 优化:** [nekoneko.cloud](http://sh.nekoneko.cloud/)
* **SWAP 管理:** [Moerats](https://www.moerats.com/)
* **WARP 管理:** [fscarmen](https://gitlab.com/fscarmen/warp)
* 以及 [**NS论坛 (NodeSeek)**](https://www.nodeseek.com/) 和其他技术社区的网友们提供的宝贵经验与脚本。

-----

## 🤝 如何贡献

我们欢迎任何形式的贡献，无论是代码还是功能建议！

1.  **Fork** 本仓库
2.  创建您的功能分支 (`git checkout -b feature/AmazingFeature`)
3.  提交您的更改 (`git commit -m 'Add some AmazingFeature'`)
4.  推送至分支 (`git push origin feature/AmazingFeature`)
5.  提交一个 **Pull Request**

-----

## 📄 许可证

本项目采用 [MIT](https://opensource.org/licenses/MIT) 许可证。