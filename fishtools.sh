#!/bin/bash
set -eo pipefail

# =================================================================
# fishtools (咸鱼工具箱) v1.0
# Author: 咸鱼银河 (Xianyu Yinhe)
# Github: https://github.com/qqzhoufan/fishtools
#
# A powerful and modular toolkit for VPS management.
# =================================================================

# --- 全局配置 ---
AUTHOR_GITHUB_USER="qqzhoufan"
MAIN_REPO_NAME="fishtools"
VERSION="v1.0"

# --- 颜色和样式定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# --- Unicode 边框字符 ---
# 使用简单的 ASCII 字符以确保兼容性
LINE_H="─"
LINE_V="│"
CORNER_TL="┌"
CORNER_TR="┐"
CORNER_BL="└"
CORNER_BR="┘"
T_LEFT="├"
T_RIGHT="┤"

# --- 基础日志函数 ---
log_info() {
    echo -e "${CYAN}  ℹ ${NC}$1"
}
log_success() {
    echo -e "${GREEN}  ✓ ${NC}$1"
}
log_warning() {
    echo -e "${YELLOW}  ⚠ ${NC}$1"
}
log_error() {
    echo -e "${RED}  ✗ ${NC}$1"
}

# --- 绘制工具函数 ---
# 绘制水平线
draw_line() {
    local width=${1:-50}
    local color=${2:-$CYAN}
    local line=""
    for ((i=0; i<width; i++)); do
        line+="$LINE_H"
    done
    echo -e "${color}${line}${NC}"
}

# 绘制带文字的标题行
draw_title_line() {
    local text="$1"
    local width=${2:-50}
    local color=${3:-$CYAN}
    local text_len=${#text}
    local padding=$(( (width - text_len - 4) / 2 ))
    local left_pad=""
    local right_pad=""
    for ((i=0; i<padding; i++)); do
        left_pad+="$LINE_H"
        right_pad+="$LINE_H"
    done
    # 处理奇数长度
    local extra=$(( (width - text_len - 4) % 2 ))
    for ((i=0; i<extra; i++)); do
        right_pad+="$LINE_H"
    done
    echo -e "${color}${CORNER_TL}${left_pad}${NC} ${WHITE}${BOLD}${text}${NC} ${color}${right_pad}${CORNER_TR}${NC}"
}

# 绘制菜单项
draw_menu_item() {
    local num="$1"
    local icon="$2"
    local text="$3"
    echo -e "  ${CYAN}${BOLD}${num}.${NC} ${icon}  ${WHITE}${text}${NC}"
}

# 绘制分隔线
draw_separator() {
    local width=${1:-50}
    local line=""
    for ((i=0; i<width; i++)); do
        line+="$LINE_H"
    done
    echo -e "${GRAY}${T_LEFT}${line}${T_RIGHT}${NC}"
}

# 绘制底部边框
draw_footer() {
    local width=${1:-50}
    local line=""
    for ((i=0; i<width; i++)); do
        line+="$LINE_H"
    done
    echo -e "${CYAN}${CORNER_BL}${line}${CORNER_BR}${NC}"
}

press_any_key() {
    echo ""
    echo -e "${DIM}按任意键返回菜单...${NC}"
    read -n 1 -s -r </dev/tty
}

# --- ASCII Art Logo ---
show_logo() {
    echo -e "${CYAN}"
    cat << 'EOF'
    _____ _     _   _____           _     
   |  ___(_)___| |_|_   _|__   ___ | |___ 
   | |_  | / __| '_ \| |/ _ \ / _ \| / __|
   |  _| | \__ \ | | | | (_) | (_) | \__ \
   |_|   |_|___/_| |_|_|\___/ \___/|_|___/
                                          
EOF
    echo -e "${NC}"
    echo -e "${GRAY}           咸鱼工具箱 ${VERSION} by 咸鱼银河${NC}"
    echo -e "${GRAY}        https://github.com/${AUTHOR_GITHUB_USER}/${MAIN_REPO_NAME}${NC}"
    echo ""
}

# --- 功能实现区 ---

# 子菜单：系统状态监控
show_status_menu() {
    while true; do
        clear
        draw_title_line "系统状态监控" 50
        echo ""
        draw_menu_item "1" "📊" "显示 VPS 基本信息"
        draw_menu_item "2" "📈" "显示 VPS 实时性能"
        draw_menu_item "3" "🌐" "网络流量监控"
        draw_menu_item "4" "⚙️" "进程管理"
        draw_menu_item "5" "🔌" "端口查看"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回主菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-5]: )" status_choice </dev/tty

        case $status_choice in
            1)
                show_machine_info
                press_any_key
                ;;
            2)
                show_live_performance
                press_any_key
                ;;
            3)
                show_network_traffic
                press_any_key
                ;;
            4)
                show_process_manager
                ;;
            5)
                show_open_ports
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

