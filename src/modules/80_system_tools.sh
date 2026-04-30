# ================== 系统工具菜单 ==================
print_diag_item() {
    local status="$1"
    local name="$2"
    local detail="$3"

    case "$status" in
        ok) echo -e "  ${GREEN}✓${NC} ${name}: ${detail}" ;;
        warn) echo -e "  ${YELLOW}⚠${NC} ${name}: ${detail}" ;;
        fail) echo -e "  ${RED}✗${NC} ${name}: ${detail}" ;;
        *) echo -e "  ${GRAY}-${NC} ${name}: ${detail}" ;;
    esac
}

diag_cmd_item() {
    local level="$1"
    local cmd="$2"
    local detail="${3:-}"

    if command -v "$cmd" &>/dev/null; then
        print_diag_item ok "$cmd" "$(command -v "$cmd")"
    elif [[ "$level" == "required" ]]; then
        print_diag_item fail "$cmd" "${detail:-未安装，核心功能可能不可用}"
    else
        print_diag_item warn "$cmd" "${detail:-未安装，部分功能可能受限}"
    fi
}

diag_url_reachable() {
    local url="$1"
    curl -fsIL --connect-timeout 3 --max-time 6 "$url" -o /dev/null 2>/dev/null || \
        curl -fsL --connect-timeout 3 --max-time 6 -r 0-0 "$url" -o /dev/null 2>/dev/null
}

diag_url_item() {
    local level="$1"
    local name="$2"
    local url="$3"

    if diag_url_reachable "$url"; then
        print_diag_item ok "$name" "可访问"
    elif [[ "$level" == "required" ]]; then
        print_diag_item fail "$name" "访问失败: $url"
    else
        print_diag_item warn "$name" "访问失败: $url"
    fi
}

diag_sudo_ready() {
    [[ $EUID -eq 0 ]] || sudo -n true 2>/dev/null
}

diag_has_docker_compose() {
    command -v docker &>/dev/null && docker compose version &>/dev/null
}

diag_feature_item() {
    local status="$1"
    local name="$2"
    local detail="$3"
    print_diag_item "$status" "$name" "$detail"
}

