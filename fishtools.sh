#!/bin/bash
set -eo pipefail

# =================================================================
# fishtools (咸鱼工具箱) v3.2
# Author: 咸鱼银河 (Xianyu Yinhe)
# Github: https://github.com/qqzhoufan/fishtools
#
# A powerful and modular toolkit for VPS management.
# =================================================================

# --- 全局配置 ---
AUTHOR_GITHUB_USER="qqzhoufan"
MAIN_REPO_NAME="fishtools"

# --- 基础组件 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}
log_success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}
log_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}
log_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}
press_any_key() {
    echo ""
    read -n 1 -s -r -p "按任意键返回主菜单..." </dev/tty
}

# --- 功能实现区 ---

# 功能 1.1: 显示机器静态信息
show_machine_info() {
    clear
    echo "================ 机器基本信息 ================"
    echo "CPU 型号: $(lscpu | grep 'Model name' | sed -E 's/.*Model name:\s*//')"
    echo "CPU 核心数: $(nproc)"
    echo "内存总量: $(free -m | awk 'NR==2{print $2}') MB"
    echo "系统架构: $(uname -m)"
    echo "操作系统: $(. /etc/os-release && echo $PRETTY_NAME)"
    echo "内核版本: $(uname -r)"
    echo "============================================="
}

# 功能 1.2: 显示VPS实时性能
show_live_performance() {
    clear
    echo "=============== VPS 实时性能状态 ==============="
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
    echo "CPU 使用率: $cpu_usage"

    local mem_info
    mem_info=$(free -m | awk 'NR==2{printf "总计: %s MB / 已用: %s MB / 剩余: %s MB", $2, $3, $4}')
    echo "内存使用情况: $mem_info"
    
    local disk_info
    disk_info=$(df -h / | awk 'NR==2{printf "总计: %s / 已用: %s (%s) / 剩余: %s", $2, $3, $5, $4}')
    echo "硬盘空间 (根目录): $disk_info"
    echo "============================================="
    echo "(此为快照信息，非持续刷新)"
}

# 子菜单：系统状态监控
show_status_menu() {
    while true; do
        clear
        echo "=========== 系统状态监控子菜单 ==========="
        echo "1. 显示VPS基本信息"
        echo "2. 显示VPS实时性能"
        echo "0. 返回主菜单"
        echo "=========================================="
        read -p "请输入您的选择 [0-2]: " status_choice </dev/tty

        case $status_choice in
            1)
                show_machine_info
                press_any_key
                ;;
            2)
                show_live_performance
                press_any_key
                ;;
            0)
                break
                ;;
            *)
                log_error "无效输入。"
                press_any_key
                ;;
        esac
    done
}

# 子菜单: 常用软件安装
show_install_menu() {
    while true; do
        clear
        echo "=========== 常用软件安装子菜单 ==========="
        echo "1. 安装 Docker 和 Docker Compose"
        echo "2. 安装 Nginx"
        echo "3. 安装 Caddy"
        echo "0. 返回主菜单"
        echo "=========================================="
        read -p "请输入您的选择 [0-3]: " install_choice </dev/tty

        case $install_choice in
            1)
                log_info "正在安装 Docker 和 Docker Compose..."
                if ! command -v docker &>/dev/null; then
                    curl -fsSL https://get.docker.com | bash
                    sudo usermod -aG docker "$USER"
                    log_success "Docker 安装成功。"
                else
                    log_success "Docker 已安装。"
                fi
                
                if ! docker compose version &>/dev/null; then
                    sudo apt-get update
                    sudo apt-get install -y docker-compose-plugin
                    log_success "Docker Compose 插件安装成功。"
                else
                    log_success "Docker Compose 已安装。"
                fi
                press_any_key
                ;;
            2)
                log_info "正在安装 Nginx..."
                sudo apt-get update && sudo apt-get install -y nginx
                log_success "Nginx 安装完成。"
                press_any_key
                ;;
            3)
                log_info "正在安装 Caddy..."
                sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https &>/dev/null
                curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
                curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
                sudo apt-get update && sudo apt-get install -y caddy
                log_success "Caddy 安装完成。"
                press_any_key
                ;;
            0)
                break
                ;;
            *)
                log_error "无效输入。"
                press_any_key
                ;;
        esac
    done
}