show_machine_info() {
    clear
    draw_title_line "VPS 基本信息" 50
    echo ""
    echo -e "  ${CYAN}CPU 型号${NC}    │ $(lscpu | grep 'Model name' | sed -E 's/.*Model name:\s*//')"
    echo -e "  ${CYAN}CPU 核心${NC}    │ $(nproc) 核"
    echo -e "  ${CYAN}内存总量${NC}    │ $(free -m | awk 'NR==2{print $2}') MB"
    echo -e "  ${CYAN}系统架构${NC}    │ $(uname -m)"
    echo -e "  ${CYAN}操作系统${NC}    │ $(. /etc/os-release && echo $PRETTY_NAME)"
    echo -e "  ${CYAN}内核版本${NC}    │ $(uname -r)"
    echo ""
    draw_footer 50
}

show_live_performance() {
    clear
    draw_title_line "VPS 实时性能" 50
    echo ""
    
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    
    # CPU 使用率颜色
    local cpu_color=$GREEN
    if (( $(echo "$cpu_usage > 70" | bc -l) )); then
        cpu_color=$RED
    elif (( $(echo "$cpu_usage > 40" | bc -l) )); then
        cpu_color=$YELLOW
    fi
    echo -e "  ${CYAN}CPU 使用率${NC}  │ ${cpu_color}${cpu_usage}%${NC}"

    local mem_total=$(free -m | awk 'NR==2{print $2}')
    local mem_used=$(free -m | awk 'NR==2{print $3}')
    local mem_free=$(free -m | awk 'NR==2{print $4}')
    local mem_percent=$((mem_used * 100 / mem_total))
    
    # 内存使用率颜色
    local mem_color=$GREEN
    if (( mem_percent > 80 )); then
        mem_color=$RED
    elif (( mem_percent > 50 )); then
        mem_color=$YELLOW
    fi
    echo -e "  ${CYAN}内存使用${NC}    │ ${mem_color}${mem_used}MB${NC} / ${mem_total}MB (${mem_color}${mem_percent}%${NC})"
    
    local disk_info=$(df -h / | awk 'NR==2{printf "%s / %s (%s)", $3, $2, $5}')
    local disk_percent=$(df -h / | awk 'NR==2{print $5}' | tr -d '%')
    
    # 磁盘使用率颜色
    local disk_color=$GREEN
    if (( disk_percent > 80 )); then
        disk_color=$RED
    elif (( disk_percent > 60 )); then
        disk_color=$YELLOW
    fi
    echo -e "  ${CYAN}磁盘空间${NC}    │ ${disk_color}${disk_info}${NC}"
    
    echo ""
    echo -e "  ${DIM}(此为快照信息，非持续刷新)${NC}"
    echo ""
    draw_footer 50
}

