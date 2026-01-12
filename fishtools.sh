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
VERSION="v1.1"

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

# 网络流量监控（实时刷新）
show_network_traffic() {
    # 获取所有活动网卡（排除 lo）
    local interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | tr '\n' ' ')
    
    # 如果没有找到网卡，使用默认的 eth0
    if [[ -z "$interfaces" ]]; then
        interfaces="eth0"
    fi
    
    # 获取默认网关所在的网卡（公网网卡）
    local default_iface=$(ip route | grep default | awk '{print $5}' | head -1)
    
    # 初始化上一次的采样数据
    declare -A rx_prev tx_prev
    for iface in $interfaces; do
        rx_prev[$iface]=$(cat /proc/net/dev 2>/dev/null | grep -w "$iface" | awk '{print $2}')
        tx_prev[$iface]=$(cat /proc/net/dev 2>/dev/null | grep -w "$iface" | awk '{print $10}')
    done
    
    # 实时刷新循环
    while true; do
        clear
        draw_title_line "网络流量监控 (实时)" 50
        echo ""
        echo -e "  ${WHITE}${BOLD}网卡流量统计${NC}  ${DIM}(每2秒刷新，按 q 退出)${NC}"
        echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
        
        for iface in $interfaces; do
            # 获取当前数据
            local rx_curr=$(cat /proc/net/dev 2>/dev/null | grep -w "$iface" | awk '{print $2}')
            local tx_curr=$(cat /proc/net/dev 2>/dev/null | grep -w "$iface" | awk '{print $10}')
            
            # 跳过无效数据
            if [[ -z "$rx_curr" || -z "$tx_curr" || "$rx_curr" == "0" ]]; then
                continue
            fi
            
            # 获取上次数据
            local rx_last=${rx_prev[$iface]:-$rx_curr}
            local tx_last=${tx_prev[$iface]:-$tx_curr}
            
            # 计算速率 (bytes/2s -> KB/s)
            local rx_diff=$((rx_curr - rx_last))
            local tx_diff=$((tx_curr - tx_last))
            local rx_rate=$((rx_diff / 2 / 1024))
            local tx_rate=$((tx_diff / 2 / 1024))
            
            # 更新上次数据
            rx_prev[$iface]=$rx_curr
            tx_prev[$iface]=$tx_curr
            
            # 计算总流量 (使用 awk 进行浮点运算)
            local rx_total=$(awk "BEGIN {printf \"%.2f\", $rx_curr / 1024 / 1024 / 1024}")
            local tx_total=$(awk "BEGIN {printf \"%.2f\", $tx_curr / 1024 / 1024 / 1024}")
            
            # 判断是公网还是内网网卡
            local iface_type=""
            if [[ "$iface" == "$default_iface" ]]; then
                iface_type="${MAGENTA}[公网]${NC}"
            else
                iface_type="${GRAY}[内网]${NC}"
            fi
            
            # 速率单位自动调整
            local rx_display tx_display
            if [[ $rx_rate -ge 1024 ]]; then
                rx_display=$(awk "BEGIN {printf \"%.2f MB/s\", $rx_rate / 1024}")
            else
                rx_display="${rx_rate} KB/s"
            fi
            if [[ $tx_rate -ge 1024 ]]; then
                tx_display=$(awk "BEGIN {printf \"%.2f MB/s\", $tx_rate / 1024}")
            else
                tx_display="${tx_rate} KB/s"
            fi
            
            echo ""
            echo -e "  ${CYAN}${BOLD}$iface${NC} $iface_type"
            echo -e "    ${GREEN}↓ 下载${NC}  ${rx_display}  │  累计 ${rx_total} GB"
            echo -e "    ${YELLOW}↑ 上传${NC}  ${tx_display}  │  累计 ${tx_total} GB"
        done
        
        echo ""
        draw_footer 50
        
        # 等待2秒，期间检测是否按下 q 键退出
        read -t 2 -n 1 key </dev/tty 2>/dev/null || true
        if [[ "$key" == "q" || "$key" == "Q" ]]; then
            break
        fi
    done
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
        }' | sort -t' ' -k1 -n | uniq || true
    else
        netstat -tlnp 2>/dev/null | grep LISTEN | awk '{
            split($4, a, ":")
            port = a[length(a)]
            proc = $7
            printf "  %-10s %-10s %s\n", port, "LISTEN", proc
        }' | sort -t' ' -k1 -n | uniq || true
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
        }' | sort -t' ' -k1 -n | uniq || true
    else
        netstat -ulnp 2>/dev/null | awk '{
            split($4, a, ":")
            port = a[length(a)]
            proc = $6
            if (NR > 2) printf "  %-10s %-10s %s\n", port, "UDP", proc
        }' | sort -t' ' -k1 -n | uniq || true
    fi
    
    echo ""
    draw_footer 50
}

