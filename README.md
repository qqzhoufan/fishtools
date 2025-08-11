# fishtools (咸鱼工具箱) 🧰

[![Version](https://img.shields.io/badge/version-v2.8-blue.svg)](https://github.com/qqzhoufan/fishtools)
[![Author](https://img.shields.io/badge/author-咸鱼银河-orange.svg)](https://github.com/qqzhoufan)
[![Language](https://img.shields.io/badge/language-Bash-brightgreen.svg)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

一款由 **咸鱼银河** 开发的 **一站式VPS管理与自动化部署工具箱**。它将服务器的性能监控、环境配置、应用部署和系统维护等复杂操作，汇集于一个清晰、易用的交互式菜单中，旨在成为您管理VPS的得力助手。

---

## 📖 快速上手

在您的VPS上，仅需一行命令即可启动“咸鱼工具箱”。

```bash
curl -sL https://raw.githubusercontent.com/qqzhoufan/fishtools/main/fishtools.sh | bash
```
> **高兼容性命令：** 此命令使用管道，确保在几乎所有Linux环境中都能稳定运行。  
> **提示：** 从网页复制命令时，请确保没有带上额外的格式。如果粘贴后运行报错 `syntax error`，请尝试手动输入此命令。

---

## 🚀 功能详解

`fishtools` 将所有核心功能都整合到了主菜单中，让您可以轻松访问。

### 1. & 4. VPS 状态监控 (VPS Status Monitoring)

随时掌握您服务器的健康状况。

* **显示VPS基本信息 (菜单 - 1):** 提供一份服务器的静态“体检报告”，包含CPU型号、核心数、内存总量、操作系统与内核版本等。
* **显示VPS实时性能 (菜单 - 4):** 获取服务器当前的动态负载快照，包含CPU、内存、硬盘的实时使用率。

### 2. 性能与网络测试 (Bench & Network Tests)

无需再到处寻找测试脚本，我们为您内置了行业主流的测试工具。

* **Superbench:** 全面测试VPS的硬件信息、I/O性能以及到国内外的网络速度。
* **Lemonbench:** 另一款强大的综合性测试工具，提供详尽的硬件、网络及性能评估报告。

### 5. 常用软件安装 (Essential Software Installation)

通过子菜单，一键安装和配置最常用的服务器软件，为部署应用打下基础。

* **Docker & Docker Compose:** 业界领先的容器化解决方案。
* **Nginx:** 高性能Web服务器和反向代理。
* **Caddy:** 新一代Web服务器，以其自动化的HTTPS功能而闻名。

### 6. Docker 应用部署 (Docker Application Deployment) ✨

这不仅仅是一个功能，更是一个小型的“应用商店”，也是 `fishtools` 的核心特色。

* **一键部署精选项目 (推荐):** 为普通用户设计，无需任何配置！直接从菜单中选择作者预设好的热门应用（如 `Portainer`, `Homepage` 等），即可全自动下载、配置和启动。

### 3. 系统维护工具 (System Maintenance Tools)

提供一些高阶的系统管理功能。

* **DD系统/重装系统:**
  > **警告：** 此功能风险极高！它会完全擦除您服务器的现有数据。请仅在您完全理解其后果的情况下使用，并务必提前备份好所有重要数据。

---

## 🧑‍💻 开发者指南：如何扩充您的“精选项目”

作为本脚本的维护者 **(咸鱼银河)**，您可以非常轻松地扩充您的应用商店。

**第一步：在本地项目中添加预设文件**

1.  在您本地的 `fishtools` 项目文件夹中，确保有一个名为 `presets` 的文件夹。
2.  当您想新增一个应用（如`alist`）时，只需在 `presets` 文件夹内创建一个同名的新文件夹`alist`。
3.  将为`alist`准备好的`docker-compose.yml`文件放入`presets/alist/`中。

    项目结构应如下所示：
    ```
    fishtools/
    ├── fishtools.sh
    ├── README.md
    └── presets/
        ├── homepage/
        │   └── docker-compose.yml
        └── ...
    ```

**第二步：修改 `fishtools.sh`**

1.  打开脚本，找到 `show_preset_deployment_menu` 函数。
2.  在菜单 `echo` 列表中增加一行，用于显示新项目。
3.  在 `case` 逻辑中增加对应的处理分支。

**第三步：提交更改**

将您所有的修改（包括新增的`presets`文件和改动的`fishtools.sh`）提交到GitHub。
```bash
git add .
git commit -m "feat: Add New-App to presets"
git push
```
完成！所有用户即可立即看到并部署您的新项目。

---

## 🤝 如何贡献

欢迎为本项目贡献代码或提出建议！

1.  **Fork** 本仓库
2.  创建您的功能分支 (`git checkout -b feature/AmazingFeature`)
3.  提交您的更改 (`git commit -m 'Add some AmazingFeature'`)
4.  推送至分支 (`git push origin feature/AmazingFeature`)
5.  提交一个 **Pull Request**

---

## 📄 许可证

本项目采用 MIT 许可证。