# 网络流量监控
show_network_traffic() {
    clear
    draw_title_line "网络流量监控" 50
    echo ""
    log_info "正在监控网络流量（5秒采样）..."
    echo ""
    
    # 获取主要网卡名称
    local interface=$(ip route | grep default | awk '{print $5}' | head -1)
    if [[ -z "$interface" ]]; then
        interface="eth0"
    fi
    
    # 第一次采样
    local rx1=$(cat /proc/net/dev | grep "$interface" | awk '{print $2}')
    local tx1=$(cat /proc/net/dev | grep "$interface" | awk '{print $10}')
    
    sleep 5
    
    # 第二次采样
    local rx2=$(cat /proc/net/dev | grep "$interface" | awk '{print $2}')
    local tx2=$(cat /proc/net/dev | grep "$interface" | awk '{print $10}')
    
    # 计算速率 (bytes/s -> KB/s)
    local rx_rate=$(( (rx2 - rx1) / 5 / 1024 ))
    local tx_rate=$(( (tx2 - tx1) / 5 / 1024 ))
    
    # 计算总流量
    local rx_total=$(echo "scale=2; $rx2 / 1024 / 1024 / 1024" | bc)
    local tx_total=$(echo "scale=2; $tx2 / 1024 / 1024 / 1024" | bc)
    
    echo -e "  ${CYAN}网卡名称${NC}      │ ${WHITE}$interface${NC}"
    echo -e "  ${CYAN}下载速度${NC}      │ ${GREEN}↓ ${rx_rate} KB/s${NC}"
    echo -e "  ${CYAN}上传速度${NC}      │ ${YELLOW}↑ ${tx_rate} KB/s${NC}"
    echo -e "  ${CYAN}累计下载${NC}      │ ${rx_total} GB"
    echo -e "  ${CYAN}累计上传${NC}      │ ${tx_total} GB"
    echo ""
    draw_footer 50
}

# 进程管理
show_process_manager() {
    while true; do
        clear
        draw_title_line "进程管理" 50
        echo ""
        
        # 显示CPU占用前10的进程
        echo -e "  ${WHITE}${BOLD}CPU 占用 TOP 10${NC}"
        echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
        echo -e "  ${CYAN}PID      CPU%   MEM%   命令${NC}"
        ps aux --sort=-%cpu | head -11 | tail -10 | awk '{printf "  %-8s %-6s %-6s %s\n", $2, $3, $4, $11}'
        
        echo ""
        echo -e "  ${WHITE}${BOLD}内存 占用 TOP 10${NC}"
        echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
        echo -e "  ${CYAN}PID      CPU%   MEM%   命令${NC}"
        ps aux --sort=-%mem | head -11 | tail -10 | awk '{printf "  %-8s %-6s %-6s %s\n", $2, $3, $4, $11}'
        
        echo ""
        draw_separator 50
        echo -e "  ${YELLOW}输入 PID 杀死进程，或输入 0 返回${NC}"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入${NC}): " pid_input </dev/tty
        
        if [[ "$pid_input" == "0" ]]; then
            break
        elif [[ "$pid_input" =~ ^[0-9]+$ ]]; then
            read -p "确认杀死进程 $pid_input? (y/n): " confirm </dev/tty
            if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                if kill -9 "$pid_input" 2>/dev/null; then
                    log_success "进程 $pid_input 已终止"
                else
                    log_error "无法终止进程 $pid_input（可能需要 sudo 权限）"
                fi
                press_any_key
            fi
        fi
    done
}