# ================== Docker 安装子菜单 ==================
install_docker_menu() {
    while true; do
        clear
        draw_title_line "Docker 安装" 50
        echo ""
        
        # 显示当前安装状态
        if command -v docker &>/dev/null; then
            local docker_ver=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')
            echo -e "  ${GREEN}✓${NC} Docker 已安装 (${docker_ver})"
        else
            echo -e "  ${GRAY}○${NC} Docker 未安装"
        fi
        
        if docker compose version &>/dev/null 2>&1; then
            local compose_ver=$(docker compose version 2>/dev/null | awk '{print $4}')
            echo -e "  ${GREEN}✓${NC} Docker Compose 已安装 (${compose_ver})"
        else
            echo -e "  ${GRAY}○${NC} Docker Compose 未安装"
        fi
        echo ""
        
        draw_menu_item "1" "🌍" "使用官方源安装 (国外服务器推荐)"
        draw_menu_item "2" "🇨🇳" "使用阿里云源安装 (国内服务器推荐)"
        draw_menu_item "3" "🗑️" "卸载 Docker"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回上级菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-3]: )" docker_choice </dev/tty
        
        case $docker_choice in
            1)
                clear
                draw_title_line "使用官方源安装 Docker" 50
                echo ""
                if command -v docker &>/dev/null; then
                    log_warning "Docker 已安装，是否重新安装？"
                    read -p "输入 y 继续，其他键取消: " confirm </dev/tty
                    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && continue
                fi
                log_info "正在从 Docker 官方源安装..."
                curl -fsSL https://get.docker.com | bash
                sudo usermod -aG docker "$USER" 2>/dev/null || true
                echo ""
                log_success "Docker 安装完成！"
                docker --version
                docker compose version 2>/dev/null || true
                echo ""
                echo -e "  ${YELLOW}提示: 如需使用当前用户运行 Docker，请重新登录终端${NC}"
                press_any_key
                ;;
            2)
                clear
                draw_title_line "使用阿里云源安装 Docker" 50
                echo ""
                if command -v docker &>/dev/null; then
                    log_warning "Docker 已安装，是否重新安装？"
                    read -p "输入 y 继续，其他键取消: " confirm </dev/tty
                    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && continue
                fi
                log_info "正在从阿里云源安装..."
                curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
                sudo usermod -aG docker "$USER" 2>/dev/null || true
                echo ""
                log_success "Docker 安装完成！"
                docker --version
                docker compose version 2>/dev/null || true
                echo ""
                echo -e "  ${YELLOW}提示: 如需使用当前用户运行 Docker，请重新登录终端${NC}"
                press_any_key
                ;;
            3)
                clear
                draw_title_line "卸载 Docker" 50
                echo ""
                if ! command -v docker &>/dev/null; then
                    log_warning "Docker 未安装，无需卸载。"
                    press_any_key
                    continue
                fi
                echo -e "  ${RED}${BOLD}⚠ 警告：此操作将完全删除 Docker！${NC}"
                echo ""
                echo -e "  将会删除以下内容："
                echo -e "    • Docker 引擎和 CLI"
                echo -e "    • Docker Compose 插件"
                echo -e "    • 所有容器、镜像、卷、网络"
                echo ""
                read -p "请输入 'yes' 确认卸载: " confirm </dev/tty
                if [[ "$confirm" != "yes" ]]; then
                    log_info "操作已取消。"
                    press_any_key
                    continue
                fi
                log_info "正在停止所有容器..."
                sudo docker stop $(docker ps -aq) 2>/dev/null || true
                sudo docker rm $(docker ps -aq) 2>/dev/null || true
                log_info "正在卸载 Docker..."
                # 卸载所有可能的 Docker 相关包
                sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker.io docker-compose docker-doc podman-docker 2>/dev/null || true
                sudo apt-get autoremove -y --purge
                log_info "正在清理 Docker 数据..."
                sudo rm -rf /var/lib/docker
                sudo rm -rf /var/lib/containerd
                sudo rm -rf /etc/docker
                echo ""
                log_success "Docker 已完全卸载！"
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