# 子菜单: 性能/网络测试脚本
show_test_menu() {
    while true; do
        clear
        echo "=========== 性能/网络测试子菜单 ==========="
        echo "1. Superbench 综合测试"
        echo "2. Lemonbench 综合测试"
        echo "0. 返回主菜单"
        echo "=========================================="
        read -p "请输入您的选择: " test_choice </dev/tty
        case $test_choice in
            1)
                log_warning "即将执行 Superbench..."
                curl -Lso- https://down.vpsaff.net/superbench/superbench.sh | bash
                press_any_key
                ;;
            2)
                log_warning "即将执行 Lemonbench..."
                curl -fsL https://ilemonra.in/LemonBenchIntl | bash -s fast
                press_any_key
                ;;
            0)
                break
                ;;
            *)
                log_error "无效输入。"
                press_any_key
                ;;
        esac
    done
}

# 子菜单: DD系统脚本
show_dd_menu() {
    while true; do
        clear
        echo "=========== DD系统重装子菜单 ==========="
        log_warning "DD系统风险极高，请谨慎操作！"
        echo "1. DD 为 Debian 11"
        echo "2. DD 为 Ubuntu 20.04"
        echo "0. 返回主菜单"
        echo "=========================================="
        read -p "请输入您的选择: " dd_choice </dev/tty
        case $dd_choice in
            1)
                log_error "功能待实现！"
                press_any_key
                ;;
            2)
                log_error "功能待实现！"
                press_any_key
                ;;
            0)
                break
                ;;
            *)
                log_error "无效输入。"
                press_any_key
                ;;
        esac
    done
}

# 子菜单: VPS优化
show_optimization_menu() {
    while true; do
        clear
        echo "=============== VPS 优化子菜单 ==============="
        echo "1. 开启BBR加速和TCP调优"
        echo "2. 添加/管理 SWAP 虚拟内存"
        echo "3. 安装/管理 WARP"
        echo "0. 返回主菜单"
        echo "=============================================="
        read -p "请输入您的选择 [0-3]: " opt_choice </dev/tty

        case $opt_choice in
            1)
                log_info "正在下载并执行 BBR/TCP 优化脚本..."
                if curl -sL http://sh.nekoneko.cloud/tools.sh -o tools.sh; then
                    bash tools.sh
                    rm -f tools.sh # 执行后清理
                else
                    log_error "下载脚本失败！"
                fi
                press_any_key
                ;;
            2)
                log_info "正在下载并执行 SWAP 管理脚本..."
                if curl -sL https://www.moerats.com/usr/shell/swap.sh -o swap.sh; then
                    bash swap.sh
                    rm -f swap.sh # 执行后清理
                else
                    log_error "下载脚本失败！"
                fi
                press_any_key
                ;;
            3)
                log_info "正在下载并执行 WARP 管理脚本..."
                log_warning "此脚本将接管交互，请根据其提示操作。"
                if curl -sL "https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh" -o menu.sh; then
                    bash menu.sh # 直接运行，让用户在脚本自带的菜单中选择
                    rm -f menu.sh # 执行后清理
                else
                    log_error "下载脚本失败！"
                fi
                press_any_key
                ;;
            0)
                break
                ;;
            *)
                log_error "无效输入。"
                press_any_key
                ;;
        esac
    done
}