# 端口查看
show_open_ports() {
    clear
    draw_title_line "开放端口查看" 50
    echo ""
    
    echo -e "  ${WHITE}${BOLD}TCP 监听端口${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    echo -e "  ${CYAN}端口       状态       进程${NC}"
    
    if command -v ss &>/dev/null; then
        ss -tlnp 2>/dev/null | grep LISTEN | awk '{
            split($4, a, ":")
            port = a[length(a)]
            proc = $6
            gsub(/users:\(\("/, "", proc)
            gsub(/".*/, "", proc)
            if (proc == "") proc = "-"
            printf "  %-10s %-10s %s\n", port, "LISTEN", proc
        }' | sort -t' ' -k1 -n | uniq
    else
        netstat -tlnp 2>/dev/null | grep LISTEN | awk '{
            split($4, a, ":")
            port = a[length(a)]
            proc = $7
            printf "  %-10s %-10s %s\n", port, "LISTEN", proc
        }' | sort -t' ' -k1 -n | uniq
    fi
    
    echo ""
    echo -e "  ${WHITE}${BOLD}UDP 监听端口${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    
    if command -v ss &>/dev/null; then
        ss -ulnp 2>/dev/null | grep -v "State" | awk '{
            split($4, a, ":")
            port = a[length(a)]
            proc = $6
            gsub(/users:\(\("/, "", proc)
            gsub(/".*/, "", proc)
            if (proc == "") proc = "-"
            if (port != "*") printf "  %-10s %-10s %s\n", port, "UDP", proc
        }' | sort -t' ' -k1 -n | uniq
    else
        netstat -ulnp 2>/dev/null | awk '{
            split($4, a, ":")
            port = a[length(a)]
            proc = $6
            if (NR > 2) printf "  %-10s %-10s %s\n", port, "UDP", proc
        }' | sort -t' ' -k1 -n | uniq
    fi
    
    echo ""
    draw_footer 50
}

# 子菜单: 常用软件安装
show_install_menu() {
    while true; do
        clear
        draw_title_line "常用软件安装" 50
        echo ""
        draw_menu_item "1" "🐳" "安装 Docker 和 Docker Compose"
        draw_menu_item "2" "🌐" "安装 Nginx"
        draw_menu_item "3" "🔒" "安装 Caddy"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回主菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-3]: )" install_choice </dev/tty

        case $install_choice in
            1)
                clear
                draw_title_line "安装 Docker" 50
                echo ""
                log_info "正在安装 Docker 和 Docker Compose..."
                if ! command -v docker &>/dev/null; then
                    curl -fsSL https://get.docker.com | bash
                    sudo usermod -aG docker "$USER"
                    log_success "Docker 安装成功。"
                else
                    log_success "Docker 已安装。"
                fi
                if ! docker compose version &>/dev/null; then
                    sudo apt-get update && sudo apt-get install -y docker-compose-plugin
                    log_success "Docker Compose 插件安装成功。"
                else
                    log_success "Docker Compose 已安装。"
                fi
                echo ""
                draw_footer 50
                press_any_key
                ;;
            2)
                clear
                draw_title_line "安装 Nginx" 50
                echo ""
                log_info "正在安装 Nginx..."
                sudo apt-get update && sudo apt-get install -y nginx
                log_success "Nginx 安装完成。"
                echo ""
                draw_footer 50
                press_any_key
                ;;
            3)
                clear
                draw_title_line "安装 Caddy" 50
                echo ""
                log_info "正在安装 Caddy..."
                sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https &>/dev/null
                curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
                curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
                sudo apt-get update && sudo apt-get install -y caddy
                log_success "Caddy 安装完成。"
                echo ""
                draw_footer 50
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
        draw_title_line "性能/网络测试" 50
        echo ""
        draw_menu_item "1" "🚀" "融合怪 (ecs.sh) 综合测试"
        draw_menu_item "2" "🔍" "IP 质量检测"
        draw_menu_item "3" "📺" "流媒体解锁测试"
        draw_menu_item "4" "🛤️" "回程路由测试"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回主菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-4]: )" test_choice </dev/tty
        case $test_choice in
            1)
                clear
                draw_title_line "融合怪测试" 50
                echo ""
                log_info "开始运行 融合怪 (ecs.sh) 测试脚本..."
                log_info "尝试从主链接 (gitlab) 下载..."
                if curl -L https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh -o ecs.sh; then
                    log_success "主链接下载成功。"
                    chmod +x ecs.sh && bash ecs.sh
                else
                    log_warning "主链接下载失败，尝试从备用链接 (github) 下载..."
                    if curl -L https://github.com/spiritLHLS/ecs/raw/main/ecs.sh -o ecs.sh; then
                        log_success "备用链接下载成功。"
                        chmod +x ecs.sh && bash ecs.sh
                    else
                        log_error "主链接和备用链接均下载失败！"
                    fi
                fi
                rm -f ecs.sh
                press_any_key
                ;;
            2)
                clear
                draw_title_line "IP 质量检测" 50
                echo ""
                log_info "正在运行 IP 质量检测脚本..."
                if bash <(curl -sL https://bash.ip.check.place); then
                    : # 脚本执行成功
                else
                    log_error "脚本执行失败！"
                fi
                press_any_key
                ;;
            3)
                clear
                draw_title_line "流媒体解锁测试" 50
                echo ""
                log_info "正在运行流媒体解锁检测脚本..."
                log_info "此脚本将检测 Netflix、Disney+、YouTube Premium 等平台的解锁状态"
                echo ""
                if bash <(curl -sL https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/check.sh); then
                    : # 脚本执行成功
                else
                    log_warning "主链接失败，尝试备用链接..."
                    bash <(curl -sL https://cdn.jsdelivr.net/gh/lmc999/RegionRestrictionCheck@main/check.sh) || log_error "脚本执行失败！"
                fi
                press_any_key
                ;;
            4)
                clear
                draw_title_line "回程路由测试" 50
                echo ""
                log_info "正在运行回程路由测试脚本..."
                log_info "此脚本将检测到中国各地区的回程路由线路"
                echo ""
                if curl -sL https://raw.githubusercontent.com/zhanghanyun/backtrace/main/install.sh -o backtrace.sh; then
                    chmod +x backtrace.sh && bash backtrace.sh
                    rm -f backtrace.sh
                else
                    log_error "脚本下载失败！"
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