# ================== Nginx 管理子菜单 ==================
install_nginx_menu() {
    while true; do
        clear
        draw_title_line "Nginx 管理" 50
        echo ""
        
        # 显示当前状态
        if command -v nginx &>/dev/null; then
            local nginx_ver=$(nginx -v 2>&1 | awk -F'/' '{print $2}')
            echo -e "  ${GREEN}✓${NC} Nginx 已安装 (${nginx_ver})"
            if systemctl is-active --quiet nginx 2>/dev/null; then
                echo -e "  ${GREEN}●${NC} 运行状态: ${GREEN}运行中${NC}"
            else
                echo -e "  ${RED}●${NC} 运行状态: ${RED}已停止${NC}"
            fi
        else
            echo -e "  ${GRAY}○${NC} Nginx 未安装"
        fi
        echo ""
        
        draw_menu_item "1" "📦" "安装 Nginx"
        draw_menu_item "2" "🔀" "配置反向代理"
        draw_menu_item "3" "🔒" "申请 HTTPS 证书 (Certbot)"
        draw_menu_item "4" "▶️" "启动 Nginx"
        draw_menu_item "5" "⏹️" "停止 Nginx"
        draw_menu_item "6" "🔄" "重启 Nginx"
        draw_menu_item "7" "📊" "查看状态"
        draw_menu_item "8" "🗑️" "卸载 Nginx"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回上级菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-8]: )" nginx_choice </dev/tty
        
        case $nginx_choice in
            1)
                clear
                draw_title_line "安装 Nginx" 50
                echo ""
                log_info "正在安装 Nginx..."
                sudo apt-get update && sudo apt-get install -y nginx
                log_success "Nginx 安装完成！"
                nginx -v
                echo ""
                echo -e "  ${CYAN}配置目录:${NC} /etc/nginx/"
                echo -e "  ${CYAN}站点目录:${NC} /var/www/html/"
                press_any_key
                ;;
            2)
                clear
                draw_title_line "配置 Nginx 反向代理" 50
                echo ""
                if ! command -v nginx &>/dev/null; then
                    log_error "Nginx 未安装，请先安装！"
                    press_any_key
                    continue
                fi
                
                read -p "请输入域名 (如 example.com): " domain </dev/tty
                read -p "请输入后端地址 (如 127.0.0.1:3000): " backend </dev/tty
                
                if [[ -z "$domain" || -z "$backend" ]]; then
                    log_error "域名和后端地址不能为空！"
                    press_any_key
                    continue
                fi
                
                local conf_file="/etc/nginx/sites-available/${domain}"
                sudo tee "$conf_file" > /dev/null <<EOF