# 核心功能：部署单个预设项目的逻辑
deploy_preset_project() {
    local project_name="$1"
    if [[ -z "$project_name" ]]; then
        log_error "内部错误。"
        return
    fi

    local project_dir="/opt/${project_name}"
    local dest_file="${project_dir}/docker-compose.yml"
    local url_yaml="https://raw.githubusercontent.com/${AUTHOR_GITHUB_USER}/${MAIN_REPO_NAME}/main/presets/${project_name}/docker-compose.yaml"
    local url_yml="https://raw.githubusercontent.com/${AUTHOR_GITHUB_USER}/${MAIN_REPO_NAME}/main/presets/${project_name}/docker-compose.yml"
    
    clear
    log_info "即将部署精选项目: ${project_name}"
    log_info "目标目录: ${project_dir}"
    echo ""

    if ! command -v docker &>/dev/null || ! docker compose version &>/dev/null; then
        log_error "Docker或Compose未安装。"
        return
    fi

    read -p "确认部署? (y/n): " confirm </dev/tty
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "操作已取消。"
        return
    fi

    log_info "正在创建项目目录..."
    sudo mkdir -p "$project_dir"
    log_info "正在下载配置文件..."

    if sudo curl -sLf -o "${dest_file}" "${url_yaml}"; then
        log_success "成功下载 docker-compose.yaml。"
    else
        log_warning "未找到 docker-compose.yaml，正在尝试 docker-compose.yml ..."
        if sudo curl -sLf -o "${dest_file}" "${url_yml}"; then
            log_success "成功下载 docker-compose.yml。"
        else
            log_error "下载失败！在 'presets/${project_name}/' 目录下，既未找到 .yaml 文件，也未找到 .yml 文件。"
            sudo rm -rf "$project_dir"
            return 1
        fi
    fi

    log_info "启动项目中..."
    cd "$project_dir" || return
    sudo docker compose up -d
    if [[ $? -eq 0 ]]; then
        log_success "项目 '$project_name' 已成功部署！"
    else
        log_error "项目部署失败！"
    fi
}

# 子菜单：显示预设项目
show_preset_deployment_menu() {
    while true; do
        clear
        echo "======== 一键部署精选项目 (by 咸鱼银河) ========"
        echo "1. Portainer-CE (Docker管理面板)"
        echo "2. Homepage (精美起始页)"
        echo "3. AdGuard-Home (去广告DNS)"
        echo "4. Nginx-Proxy-Manager (Nginx反代神器)"
        echo "----------------------------------------------"
        echo "0. 返回上一级菜单"
        echo "=============================================="
        read -p "请选择您要部署的项目: " preset_choice </dev/tty
        case $preset_choice in
            1) deploy_preset_project "portainer-ce" ;;
            2) deploy_preset_project "homepage" ;;
            3) deploy_preset_project "adguard-home" ;;
            4) deploy_preset_project "nginx-proxy-manager" ;;
            0) break ;;
            *) log_error "无效输入。"; press_any_key ;;
        esac
        if [[ "$preset_choice" -ne "0" ]]; then
            press_any_key
        fi
    done
}

# 子菜单：部署功能主菜单
show_deployment_menu() {
    while true; do
        clear
        echo "=========== Docker Compose 部署菜单 ==========="
        echo "1. 一键部署精选项目 (推荐)"
        echo "2. 从自定义GitHub仓库部署 (高级)"
        echo "0. 返回主菜单"
        echo "==========================================="
        read -p "请选择部署方式 [0-2]: " deploy_choice </dev/tty
        case $deploy_choice in
            1) show_preset_deployment_menu ;;
            2) log_error "功能占位，暂未实现。"; press_any_key ;;
            0) break ;;
            *) log_error "无效输入。"; press_any_key ;;
        esac
    done
}

# 主菜单和执行逻辑
main() {
    while true; do
        clear
        echo "================================================="
        echo "      欢迎使用 fishtools by 咸鱼银河 v3.2"
        echo "================================================="
        echo "1. 系统状态监控"
        echo "2. 性能/网络测试"
        echo "3. DD系统/重装系统"
        echo "4. 常用软件安装"
        echo "5. Docker Compose 项目部署"
        echo "6. VPS 优化"
        echo "0. 退出脚本"
        echo "-------------------------------------------------"
        read -p "请输入您的选择 [0-6]: " main_choice </dev/tty

        case $main_choice in
            1)
                show_status_menu
                ;;
            2)
                show_test_menu
                ;;
            3)
                show_dd_menu
                ;;
            4)
                show_install_menu
                ;;
            5)
                show_deployment_menu
                ;;
            6)
                show_optimization_menu
                ;;
            0)
                echo "感谢使用，再见!"
                exit 0
                ;;
            *)
                log_error "无效输入，请重新选择。"
                press_any_key
                ;;
        esac
    done
}

# 脚本启动入口
main