# 子菜单: DD系统脚本
show_dd_menu() {
    while true; do
        clear
        draw_title_line "DD系统/重装系统" 50
        echo ""
        echo -e "  ${RED}${BOLD}⚠ 警告：DD系统风险极高，会清空磁盘！${NC}"
        echo ""
        draw_menu_item "1" "💿" "reinstall (通用系统重装)"
        draw_menu_item "2" "🐣" "LXD小鸡DD (NS酒神脚本)"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回主菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC}): " dd_choice </dev/tty
        case $dd_choice in
            1)
                clear
                draw_title_line "reinstall 系统重装" 50
                echo ""
                log_warning "您选择了 reinstall 通用系统重装，这是高风险操作！"
                read -p "请务必确认！输入 'yes' 继续执行: " confirm </dev/tty
                if [[ "$confirm" != "yes" ]]; then
                    log_info "操作已取消。"
                    press_any_key
                    continue
                fi
                
                log_info "尝试从主链接 (github) 下载 reinstall.sh..."
                if curl -L -o reinstall.sh https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh; then
                    log_success "主链接下载成功。"
                else
                    log_warning "主链接下载失败，尝试从备用链接 (cnb.cool) 下载..."
                    if ! curl -L -o reinstall.sh https://cnb.cool/bin456789/reinstall/-/git/raw/main/reinstall.sh; then
                         log_error "主链接和备用链接均下载失败！"
                         rm -f reinstall.sh
                         press_any_key
                         continue
                    fi
                    log_success "备用链接下载成功。"
                fi
                log_warning "脚本已下载，即将执行。请根据后续脚本提示操作！"
                press_any_key
                bash reinstall.sh
                rm -f reinstall.sh
                ;;
            2)
                clear
                draw_title_line "LXD小鸡DD" 50
                echo ""
                log_warning "您选择了 LXD小鸡DD，这是高风险操作！"
                read -p "请务必确认！输入 'yes' 继续执行: " confirm </dev/tty
                if [[ "$confirm" != "yes" ]]; then
                    log_info "操作已取消。"
                    press_any_key
                    continue
                fi

                log_info "尝试从主链接 (github) 下载 OsMutation.sh..."
                if curl -sL -o OsMutation.sh https://raw.githubusercontent.com/LloydAsp/OsMutation/main/OsMutation.sh; then
                    log_success "脚本下载成功。"
                    log_warning "脚本已下载，即将执行。请根据后续脚本提示操作！"
                    press_any_key
                    chmod u+x OsMutation.sh && ./OsMutation.sh
                    rm -f OsMutation.sh
                else
                    log_error "脚本下载失败！"
                    press_any_key
                fi
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
        draw_title_line "VPS 优化" 50
        echo ""
        draw_menu_item "1" "⚡" "开启 BBR 加速和 TCP 调优"
        draw_menu_item "2" "💾" "添加/管理 SWAP 虚拟内存"
        draw_menu_item "3" "🌍" "安装/管理 WARP"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回主菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-3]: )" opt_choice </dev/tty

        case $opt_choice in
            1)
                clear
                draw_title_line "BBR/TCP 优化" 50
                echo ""
                log_info "正在下载并执行 BBR/TCP 优化脚本..."
                if curl -sL http://sh.nekoneko.cloud/tools.sh -o tools.sh; then
                    bash tools.sh
                    rm -f tools.sh
                else
                    log_error "下载脚本失败！"
                fi
                press_any_key
                ;;
            2)
                clear
                draw_title_line "SWAP 管理" 50
                echo ""
                log_info "正在下载并执行 SWAP 管理脚本..."
                if curl -sL https://www.moerats.com/usr/shell/swap.sh -o swap.sh; then
                    bash swap.sh
                    rm -f swap.sh
                else
                    log_error "下载脚本失败！"
                fi
                press_any_key
                ;;
            3)
                clear
                draw_title_line "WARP 管理" 50
                echo ""
                log_info "正在下载并执行 WARP 管理脚本..."
                log_warning "此脚本将接管交互，请根据其提示操作。"
                if curl -sL "https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh" -o menu.sh; then
                    bash menu.sh
                    rm -f menu.sh
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
    if [[ -z "$project_name" ]]; then log_error "内部错误。"; return 1; fi
    local project_dir="/opt/${project_name}"; local dest_file="${project_dir}/docker-compose.yml"
    local url_yaml="https://raw.githubusercontent.com/${AUTHOR_GITHUB_USER}/${MAIN_REPO_NAME}/main/presets/${project_name}/docker-compose.yaml"
    local url_yml="https://raw.githubusercontent.com/${AUTHOR_GITHUB_USER}/${MAIN_REPO_NAME}/main/presets/${project_name}/docker-compose.yml"
    
    clear
    draw_title_line "部署 ${project_name}" 50
    echo ""
    log_info "即将部署精选项目: ${project_name}"
    log_info "目标目录: ${project_dir}"
    echo ""
    
    if ! command -v docker &>/dev/null || ! docker compose version &>/dev/null; then 
        log_error "Docker或Compose未安装。"
        return 1
    fi
    
    read -p "确认部署? (y/n): " confirm </dev/tty
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then 
        log_info "操作已取消。"
        return 0
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
    cd "$project_dir" || return 1
    sudo docker compose up -d
    if [[ $? -eq 0 ]]; then 
        log_success "项目 '$project_name' 已成功部署！"
    else 
        log_error "项目部署失败！"
        return 1
    fi
}