server {
    listen 80;
    server_name ${domain};

    location / {
        proxy_pass http://${backend};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
                sudo ln -sf "$conf_file" /etc/nginx/sites-enabled/
                sudo nginx -t && sudo systemctl reload nginx
                log_success "反向代理配置完成！"
                echo -e "  ${CYAN}域名:${NC} ${domain}"
                echo -e "  ${CYAN}后端:${NC} ${backend}"
                echo -e "  ${YELLOW}提示: 如需 HTTPS，请选择菜单选项3申请证书${NC}"
                press_any_key
                ;;
            3)
                clear
                draw_title_line "申请 HTTPS 证书" 50
                echo ""
                if ! command -v nginx &>/dev/null; then
                    log_error "Nginx 未安装，请先安装！"
                    press_any_key
                    continue
                fi
                
                # 检测 Certbot
                if ! command -v certbot &>/dev/null; then
                    log_info "Certbot 未安装，正在自动安装..."
                    sudo apt-get update
                    sudo apt-get install -y certbot python3-certbot-nginx
                    log_success "Certbot 安装完成！"
                    echo ""
                fi
                
                read -p "请输入域名 (如 example.com): " domain </dev/tty
                
                if [[ -z "$domain" ]]; then
                    log_error "域名不能为空！"
                    press_any_key
                    continue
                fi
                
                echo ""
                log_info "正在为 ${domain} 申请证书..."
                echo -e "  ${YELLOW}请确保域名已解析到此服务器 IP${NC}"
                echo ""
                
                if sudo certbot --nginx -d "$domain" --non-interactive --agree-tos --register-unsafely-without-email; then
                    echo ""
                    log_success "HTTPS 证书申请成功！"
                    echo -e "  ${GREEN}✓${NC} 站点已启用 HTTPS"
                    echo -e "  ${GREEN}✓${NC} 证书将自动续期"
                    echo -e "  ${CYAN}访问:${NC} https://${domain}"
                else
                    echo ""
                    log_error "证书申请失败！"
                    echo -e "  ${YELLOW}可能原因：${NC}"
                    echo -e "    • 域名未解析到此服务器"
                    echo -e "    • 80/443 端口未开放"
                    echo -e "    • Nginx 配置中没有该域名"
                fi
                press_any_key
                ;;
            4)
                sudo systemctl start nginx
                log_success "Nginx 已启动"
                press_any_key
                ;;
            5)
                sudo systemctl stop nginx
                log_success "Nginx 已停止"
                press_any_key
                ;;
            6)
                sudo systemctl restart nginx
                log_success "Nginx 已重启"
                press_any_key
                ;;
            7)
                clear
                draw_title_line "Nginx 状态" 50
                echo ""
                sudo systemctl status nginx --no-pager || true
                press_any_key
                ;;
            8)
                clear
                draw_title_line "卸载 Nginx" 50
                echo ""
                if ! command -v nginx &>/dev/null; then
                    log_warning "Nginx 未安装，无需卸载。"
                    press_any_key
                    continue
                fi
                echo -e "  ${RED}${BOLD}⚠ 警告：将卸载 Nginx 及其配置文件！${NC}"
                echo ""
                read -p "请输入 'yes' 确认卸载: " confirm </dev/tty
                if [[ "$confirm" != "yes" ]]; then
                    log_info "操作已取消。"
                    press_any_key
                    continue
                fi
                log_info "正在停止 Nginx..."
                sudo systemctl stop nginx 2>/dev/null || true
                log_info "正在卸载 Nginx..."
                sudo apt-get purge -y nginx nginx-common nginx-full nginx-core 2>/dev/null || true
                sudo apt-get autoremove -y --purge
                log_info "正在清理配置..."
                sudo rm -rf /etc/nginx
                sudo rm -rf /var/log/nginx
                echo ""
                log_success "Nginx 已完全卸载！"
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