show_system_diagnostics() {
    local no_pause=0
    [[ "${1:-}" == "--no-pause" ]] && no_pause=1

    clear
    draw_title_line "全功能巡检" 50
    echo ""
    echo -e "  ${DIM}只做环境、依赖和外部链接检查，不会执行 DD、重装、优化或安装脚本。${NC}"
    echo ""

    echo -e "  ${WHITE}${BOLD}基础信息${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    print_diag_item ok "脚本版本" "$VERSION"
    print_diag_item ok "脚本路径" "$SCRIPT_PATH"
    print_diag_item ok "主机名" "$(hostname 2>/dev/null || echo unknown)"
    print_diag_item ok "内核" "$(uname -srmo 2>/dev/null || uname -a)"
    if [[ -f /etc/os-release ]]; then
        local os_name
        os_name=$(grep -E '^PRETTY_NAME=' /etc/os-release | cut -d= -f2- | tr -d '"' 2>/dev/null)
        print_diag_item ok "系统" "${os_name:-unknown}"
    fi
    print_diag_item ok "包管理器" "$(detect_pkg_manager)"
    local access_host
    access_host=$(get_primary_access_host)
    if [[ -n "$access_host" ]]; then
        print_diag_item ok "访问地址 IP" "$access_host"
    else
        print_diag_item warn "访问地址 IP" "自动获取失败，部署后需手动替换"
    fi
    if [[ $EUID -eq 0 ]]; then
        print_diag_item ok "权限" "root"
    elif sudo -n true 2>/dev/null; then
        print_diag_item ok "权限" "非 root，但免密 sudo 可用"
    else
        print_diag_item warn "权限" "非 root 且无免密 sudo，安装/修改系统配置时需要输入密码或改用 root"
    fi
    echo ""

    echo -e "  ${WHITE}${BOLD}关键依赖${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    local cmd
    for cmd in bash curl sudo awk sed grep; do
        diag_cmd_item required "$cmd"
    done
    for cmd in systemctl jq bc dig ss openssl crontab journalctl; do
        diag_cmd_item optional "$cmd"
    done
    echo ""

    echo -e "  ${WHITE}${BOLD}网络与更新源${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    local public_ipv4
    public_ipv4=$(get_public_ipv4)
    if [[ -n "$public_ipv4" ]]; then
        print_diag_item ok "公网 IPv4" "$public_ipv4"
    else
        print_diag_item warn "公网 IPv4" "获取失败"
    fi
    diag_url_item required "GitHub API" "https://api.github.com/repos/${AUTHOR_GITHUB_USER}/${MAIN_REPO_NAME}/git/ref/heads/main"
    diag_url_item required "脚本更新源" "$(get_release_url)"
    diag_url_item optional "Docker 安装脚本" "https://get.docker.com"
    diag_url_item optional "NodeSource Node.js 22" "https://deb.nodesource.com/setup_22.x"
    echo ""

    echo -e "  ${WHITE}${BOLD}Docker 与容器部署${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    if command -v docker &>/dev/null; then
        print_diag_item ok "docker" "$(docker --version 2>/dev/null | head -1)"
        if docker compose version &>/dev/null; then
            print_diag_item ok "compose" "$(docker compose version 2>/dev/null | head -1)"
        else
            print_diag_item warn "compose" "Docker Compose 插件不可用"
        fi
        if systemctl is-active --quiet docker 2>/dev/null; then
            print_diag_item ok "docker 服务" "运行中"
        else
            print_diag_item warn "docker 服务" "未运行或非 systemd 环境"
        fi
        if docker info &>/dev/null; then
            print_diag_item ok "docker 权限" "当前用户可直接访问 Docker"
        elif diag_sudo_ready && sudo docker info &>/dev/null; then
            print_diag_item ok "docker 权限" "可通过 sudo 访问 Docker"
        else
            print_diag_item warn "docker 权限" "当前用户暂不能访问 Docker，部署时可能需要 sudo 密码或加入 docker 组"
        fi
    else
        print_diag_item warn "docker" "未安装"
    fi
    diag_url_item optional "预设项目配置" "https://raw.githubusercontent.com/${AUTHOR_GITHUB_USER}/${MAIN_REPO_NAME}/main/presets/homepage/docker-compose.yaml"
    echo ""

    echo -e "  ${WHITE}${BOLD}主菜单功能巡检${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    if command -v curl &>/dev/null && command -v awk &>/dev/null && command -v sed &>/dev/null; then
        diag_feature_item ok "1 系统状态监控" "核心命令可用"
    else
        diag_feature_item fail "1 系统状态监控" "缺少 curl/awk/sed 等基础命令"
    fi
    diag_feature_item ok "2 性能/网络测试" "菜单可用；第三方测速脚本见下方外部脚本源"
    diag_feature_item warn "3 DD系统/重装系统" "高风险功能，仅检查下载源，不自动执行"
    if [[ "$(detect_pkg_manager)" != "unknown" ]]; then
        diag_feature_item ok "4 常用软件安装" "包管理器可用: $(detect_pkg_manager)"
    else
        diag_feature_item fail "4 常用软件安装" "未识别 apt/dnf/yum"
    fi
    if diag_has_docker_compose; then
        diag_feature_item ok "5 Docker Compose 项目部署" "Docker 与 Compose 可用"
    else
        diag_feature_item warn "5 Docker Compose 项目部署" "需要 Docker 与 Docker Compose"
    fi
    if command -v sysctl &>/dev/null; then
        diag_feature_item ok "6 VPS 优化" "sysctl 可用；部分优化仍依赖内核和外部脚本"
    else
        diag_feature_item warn "6 VPS 优化" "缺少 sysctl"
    fi
    if diag_sudo_ready; then
        diag_feature_item ok "7 系统工具" "系统配置类操作权限基本满足"
    else
        diag_feature_item warn "7 系统工具" "部分操作需要 sudo 密码或 root"
    fi
    if command -v jq &>/dev/null; then
        diag_feature_item ok "8 网络隧道工具" "jq 可用；Gost 脚本源见下方"
    else
        diag_feature_item warn "8 网络隧道工具" "需要 jq，脚本会尝试自动安装"
    fi
    if command -v openclaw &>/dev/null || command -v hermes &>/dev/null || command -v node &>/dev/null || command -v docker &>/dev/null; then
        diag_feature_item ok "9 虾和马" "检测到 AI 工具运行基础或已安装组件"
    else
        diag_feature_item warn "9 虾和马" "OpenClaw/Hermes 需要 Node.js、Docker 或官方安装脚本"
    fi
    echo ""

    echo -e "  ${WHITE}${BOLD}外部脚本源巡检${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    diag_url_item optional "融合怪 ecs.sh" "https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh"
    diag_url_item optional "回程路由 backtrace" "https://raw.githubusercontent.com/zhanghanyun/backtrace/main/install.sh"
    diag_url_item optional "NextTrace 安装脚本" "https://raw.githubusercontent.com/nxtrace/NTrace-core/main/nt_install.sh"
    diag_url_item optional "流媒体检测脚本" "https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/check.sh"
    diag_url_item optional "reinstall 主源" "https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh"
    diag_url_item optional "OsMutation 主源" "https://raw.githubusercontent.com/LloydAsp/OsMutation/main/OsMutation.sh"
    diag_url_item optional "BBR/TCP 主源" "https://sh.nekoneko.cloud/tools.sh"
    diag_url_item optional "BBR/TCP 备用源" "https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh"
    diag_url_item optional "WARP 管理脚本" "https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh"
    diag_url_item optional "鱼工具 IP 检测" "https://raw.githubusercontent.com/${AUTHOR_GITHUB_USER}/${MAIN_REPO_NAME}/main/scripts/fish_ipcheck.sh"
    diag_url_item optional "Gost 管理脚本" "https://raw.githubusercontent.com/${AUTHOR_GITHUB_USER}/${MAIN_REPO_NAME}/main/scripts/gost_manager.sh"
    echo ""

    echo -e "  ${WHITE}${BOLD}AI 工具巡检${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    if declare -F check_node_version >/dev/null && check_node_version; then
        print_diag_item ok "Node.js" "$(node -v 2>/dev/null)"
    elif command -v node &>/dev/null; then
        local node_ver
        node_ver=$(node -v 2>/dev/null || true)
        [[ -z "$node_ver" ]] && node_ver="版本获取失败"
        print_diag_item warn "Node.js" "${node_ver}，OpenClaw npm 安装需要 v22+"
    else
        print_diag_item warn "Node.js" "未安装，OpenClaw npm 安装会尝试安装 v22"
    fi
    if command -v openclaw &>/dev/null; then
        print_diag_item ok "OpenClaw" "$(openclaw --version 2>/dev/null || echo 已安装)"
    else
        print_diag_item warn "OpenClaw" "未安装"
    fi
    local hermes_cmd=""
    if declare -F find_hermes_cmd >/dev/null && hermes_cmd="$(find_hermes_cmd)"; then
        print_diag_item ok "Hermes Agent" "$("$hermes_cmd" --version 2>/dev/null || echo "$hermes_cmd")"
    else
        print_diag_item warn "Hermes Agent" "未安装"
    fi
    diag_url_item optional "Hermes 官方安装脚本" "https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh"
    echo ""

    echo -e "  ${WHITE}${BOLD}磁盘、内存与端口${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    df -h / 2>/dev/null | awk 'NR==1{print "  "$0} NR==2{print "  "$0}'
    df -ih / 2>/dev/null | awk 'NR==1{print "  "$0} NR==2{print "  "$0}'
    free -h 2>/dev/null | awk 'NR==1{print "  "$0} NR==2{print "  "$0}'
    echo ""
    local port
    for port in 22 53 80 443 3000 3001 8080 8081 8443 18789; do
        if is_port_in_use "$port"; then
            print_diag_item warn "端口 ${port}" "已占用"
        else
            print_diag_item ok "端口 ${port}" "空闲"
        fi
    done
    echo ""
    echo -e "  ${DIM}说明: 巡检通过代表环境和下载源基本可用，不代表高风险操作已执行或第三方脚本永远稳定。${NC}"
    echo ""
    [[ $no_pause -eq 0 ]] && press_any_key
}