# 新增功能：安装后提示信息
show_post_install_message() {
    local project_name="$1"
    echo ""
    case $project_name in
        "qbittorrent")
            echo -e "  ${YELLOW}╭───────────────────────────────────────╮${NC}"
            echo -e "  ${YELLOW}│${NC}  ${WHITE}${BOLD}qBittorrent 默认登录信息${NC}            ${YELLOW}│${NC}"
            echo -e "  ${YELLOW}├───────────────────────────────────────┤${NC}"
            echo -e "  ${YELLOW}│${NC}  用户名: ${CYAN}admin${NC}                      ${YELLOW}│${NC}"
            echo -e "  ${YELLOW}│${NC}  查看密码: ${CYAN}sudo docker logs qbittorrent${NC}${YELLOW}│${NC}"
            echo -e "  ${YELLOW}╰───────────────────────────────────────╯${NC}"
            ;;
        "moontv")
            echo -e "  ${YELLOW}╭───────────────────────────────────────╮${NC}"
            echo -e "  ${YELLOW}│${NC}  ${WHITE}${BOLD}MoonTV 默认登录信息${NC}                 ${YELLOW}│${NC}"
            echo -e "  ${YELLOW}├───────────────────────────────────────┤${NC}"
            echo -e "  ${YELLOW}│${NC}  用户名: ${CYAN}admin${NC}                      ${YELLOW}│${NC}"
            echo -e "  ${YELLOW}│${NC}  密  码: ${CYAN}admin_password${NC}             ${YELLOW}│${NC}"
            echo -e "  ${YELLOW}╰───────────────────────────────────────╯${NC}"
            ;;
        "nginx-proxy-manager")
            echo -e "  ${YELLOW}╭───────────────────────────────────────╮${NC}"
            echo -e "  ${YELLOW}│${NC}  ${WHITE}${BOLD}Nginx Proxy Manager 默认登录信息${NC}    ${YELLOW}│${NC}"
            echo -e "  ${YELLOW}├───────────────────────────────────────┤${NC}"
            echo -e "  ${YELLOW}│${NC}  邮  箱: ${CYAN}admin@example.com${NC}          ${YELLOW}│${NC}"
            echo -e "  ${YELLOW}│${NC}  密  码: ${CYAN}changeme${NC}                   ${YELLOW}│${NC}"
            echo -e "  ${YELLOW}│${NC}  ${RED}首次登录后请立即修改！${NC}              ${YELLOW}│${NC}"
            echo -e "  ${YELLOW}╰───────────────────────────────────────╯${NC}"
            ;;
        *)
            # 其他项目没有特殊提示
            ;;
    esac
}