# ================== Caddy 管理子菜单 ==================
install_caddy_menu() {
    while true; do
        clear
        draw_title_line "Caddy 管理" 50
        echo ""
        
        # 显示当前状态
        if command -v caddy &>/dev/null; then
            local caddy_ver=$(caddy version 2>/dev/null | awk '{print $1}')
            echo -e "  ${GREEN}✓${NC} Caddy 已安装 (${caddy_ver})"
            if systemctl is-active --quiet caddy 2>/dev/null; then
                echo -e "  ${GREEN}●${NC} 运行状态: ${GREEN}运行中${NC}"
            else
                echo -e "  ${RED}●${NC} 运行状态: ${RED}已停止${NC}"
            fi
        else
            echo -e "  ${GRAY}○${NC} Caddy 未安装"
        fi
        echo ""
        
        draw_menu_item "1" "📦" "安装 Caddy"
        draw_menu_item "2" "🔀" "配置反向代理 (自动 HTTPS)"
        draw_menu_item "3" "▶️" "启动 Caddy"
        draw_menu_item "4" "⏹️" "停止 Caddy"
        draw_menu_item "5" "🔄" "重启 Caddy"
        draw_menu_item "6" "📊" "查看状态"
        draw_menu_item "7" "🗑️" "卸载 Caddy"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回上级菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-7]: )" caddy_choice </dev/tty
        
        case $caddy_choice in
            1)
                clear
                draw_title_line "安装 Caddy" 50
                echo ""
                log_info "正在安装 Caddy..."
                sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https &>/dev/null
                curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg --yes
                curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
                sudo apt-get update && sudo apt-get install -y caddy
                log_success "Caddy 安装完成！"
                caddy version
                echo ""
                echo -e "  ${CYAN}配置文件:${NC} /etc/caddy/Caddyfile"
                echo -e "  ${GREEN}特性: 自动 HTTPS 证书申请与续期${NC}"
                press_any_key
                ;;
            2)
                clear
                draw_title_line "配置 Caddy 反向代理" 50
                echo ""
                if ! command -v caddy &>/dev/null; then
                    log_error "Caddy 未安装，请先安装！"
                    press_any_key
                    continue
                fi
                
                read -p "请输入域名 (如 example.com): " domain </dev/tty
                read -p "请输入后端地址 (如 127.0.0.1:3000): " backend </dev/tty
                
                if [[ -z "$domain" || -z "$backend" ]]; then
                    log_error "域名和后端地址不能为空！"
                    press_any_key
                    continue
                fi
                
                # 追加到 Caddyfile
                echo "" | sudo tee -a /etc/caddy/Caddyfile >/dev/null
                echo "${domain} {" | sudo tee -a /etc/caddy/Caddyfile >/dev/null
                echo "    reverse_proxy ${backend}" | sudo tee -a /etc/caddy/Caddyfile >/dev/null
                echo "}" | sudo tee -a /etc/caddy/Caddyfile >/dev/null
                
                sudo systemctl reload caddy
                log_success "反向代理配置完成！"
                echo -e "  ${CYAN}域名:${NC} ${domain}"
                echo -e "  ${CYAN}后端:${NC} ${backend}"
                echo -e "  ${GREEN}Caddy 将自动为该域名申请 HTTPS 证书${NC}"
                press_any_key
                ;;
            3)
                sudo systemctl start caddy
                log_success "Caddy 已启动"
                press_any_key
                ;;
            4)
                sudo systemctl stop caddy
                log_success "Caddy 已停止"
                press_any_key
                ;;
            5)
                sudo systemctl restart caddy
                log_success "Caddy 已重启"
                press_any_key
                ;;
            6)
                clear
                draw_title_line "Caddy 状态" 50
                echo ""
                sudo systemctl status caddy --no-pager || true
                press_any_key
                ;;
            7)
                clear
                draw_title_line "卸载 Caddy" 50
                echo ""
                if ! command -v caddy &>/dev/null; then
                    log_warning "Caddy 未安装，无需卸载。"
                    press_any_key
                    continue
                fi
                echo -e "  ${RED}${BOLD}⚠ 警告：将卸载 Caddy 及其配置文件！${NC}"
                echo ""
                read -p "请输入 'yes' 确认卸载: " confirm </dev/tty
                if [[ "$confirm" != "yes" ]]; then
                    log_info "操作已取消。"
                    press_any_key
                    continue
                fi
                log_info "正在停止 Caddy..."
                sudo systemctl stop caddy 2>/dev/null || true
                log_info "正在卸载 Caddy..."
                sudo apt-get purge -y caddy 2>/dev/null || true
                sudo apt-get autoremove -y --purge
                log_info "正在清理配置..."
                sudo rm -rf /etc/caddy
                sudo rm -rf /var/lib/caddy
                sudo rm -rf /var/log/caddy
                sudo rm -f /etc/apt/sources.list.d/caddy-stable.list
                sudo rm -f /usr/share/keyrings/caddy-stable-archive-keyring.gpg
                echo ""
                log_success "Caddy 已完全卸载！"
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

# ================== 常用软件安装主菜单 ==================
show_install_menu() {
    while true; do
        clear
        draw_title_line "常用软件安装" 50
        echo ""
        draw_menu_item "1" "🐳" "Docker 安装"
        draw_menu_item "2" "🌐" "Nginx 管理"
        draw_menu_item "3" "🔒" "Caddy 管理"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回主菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-3]: )" install_choice </dev/tty

        case $install_choice in
            1) install_docker_menu ;;
            2) install_nginx_menu ;;
            3) install_caddy_menu ;;
            0) break ;;
            *) log_error "无效输入。"; press_any_key ;;
        esac
    done
}

