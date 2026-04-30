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
        draw_menu_item "6" "🔧" "系统服务管理"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回主菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-6]: )" status_choice </dev/tty

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
            6)
                show_service_manager
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

    # 基础硬件信息
    echo -e "  ${WHITE}${BOLD}硬件信息${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    echo -e "  ${CYAN}CPU 型号${NC}    │ $(lscpu | grep 'Model name' | sed -E 's/.*Model name:\s*//' | head -1)"
    echo -e "  ${CYAN}CPU 核心${NC}    │ $(nproc) 核"
    echo -e "  ${CYAN}内存总量${NC}    │ $(free -m | awk 'NR==2{print $2}') MB"
    echo -e "  ${CYAN}磁盘总量${NC}    │ $(df -h / | awk 'NR==2{print $2}')"
    echo -e "  ${CYAN}系统架构${NC}    │ $(uname -m)"

    # 虚拟化检测
    local virt_type="物理机"
    if command -v systemd-detect-virt &>/dev/null; then
        virt_type=$(systemd-detect-virt 2>/dev/null || echo "未知")
        [[ "$virt_type" == "none" ]] && virt_type="物理机"
    elif [[ -f /proc/vz/veinfo ]]; then
        virt_type="OpenVZ"
    elif grep -q "hypervisor" /proc/cpuinfo 2>/dev/null; then
        virt_type="虚拟机"
    fi
    echo -e "  ${CYAN}虚拟化${NC}      │ ${virt_type}"

    echo ""
    echo -e "  ${WHITE}${BOLD}系统信息${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    echo -e "  ${CYAN}操作系统${NC}    │ $(. /etc/os-release && echo $PRETTY_NAME)"
    echo -e "  ${CYAN}内核版本${NC}    │ $(uname -r)"
    echo -e "  ${CYAN}运行时间${NC}    │ $(uptime -p 2>/dev/null | sed 's/up //' || uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')"

    # 负载
    local load_avg=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
    echo -e "  ${CYAN}系统负载${NC}    │ ${load_avg} (1/5/15分钟)"

    echo ""
    echo -e "  ${WHITE}${BOLD}网络信息${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"

    # 获取公网 IPv4
    local ipv4=$(get_public_ipv4)
    [[ -z "$ipv4" ]] && ipv4="获取失败"
    echo -e "  ${CYAN}公网 IPv4${NC}   │ ${ipv4}"

    # 获取公网 IPv6
    local ipv6=$(curl -s6 --connect-timeout 3 ip.sb 2>/dev/null || echo "无/获取失败")
    echo -e "  ${CYAN}公网 IPv6${NC}   │ ${ipv6}"

    # 主机名
    echo -e "  ${CYAN}主机名${NC}      │ $(hostname)"

    echo ""
    draw_footer 50
}