# 子菜单：显示预设项目
show_preset_deployment_menu() {
    while true; do
        clear
        draw_title_line "一键部署精选项目" 50
        echo -e "  ${DIM}by 咸鱼银河${NC}"
        echo ""
        draw_menu_item "1" "🏠" "Homepage (精美起始页)"
        draw_menu_item "2" "🔀" "Nginx-Proxy-Manager (反代神器)"
        draw_menu_item "3" "🎵" "Navidrome (音乐服务器)"
        draw_menu_item "4" "📥" "qBittorrent (下载器)"
        draw_menu_item "5" "📺" "MoonTV (观影聚合)"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回上一级菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请选择要部署的项目${NC} [0-5]: )" preset_choice </dev/tty
        
        local project_to_deploy=""
        case $preset_choice in
            1) project_to_deploy="homepage" ;;
            2) project_to_deploy="nginx-proxy-manager" ;;
            3) project_to_deploy="navidrome" ;;
            4) project_to_deploy="qbittorrent" ;;
            5) project_to_deploy="moontv" ;;
            0) break ;;
            *) log_error "无效输入。"; press_any_key; continue ;;
        esac

        if [[ -n "$project_to_deploy" ]]; then
            deploy_preset_project "$project_to_deploy"
            show_post_install_message "$project_to_deploy"
            press_any_key
        fi
    done
}

# 子菜单：部署功能主菜单
show_deployment_menu() {
    while true; do
        clear
        draw_title_line "Docker Compose 部署" 50
        echo ""
        draw_menu_item "1" "⭐" "一键部署精选项目 (推荐)"
        draw_menu_item "2" "🔧" "从自定义 GitHub 仓库部署 (高级)"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回主菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请选择部署方式${NC} [0-2]: )" deploy_choice </dev/tty
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
        show_logo
        draw_title_line "主菜单" 50
        echo ""
        draw_menu_item "1" "💻" "系统状态监控"
        draw_menu_item "2" "🚀" "性能/网络测试"
        draw_menu_item "3" "💿" "DD系统/重装系统"
        draw_menu_item "4" "📦" "常用软件安装"
        draw_menu_item "5" "🐳" "Docker Compose 项目部署"
        draw_menu_item "6" "⚡" "VPS 优化"
        echo ""
        draw_separator 50
        draw_menu_item "0" "👋" "退出脚本"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-6]: )" main_choice </dev/tty

        case $main_choice in
            1) show_status_menu ;;
            2) show_test_menu ;;
            3) show_dd_menu ;;
            4) show_install_menu ;;
            5) show_deployment_menu ;;
            6) show_optimization_menu ;;
            0) 
                echo ""
                echo -e "  ${CYAN}感谢使用 fishtools，再见！${NC} 👋"
                echo ""
                exit 0 
                ;;
            *) log_error "无效输入，请重新选择。"; press_any_key ;;
        esac
    done
}

# 脚本启动入口
main