# 子菜单: 路由测试
show_route_menu() {
    while true; do
        clear
        draw_title_line "路由测试" 50
        echo ""
        draw_menu_item "1" "🔙" "回程路由测试 (VPS → 中国)"
        draw_menu_item "2" "🔜" "去程路由测试 (中国 → VPS)"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回上级菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-2]: )" route_choice </dev/tty
        
        case $route_choice in
            1)
                clear
                draw_title_line "回程路由测试" 50
                echo ""
                log_info "正在下载回程路由测试脚本..."
                log_info "此脚本将检测从 VPS 到中国各地区的回程路由线路"
                echo ""
                if curl -sL https://raw.githubusercontent.com/zhanghanyun/backtrace/main/install.sh -o backtrace.sh 2>/dev/null; then
                    log_success "下载成功，开始执行..."
                    echo ""
                    chmod +x backtrace.sh && bash backtrace.sh || true
                    rm -f backtrace.sh
                else
                    log_error "脚本下载失败！"
                fi
                press_any_key
                ;;
            2)
                clear
                draw_title_line "去程路由测试" 50
                echo ""
                log_info "去程路由测试说明："
                log_info "去程 = 从中国访问您的 VPS 时经过的路由"
                log_info "需要在中国的设备上安装 NextTrace 并追踪到您的 VPS IP"
                echo ""
                
                # 显示当前VPS的IP
                local vps_ip=$(curl -4 -s --max-time 5 ip.sb 2>/dev/null || curl -4 -s --max-time 5 ifconfig.me 2>/dev/null)
                if [[ -n "$vps_ip" ]]; then
                    echo -e "  ${WHITE}${BOLD}您的 VPS IP: ${CYAN}${vps_ip}${NC}"
                    echo ""
                fi
                
                log_info "正在安装 NextTrace 路由追踪工具..."
                echo ""
                
                # 使用官方安装脚本
                if curl -sL https://raw.githubusercontent.com/nxtrace/NTrace-core/main/nt_install.sh -o nt_install.sh 2>/dev/null; then
                    bash nt_install.sh || true
                    rm -f nt_install.sh
                    echo ""
                    log_success "NextTrace 安装完成！"
                    echo ""
                    echo -e "  ${WHITE}${BOLD}使用方法:${NC}"
                    echo -e "  ${CYAN}nexttrace ${vps_ip:-<目标IP>}${NC}  - 从本机追踪到目标"
                    echo -e "  ${CYAN}nexttrace -T <域名>${NC}      - TCP 模式追踪"
                    echo -e "  ${CYAN}nexttrace -M${NC}             - 交互式菜单"
                    echo ""
                    echo -e "  ${YELLOW}提示: 在中国的设备上运行 nexttrace ${vps_ip:-<您的VPS IP>} 可测试去程${NC}"
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

# 子菜单: 性能/网络测试脚本
show_test_menu() {
    while true; do
        clear
        draw_title_line "性能/网络测试" 50
        echo ""
        draw_menu_item "1" "🚀" "融合怪 (ecs.sh) 综合测试"
        draw_menu_item "2" "🐟" "咸鱼 IP 检测 (原创)"
        draw_menu_item "3" "🛤️" "路由测试 (回程/去程)"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回主菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-3]: )" test_choice </dev/tty
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
                draw_title_line "🐟 咸鱼 IP 检测" 50
                echo ""
                # 尝试使用本地脚本
                local script_path="$(dirname "$0")/scripts/fish_ipcheck.sh"
                if [[ -f "$script_path" ]]; then
                    log_info "使用本地脚本..."
                    bash "$script_path" || true
                else
                    # 从 GitHub 下载
                    log_info "正在从 GitHub 下载咸鱼 IP 检测脚本..."
                    if curl -sL "https://raw.githubusercontent.com/${AUTHOR_GITHUB_USER}/${MAIN_REPO_NAME}/main/scripts/fish_ipcheck.sh" -o fish_ipcheck.sh 2>/dev/null; then
                        log_success "下载成功，开始执行..."
                        echo ""
                        bash fish_ipcheck.sh || true
                        rm -f fish_ipcheck.sh
                    else
                        log_error "脚本下载失败！"
                    fi
                fi
                press_any_key
                ;;
            3)
                show_route_menu
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