show_live_performance() {
    clear
    draw_title_line "VPS 实时性能" 50
    echo ""

    echo -e "  ${WHITE}${BOLD}CPU & 内存${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"

    # CPU 使用率
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')

    # IO 等待
    local iowait
    iowait=$(top -bn1 | grep "Cpu(s)" | awk '{for(i=1;i<=NF;i++) if($i ~ /wa/) print $(i-1)}' | tr -d ',')
    [[ -z "$iowait" ]] && iowait="0.0"

    # CPU 使用率颜色
    local cpu_color=$GREEN
    if (( $(echo "$cpu_usage > 70" | bc -l) )); then
        cpu_color=$RED
    elif (( $(echo "$cpu_usage > 40" | bc -l) )); then
        cpu_color=$YELLOW
    fi
    echo -e "  ${CYAN}CPU 使用率${NC}  │ ${cpu_color}${cpu_usage}%${NC}  ${DIM}(IO等待: ${iowait}%)${NC}"

    # 内存使用
    local mem_total=$(free -m | awk 'NR==2{print $2}')
    local mem_used=$(free -m | awk 'NR==2{print $3}')
    local mem_percent=$((mem_used * 100 / mem_total))

    local mem_color=$GREEN
    if (( mem_percent > 80 )); then
        mem_color=$RED
    elif (( mem_percent > 50 )); then
        mem_color=$YELLOW
    fi
    echo -e "  ${CYAN}内存使用${NC}    │ ${mem_color}${mem_used}MB${NC} / ${mem_total}MB (${mem_color}${mem_percent}%${NC})"

    # SWAP 使用
    local swap_total=$(free -m | awk 'NR==3{print $2}')
    local swap_used=$(free -m | awk 'NR==3{print $3}')
    if [[ "$swap_total" -gt 0 ]]; then
        local swap_percent=$((swap_used * 100 / swap_total))
        local swap_color=$GREEN
        if (( swap_percent > 80 )); then
            swap_color=$RED
        elif (( swap_percent > 50 )); then
            swap_color=$YELLOW
        fi
        echo -e "  ${CYAN}SWAP 使用${NC}   │ ${swap_color}${swap_used}MB${NC} / ${swap_total}MB (${swap_color}${swap_percent}%${NC})"
    else
        echo -e "  ${CYAN}SWAP 使用${NC}   │ ${GRAY}未配置${NC}"
    fi

    echo ""
    echo -e "  ${WHITE}${BOLD}磁盘 & 网络${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"

    # 磁盘使用
    local disk_info=$(df -h / | awk 'NR==2{printf "%s / %s (%s)", $3, $2, $5}')
    local disk_percent=$(df -h / | awk 'NR==2{print $5}' | tr -d '%')

    local disk_color=$GREEN
    if (( disk_percent > 80 )); then
        disk_color=$RED
    elif (( disk_percent > 60 )); then
        disk_color=$YELLOW
    fi
    echo -e "  ${CYAN}磁盘空间${NC}    │ ${disk_color}${disk_info}${NC}"

    # 网络连接数
    local tcp_conn=$(ss -t state established 2>/dev/null | wc -l)
    local tcp_listen=$(ss -tln 2>/dev/null | grep -c LISTEN || echo 0)
    echo -e "  ${CYAN}网络连接${NC}    │ TCP 已建立: ${tcp_conn}  监听端口: ${tcp_listen}"

    # 系统负载
    local load_avg=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
    echo -e "  ${CYAN}系统负载${NC}    │ ${load_avg}"

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

# ================== 系统服务管理 ==================
show_service_manager() {
    while true; do
        clear
        draw_title_line "系统服务管理" 50
        echo ""
        draw_menu_item "1" "📋" "查看运行中的服务"
        draw_menu_item "2" "🔍" "搜索服务"
        draw_menu_item "3" "▶️" "启动服务"
        draw_menu_item "4" "⏹️" "停止服务"
        draw_menu_item "5" "🔄" "重启服务"
        draw_menu_item "6" "📊" "查看服务状态"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回上级菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-6]: )" svc_choice </dev/tty

        case $svc_choice in
            1)
                clear
                draw_title_line "运行中的服务" 50
                echo ""
                echo -e "  ${WHITE}${BOLD}活跃的系统服务 (前30个)${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                echo ""
                systemctl list-units --type=service --state=running --no-pager 2>/dev/null | head -35 || \
                    service --status-all 2>/dev/null | grep '\[ + \]' | head -30
                press_any_key
                ;;
            2)
                clear
                draw_title_line "搜索服务" 50
                echo ""
                read -p "请输入服务名关键词: " keyword </dev/tty
                if [[ -n "$keyword" ]]; then
                    echo ""
                    echo -e "  ${WHITE}${BOLD}搜索结果:${NC}"
                    echo ""
                    systemctl list-units --type=service --all --no-pager 2>/dev/null | grep -i "$keyword" || \
                        echo "  未找到匹配的服务"
                fi
                press_any_key
                ;;
            3)
                clear
                draw_title_line "启动服务" 50
                echo ""
                read -p "请输入要启动的服务名: " svc_name </dev/tty
                if [[ -n "$svc_name" ]]; then
                    if sudo systemctl start "$svc_name" 2>/dev/null; then
                        log_success "服务 $svc_name 已启动"
                    else
                        log_error "启动服务 $svc_name 失败"
                    fi
                fi
                press_any_key
                ;;
            4)
                clear
                draw_title_line "停止服务" 50
                echo ""
                read -p "请输入要停止的服务名: " svc_name </dev/tty
                if [[ -n "$svc_name" ]]; then
                    read -p "确认停止服务 $svc_name? (y/n): " confirm </dev/tty
                    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                        if sudo systemctl stop "$svc_name" 2>/dev/null; then
                            log_success "服务 $svc_name 已停止"
                        else
                            log_error "停止服务 $svc_name 失败"
                        fi
                    fi
                fi
                press_any_key
                ;;
            5)
                clear
                draw_title_line "重启服务" 50
                echo ""
                read -p "请输入要重启的服务名: " svc_name </dev/tty
                if [[ -n "$svc_name" ]]; then
                    if sudo systemctl restart "$svc_name" 2>/dev/null; then
                        log_success "服务 $svc_name 已重启"
                    else
                        log_error "重启服务 $svc_name 失败"
                    fi
                fi
                press_any_key
                ;;
            6)
                clear
                draw_title_line "查看服务状态" 50
                echo ""
                read -p "请输入服务名: " svc_name </dev/tty
                if [[ -n "$svc_name" ]]; then
                    echo ""
                    sudo systemctl status "$svc_name" --no-pager 2>/dev/null || \
                        log_error "无法获取服务 $svc_name 的状态"
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