show_config_backup_menu() {
    local backup_dir="/var/backups/fishtools"

    clear
    draw_title_line "配置备份恢复" 50
    echo ""

    if [[ ! -d "$backup_dir" ]]; then
        log_warning "暂无备份目录: $backup_dir"
        press_any_key
        return
    fi

    local backups=()
    local backup_file
    while IFS= read -r backup_file; do
        backups+=("$backup_file")
    done < <(ls -1t "$backup_dir"/*.bak 2>/dev/null)

    if [[ ${#backups[@]} -eq 0 ]]; then
        log_warning "暂无可恢复的配置备份"
        press_any_key
        return
    fi

    echo -e "  ${WHITE}${BOLD}最近备份${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    local i original_path display_count
    display_count=${#backups[@]}
    [[ $display_count -gt 20 ]] && display_count=20

    for ((i=0; i<display_count; i++)); do
        original_path="未知原路径"
        [[ -f "${backups[$i]}.path" ]] && original_path=$(cat "${backups[$i]}.path" 2>/dev/null)
        echo -e "  ${CYAN}$((i + 1)).${NC} ${original_path}"
        echo -e "      ${DIM}$(basename "${backups[$i]}")${NC}"
    done

    echo ""
    read -p "请选择要恢复的备份 [1-${display_count}]，或回车取消: " backup_choice </dev/tty
    [[ -z "$backup_choice" ]] && return 0

    if [[ ! "$backup_choice" =~ ^[0-9]+$ ]] || [[ "$backup_choice" -lt 1 ]] || [[ "$backup_choice" -gt "$display_count" ]]; then
        log_error "无效选择"
        press_any_key
        return 1
    fi

    local selected_backup="${backups[$((backup_choice - 1))]}"
    local restore_path=""
    [[ -f "${selected_backup}.path" ]] && restore_path=$(cat "${selected_backup}.path" 2>/dev/null)
    if [[ -z "$restore_path" || "$restore_path" == "未知原路径" ]]; then
        read -p "无法识别原路径，请输入恢复目标路径: " restore_path </dev/tty
    fi

    if [[ -z "$restore_path" || "$restore_path" != /* ]]; then
        log_error "恢复目标路径无效"
        press_any_key
        return 1
    fi

    echo ""
    echo -e "  备份文件: ${CYAN}${selected_backup}${NC}"
    echo -e "  恢复到:   ${CYAN}${restore_path}${NC}"
    echo ""
    read -p "确认恢复? (y/n): " confirm_restore </dev/tty
    if [[ "$confirm_restore" != "y" && "$confirm_restore" != "Y" ]]; then
        log_info "操作已取消"
        press_any_key
        return 0
    fi

    if [[ -e "$restore_path" ]]; then
        backup_config_file "$restore_path" >/dev/null || {
            log_error "恢复前备份当前配置失败，已取消恢复"
            press_any_key
            return 1
        }
    fi

    if sudo cp -a "$selected_backup" "$restore_path"; then
        log_success "配置已恢复: $restore_path"
    else
        log_error "恢复失败，请检查权限和路径"
    fi
    press_any_key
}

show_system_tools_menu() {
    while true; do
        clear
        draw_title_line "系统工具" 50
        echo ""
        draw_menu_item "1" "🧹" "磁盘清理"
        draw_menu_item "2" "🌐" "修改时区"
        draw_menu_item "3" "🏷️" "修改主机名"
        draw_menu_item "4" "🔌" "修改 SSH 端口"
        draw_menu_item "5" "📅" "定时任务管理"
        draw_menu_item "6" "🔄" "系统重启/关机"
        draw_menu_item "7" "📦" "系统包一键更新"
        draw_menu_item "8" "📋" "系统日志查看"
        draw_menu_item "9" "📊" "流量统计 (vnstat)"
        draw_menu_item "10" "🩺" "全功能巡检"
        draw_menu_item "11" "♻️" "配置备份恢复"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回主菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-11]: )" tools_choice </dev/tty

        case $tools_choice in
            1)
                clear
                draw_title_line "磁盘清理" 50
                echo ""

                # 显示当前磁盘使用情况
                echo -e "  ${WHITE}${BOLD}当前磁盘使用情况${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                df -h / | awk 'NR==1{print "  "$0} NR==2{print "  "$0}'
                echo ""

                # 计算可清理空间
                local apt_cache=$(du -sh /var/cache/apt/archives 2>/dev/null | awk '{print $1}' || echo "0")
                local journal=$(du -sh /var/log/journal 2>/dev/null | awk '{print $1}' || echo "0")
                local tmp_size=$(du -sh /tmp 2>/dev/null | awk '{print $1}' || echo "0")
                local old_kernels=$(dpkg -l 'linux-*' 2>/dev/null | grep -E '^ii' | wc -l)

                echo -e "  ${WHITE}${BOLD}可清理项目${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                echo -e "  ${CYAN}1.${NC} APT 缓存            约 ${apt_cache}"
                echo -e "  ${CYAN}2.${NC} 系统日志 (Journal)  约 ${journal}"
                echo -e "  ${CYAN}3.${NC} 临时文件 (/tmp)     约 ${tmp_size}"
                echo -e "  ${CYAN}4.${NC} 旧内核 (保留当前)   ${old_kernels} 个包"
                echo -e "  ${CYAN}5.${NC} 一键清理全部"
                echo ""

                read -p "请选择要清理的项目 [1-5]: " clean_opt </dev/tty
                echo ""

                case $clean_opt in
                    1)
                        log_info "清理包管理器缓存..."
                        local pm=$(detect_pkg_manager)
                        case "$pm" in
                            apt) sudo apt-get clean ;;
                            dnf) sudo dnf clean all ;;
                            yum) sudo yum clean all ;;
                        esac
                        log_success "包缓存已清理"
                        ;;
                    2)
                        log_info "清理系统日志..."
                        sudo journalctl --vacuum-time=7d 2>/dev/null || true
                        log_success "日志已清理（保留7天）"
                        ;;
                    3)
                        log_info "清理临时文件..."
                        safe_clean_tmp_files
                        log_success "临时文件已清理（保留近 60 分钟和系统 socket）"
                        ;;
                    4)
                        log_info "清理旧内核..."
                        local pm=$(detect_pkg_manager)
                        case "$pm" in
                            apt) sudo apt-get autoremove --purge -y 2>/dev/null || true ;;
                            dnf) sudo dnf autoremove -y 2>/dev/null || true ;;
                            yum) sudo package-cleanup --oldkernels --count=1 2>/dev/null || true ;;
                        esac
                        log_success "旧内核已清理"
                        ;;
                    5)
                        log_info "执行一键清理..."
                        local pm=$(detect_pkg_manager)
                        case "$pm" in
                            apt) sudo apt-get clean; sudo apt-get autoremove --purge -y 2>/dev/null || true ;;
                            dnf) sudo dnf clean all; sudo dnf autoremove -y 2>/dev/null || true ;;
                            yum) sudo yum clean all; sudo yum autoremove -y 2>/dev/null || true ;;
                        esac
                        sudo journalctl --vacuum-time=7d 2>/dev/null || true
                        safe_clean_tmp_files
                        safe_clean_user_cache
                        log_success "全部清理完成！"
                        ;;
                esac

                echo ""
                echo -e "  ${WHITE}${BOLD}清理后磁盘使用${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                df -h / | awk 'NR==2{print "  "$0}'
                press_any_key
                ;;
            2)
                clear
                draw_title_line "修改时区" 50
                echo ""
                echo -e "  ${WHITE}${BOLD}当前时区${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                echo -e "  $(timedatectl 2>/dev/null | grep 'Time zone' | awk -F': ' '{print $2}' || date +%Z)"
                echo ""
                echo -e "  ${WHITE}${BOLD}常用时区${NC}"
                echo -e "  ${CYAN}1.${NC} Asia/Shanghai     (中国-上海)"
                echo -e "  ${CYAN}2.${NC} Asia/Hong_Kong    (中国-香港)"
                echo -e "  ${CYAN}3.${NC} Asia/Tokyo        (日本-东京)"
                echo -e "  ${CYAN}4.${NC} Asia/Singapore    (新加坡)"
                echo -e "  ${CYAN}5.${NC} America/New_York  (美国-纽约)"
                echo -e "  ${CYAN}6.${NC} America/Los_Angeles (美国-洛杉矶)"
                echo -e "  ${CYAN}7.${NC} Europe/London     (英国-伦敦)"
                echo -e "  ${CYAN}8.${NC} 自定义输入"
                echo ""
                read -p "请选择时区 [1-8]: " tz_choice </dev/tty

                local new_tz=""
                case $tz_choice in
                    1) new_tz="Asia/Shanghai" ;;
                    2) new_tz="Asia/Hong_Kong" ;;
                    3) new_tz="Asia/Tokyo" ;;
                    4) new_tz="Asia/Singapore" ;;
                    5) new_tz="America/New_York" ;;
                    6) new_tz="America/Los_Angeles" ;;
                    7) new_tz="Europe/London" ;;
                    8)
                        read -p "请输入时区 (如 Asia/Shanghai): " new_tz </dev/tty
                        ;;
                esac

                if [[ -n "$new_tz" ]]; then
                    sudo timedatectl set-timezone "$new_tz" 2>/dev/null || \
                    sudo ln -sf "/usr/share/zoneinfo/$new_tz" /etc/localtime
                    log_success "时区已设置为: $new_tz"
                    echo -e "  当前时间: $(date)"
                fi
                press_any_key
                ;;
            3)
                clear
                draw_title_line "修改主机名" 50
                echo ""
                echo -e "  ${WHITE}${BOLD}当前主机名${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                echo -e "  $(hostname)"
                echo ""
                read -p "请输入新主机名: " new_hostname </dev/tty

                if [[ -n "$new_hostname" ]]; then
                    # 校验主机名格式 (RFC 1123)
                    if [[ ! "$new_hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$ ]]; then
                        log_error "无效主机名！仅允许字母、数字和连字符，不能以连字符开头或结尾"
                        press_any_key
                        continue
                    fi
                    sudo hostnamectl set-hostname "$new_hostname" 2>/dev/null || \
                    echo "$new_hostname" | sudo tee /etc/hostname >/dev/null
                    # 更新 /etc/hosts
                    sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$new_hostname/" /etc/hosts 2>/dev/null || true
                    log_success "主机名已设置为: $new_hostname"
                    echo -e "  ${YELLOW}提示: 重新登录后生效${NC}"
                fi
                press_any_key
                ;;
            4)
                clear
                draw_title_line "修改 SSH 端口" 50
                echo ""
                local current_port=$(grep -E "^Port" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")
                [[ -z "$current_port" ]] && current_port="22"

                echo -e "  ${WHITE}${BOLD}当前 SSH 端口${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                echo -e "  ${current_port}"
                echo ""
                echo -e "  ${YELLOW}⚠ 警告：修改端口前请确保新端口已在防火墙中开放！${NC}"
                echo ""
                read -p "请输入新 SSH 端口 (1024-65535): " new_port </dev/tty

                if [[ "$new_port" =~ ^[0-9]+$ ]] && [[ "$new_port" -ge 1024 ]] && [[ "$new_port" -le 65535 ]]; then
                    if [[ "$new_port" != "$current_port" ]] && is_port_in_use "$new_port"; then
                        log_error "端口 $new_port 已被占用，请选择其他端口。"
                        press_any_key
                        continue
                    fi

                    # 备份配置
                    local backup_file
                    if ! backup_file=$(backup_config_file /etc/ssh/sshd_config); then
                        log_error "备份 SSH 配置失败，已取消操作。"
                        press_any_key
                        continue
                    fi

                    # 修改端口
                    if grep -q "^Port" /etc/ssh/sshd_config; then
                        sudo sed -i "s/^Port.*/Port $new_port/" /etc/ssh/sshd_config
                    elif grep -q "^#Port" /etc/ssh/sshd_config; then
                        sudo sed -i "s/^#Port.*/Port $new_port/" /etc/ssh/sshd_config
                    else
                        echo "Port $new_port" | sudo tee -a /etc/ssh/sshd_config >/dev/null
                    fi

                    if ! test_sshd_config; then
                        sudo cp "$backup_file" /etc/ssh/sshd_config
                        log_error "SSH 配置语法检查失败，已恢复原配置。"
                        press_any_key
                        continue
                    fi

                    # 尝试在防火墙中开放新端口
                    if command -v ufw &>/dev/null; then
                        sudo ufw allow "$new_port"/tcp 2>/dev/null || true
                    fi

                    # 同步更新 fail2ban 配置
                    if command -v fail2ban-client &>/dev/null && [[ -f /etc/fail2ban/jail.local ]]; then
                        sudo sed -i "s/^port = .*/port = $new_port/" /etc/fail2ban/jail.local 2>/dev/null || true
                        # 如果没有 port 行，则在 [sshd] 段后添加
                        if ! grep -q "^port = " /etc/fail2ban/jail.local 2>/dev/null; then
                            sudo sed -i "/^\[sshd\]/a port = $new_port" /etc/fail2ban/jail.local 2>/dev/null || true
                        fi
                        sudo systemctl restart fail2ban 2>/dev/null || true
                        log_info "fail2ban 已同步更新到端口 $new_port"
                    fi

                    log_success "SSH 端口已修改为: $new_port"
                    echo ""
                    echo -e "  ${RED}${BOLD}重要提示：${NC}"
                    echo -e "  1. 请确保防火墙已开放端口 $new_port"
                    echo -e "  2. 新开一个终端测试: ${CYAN}ssh -p $new_port user@ip${NC}"
                    echo -e "  3. 确认能连接后再关闭当前终端"
                    echo ""
                    read -p "是否立即重启 SSH 服务? (y/n): " restart_ssh </dev/tty
                    if [[ "$restart_ssh" == "y" || "$restart_ssh" == "Y" ]]; then
                        if sudo systemctl restart sshd 2>/dev/null || sudo service ssh restart; then
                            log_success "SSH 服务已重启"
                        else
                            log_error "SSH 服务重启失败，请检查服务名称和配置。"
                        fi
                    fi
                else
                    log_error "无效端口号！请输入 1024-65535 之间的数字"
                fi
                press_any_key
                ;;
            5)
                clear
                draw_title_line "定时任务管理" 50
                echo ""
                echo -e "  ${WHITE}${BOLD}当前用户的 Cron 任务${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                crontab -l 2>/dev/null || echo "  暂无定时任务"
                echo ""
                draw_menu_item "1" "➕" "添加定时任务"
                draw_menu_item "2" "📝" "编辑定时任务"
                draw_menu_item "3" "🗑️" "清空所有任务"
                echo ""
                read -p "请选择操作 [1-3]: " cron_opt </dev/tty

                case $cron_opt in
                    1)
                        echo ""
                        echo -e "  ${WHITE}${BOLD}Cron 时间格式说明${NC}"
                        echo -e "  ${GRAY}分 时 日 月 周 命令${NC}"
                        echo -e "  ${DIM}示例: 0 2 * * * /path/to/script.sh (每天凌晨2点执行)${NC}"
                        echo ""
                        read -p "请输入 Cron 表达式 (如 0 2 * * *): " cron_expr </dev/tty
                        read -p "请输入要执行的命令: " cron_cmd </dev/tty
                        if [[ -n "$cron_expr" && -n "$cron_cmd" ]]; then
                            (crontab -l 2>/dev/null; echo "$cron_expr $cron_cmd") | crontab -
                            log_success "定时任务已添加"
                        fi
                        ;;
                    2)
                        crontab -e
                        ;;
                    3)
                        read -p "确认清空所有定时任务? (y/n): " confirm </dev/tty
                        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                            crontab -r 2>/dev/null || true
                            log_success "定时任务已清空"
                        fi
                        ;;
                esac
                press_any_key
                ;;
            6)
                clear
                draw_title_line "系统重启/关机" 50
                echo ""
                echo -e "  ${RED}${BOLD}⚠ 警告：此操作将中断所有服务！${NC}"
                echo ""
                echo -e "  ${CYAN}1.${NC} 立即重启"
                echo -e "  ${CYAN}2.${NC} 立即关机"
                echo -e "  ${CYAN}3.${NC} 定时重启 (分钟后)"
                echo ""
                read -p "请选择操作 [1-3]: " power_opt </dev/tty

                case $power_opt in
                    1)
                        read -p "确认立即重启? (y/n): " confirm </dev/tty
                        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                            log_warning "系统将在 5 秒后重启..."
                            sleep 5
                            sudo reboot
                        fi
                        ;;
                    2)
                        read -p "确认立即关机? (y/n): " confirm </dev/tty
                        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                            log_warning "系统将在 5 秒后关机..."
                            sleep 5
                            sudo poweroff
                        fi
                        ;;
                    3)
                        read -p "请输入分钟数: " minutes </dev/tty
                        if [[ "$minutes" =~ ^[0-9]+$ ]]; then
                            sudo shutdown -r +"$minutes" "System will reboot in $minutes minutes"
                            log_success "已设置 $minutes 分钟后重启"
                            echo -e "  ${DIM}取消命令: sudo shutdown -c${NC}"
                        fi
                        ;;
                esac
                press_any_key
                ;;
            7)
                clear
                draw_title_line "系统包一键更新" 50
                echo ""
                local pm=$(detect_pkg_manager)
                echo -e "  ${WHITE}${BOLD}包管理器: ${CYAN}${pm}${NC}"
                echo ""
                log_info "正在更新软件包索引..."
                pkg_update
                echo ""
                log_info "正在升级所有已安装的软件包..."
                case "$pm" in
                    apt) sudo apt-get upgrade -y ;;
                    dnf) sudo dnf upgrade -y ;;
                    yum) sudo yum update -y ;;
                    *) log_error "不支持的包管理器" ;;
                esac
                echo ""
                log_success "系统包更新完成！"
                press_any_key
                ;;
            8)
                clear
                draw_title_line "系统日志查看" 50
                echo ""
                echo -e "  ${WHITE}${BOLD}选择要查看的日志:${NC}"
                echo -e "  ${CYAN}1.${NC} 系统日志 (最近 50 条)"
                echo -e "  ${CYAN}2.${NC} 认证日志 (SSH 登录记录)"
                echo -e "  ${CYAN}3.${NC} 内核日志 (dmesg)"
                echo -e "  ${CYAN}4.${NC} 实时跟踪系统日志"
                echo -e "  ${CYAN}5.${NC} 按关键词搜索日志"
                echo ""
                read -p "请选择 [1-5]: " log_choice </dev/tty
                echo ""
                case $log_choice in
                    1)
                        echo -e "  ${WHITE}${BOLD}系统日志 (最近 50 条)${NC}"
                        echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                        sudo journalctl -n 50 --no-pager 2>/dev/null || \
                            sudo tail -50 /var/log/syslog 2>/dev/null || \
                            sudo tail -50 /var/log/messages 2>/dev/null || \
                            log_error "无法读取系统日志"
                        ;;
                    2)
                        echo -e "  ${WHITE}${BOLD}认证日志 (最近 30 条)${NC}"
                        echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                        sudo journalctl -u sshd -n 30 --no-pager 2>/dev/null || \
                            sudo tail -30 /var/log/auth.log 2>/dev/null || \
                            sudo tail -30 /var/log/secure 2>/dev/null || \
                            log_error "无法读取认证日志"
                        ;;
                    3)
                        echo -e "  ${WHITE}${BOLD}内核日志${NC}"
                        echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                        sudo dmesg --time-format iso 2>/dev/null | tail -30 || \
                            sudo dmesg | tail -30
                        ;;
                    4)
                        log_info "实时跟踪系统日志中... 按 Ctrl+C 退出"
                        echo ""
                        sudo journalctl -f --no-pager 2>/dev/null || \
                            sudo tail -f /var/log/syslog 2>/dev/null || \
                            sudo tail -f /var/log/messages 2>/dev/null || \
                            log_error "无法跟踪系统日志"
                        ;;
                    5)
                        read -p "请输入搜索关键词: " log_keyword </dev/tty
                        if [[ -n "$log_keyword" ]]; then
                            echo ""
                            echo -e "  ${WHITE}${BOLD}搜索结果: '${log_keyword}'${NC}"
                            echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                            sudo journalctl --no-pager -n 50 2>/dev/null | grep -i "$log_keyword" || \
                                echo "  未找到匹配的日志"
                        fi
                        ;;
                esac
                press_any_key
                ;;
            9)
                clear
                draw_title_line "流量统计 (vnstat)" 50
                echo ""

                if ! command -v vnstat &>/dev/null; then
                    echo -e "  ${GRAY}○${NC} vnstat 未安装"
                    echo ""
                    echo -e "  ${WHITE}${BOLD}vnstat 是一个轻量级流量监控工具${NC}"
                    echo -e "  ${DIM}安装后自动在后台统计网络流量，支持月度/日/小时报表${NC}"
                    echo ""
                    read -p "是否安装 vnstat? (y/n): " install_vnstat </dev/tty
                    if [[ "$install_vnstat" == "y" || "$install_vnstat" == "Y" ]]; then
                        pkg_update && pkg_install vnstat
                        sudo systemctl enable vnstat 2>/dev/null || true
                        sudo systemctl start vnstat 2>/dev/null || true
                        log_success "vnstat 已安装并启动！"
                        echo -e "  ${YELLOW}提示: 需要运行一段时间才会有统计数据${NC}"
                    fi
                    press_any_key
                    continue
                fi

                echo -e "  ${GREEN}✓${NC} vnstat 已安装"
                echo ""
                echo -e "  ${WHITE}${BOLD}选择查看方式:${NC}"
                echo -e "  ${CYAN}1.${NC} 总览 (默认)"
                echo -e "  ${CYAN}2.${NC} 按月统计"
                echo -e "  ${CYAN}3.${NC} 按天统计"
                echo -e "  ${CYAN}4.${NC} 按小时统计"
                echo -e "  ${CYAN}5.${NC} 实时流量"
                echo ""
                read -p "请选择 [1-5]: " vnstat_choice </dev/tty
                echo ""
                case $vnstat_choice in
                    1) vnstat ;;
                    2) vnstat -m ;;
                    3) vnstat -d ;;
                    4) vnstat -h ;;
                    5)
                        log_info "实时流量监控中... 按 Ctrl+C 退出"
                        echo ""
                        vnstat -l
                        ;;
                    *) vnstat ;;
                esac
                press_any_key
                ;;
            10)
                show_system_diagnostics
                ;;
            11)
                show_config_backup_menu
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
