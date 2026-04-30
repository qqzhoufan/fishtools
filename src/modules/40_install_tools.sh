# ================== fail2ban 管理子菜单 ==================
install_fail2ban_menu() {
    while true; do
        clear
        draw_title_line "fail2ban 安全防护" 50
        echo ""

        # 显示当前状态
        if command -v fail2ban-client &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} fail2ban 已安装"
            if systemctl is-active --quiet fail2ban 2>/dev/null; then
                echo -e "  ${GREEN}●${NC} 运行状态: ${GREEN}运行中${NC}"
                local banned=$(sudo fail2ban-client status sshd 2>/dev/null | grep "Currently banned" | awk '{print $NF}')
                echo -e "  ${CYAN}当前封禁:${NC} ${banned:-0} 个 IP"
            else
                echo -e "  ${RED}●${NC} 运行状态: ${RED}已停止${NC}"
            fi
        else
            echo -e "  ${GRAY}○${NC} fail2ban 未安装"
        fi
        echo ""

        draw_menu_item "1" "📦" "安装 fail2ban"
        draw_menu_item "2" "📋" "查看封禁列表"
        draw_menu_item "3" "🔓" "解封指定 IP"
        draw_menu_item "4" "📊" "查看状态"
        draw_menu_item "5" "🗑️" "卸载 fail2ban"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回上级菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-5]: )" f2b_choice </dev/tty

        case $f2b_choice in
            1)
                clear
                draw_title_line "安装 fail2ban" 50
                echo ""
                log_info "正在安装 fail2ban..."
                pkg_update && pkg_install fail2ban

                # 自动检测日志后端并生成对应配置
                local f2b_backend=""
                local f2b_logpath=""
                if [[ -f /var/log/auth.log ]]; then
                    # Debian/Ubuntu 传统 rsyslog 模式
                    f2b_backend="auto"
                    f2b_logpath="logpath = /var/log/auth.log"
                elif [[ -f /var/log/secure ]]; then
                    # CentOS/RHEL/Fedora
                    f2b_backend="auto"
                    f2b_logpath="logpath = /var/log/secure"
                else
                    # Debian 12+/现代 systemd 系统 - 使用 journald
                    f2b_backend="systemd"
                    f2b_logpath=""
                fi

                sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[sshd]
enabled = true
port = ssh
filter = sshd
backend = ${f2b_backend}
${f2b_logpath}
maxretry = 5
bantime = 3600
findtime = 600
EOF
                sudo systemctl enable fail2ban
                sudo systemctl restart fail2ban
                log_success "fail2ban 安装完成！"
                echo ""
                echo -e "  ${CYAN}配置说明:${NC}"
                echo -e "    • 5 次失败后封禁 IP"
                echo -e "    • 封禁时长: 1 小时"
                echo -e "    • 日志后端: ${f2b_backend}"
                echo -e "    • 配置文件: /etc/fail2ban/jail.local"
                press_any_key
                ;;
            2)
                clear
                draw_title_line "封禁列表" 50
                echo ""
                if ! command -v fail2ban-client &>/dev/null; then
                    log_error "fail2ban 未安装！"
                    press_any_key
                    continue
                fi
                log_info "当前被封禁的 IP 列表:"
                echo ""
                sudo fail2ban-client status sshd 2>/dev/null || echo "  暂无封禁记录"
                press_any_key
                ;;
            3)
                clear
                draw_title_line "解封 IP" 50
                echo ""
                if ! command -v fail2ban-client &>/dev/null; then
                    log_error "fail2ban 未安装！"
                    press_any_key
                    continue
                fi
                read -p "请输入要解封的 IP: " unban_ip </dev/tty
                if [[ -n "$unban_ip" ]]; then
                    sudo fail2ban-client set sshd unbanip "$unban_ip" && \
                        log_success "已解封 IP: $unban_ip" || \
                        log_error "解封失败，IP 可能不在封禁列表中"
                fi
                press_any_key
                ;;
            4)
                clear
                draw_title_line "fail2ban 状态" 50
                echo ""
                sudo systemctl status fail2ban --no-pager || true
                press_any_key
                ;;
            5)
                clear
                draw_title_line "卸载 fail2ban" 50
                echo ""
                if ! command -v fail2ban-client &>/dev/null; then
                    log_warning "fail2ban 未安装，无需卸载。"
                    press_any_key
                    continue
                fi
                read -p "确认卸载 fail2ban? (y/n): " confirm </dev/tty
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    sudo systemctl stop fail2ban 2>/dev/null || true
                    pkg_remove fail2ban
                    log_success "fail2ban 已卸载！"
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

# ================== 系统监控工具子菜单 ==================
install_monitor_menu() {
    while true; do
        clear
        draw_title_line "系统监控工具" 50
        echo ""

        # 显示当前状态
        if command -v htop &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} htop 已安装"
        else
            echo -e "  ${GRAY}○${NC} htop 未安装"
        fi
        if command -v btop &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} btop 已安装"
        else
            echo -e "  ${GRAY}○${NC} btop 未安装"
        fi
        echo ""

        echo -e "  ${CYAN}htop${NC}  - 经典轻量，兼容性好"
        echo -e "  ${CYAN}btop${NC}  - 现代美观，功能丰富"
        echo ""
        draw_menu_item "1" "📦" "安装 htop"
        draw_menu_item "2" "📦" "安装 btop"
        draw_menu_item "3" "▶️" "运行 htop"
        draw_menu_item "4" "▶️" "运行 btop"
        draw_menu_item "5" "🗑️" "卸载 htop/btop"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回上级菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-5]: )" mon_choice </dev/tty

        case $mon_choice in
            1)
                clear
                log_info "正在安装 htop..."
                pkg_update && pkg_install htop
                log_success "htop 安装完成！运行命令: htop"
                press_any_key
                ;;
            2)
                clear
                log_info "正在安装 btop..."
                pkg_update && pkg_install btop 2>/dev/null || {
                    log_warning "包管理器中无 btop，尝试 snap 安装..."
                    sudo snap install btop 2>/dev/null || {
                        log_error "btop 安装失败，您的系统可能不支持"
                    }
                }
                command -v btop &>/dev/null && log_success "btop 安装完成！运行命令: btop"
                press_any_key
                ;;
            3)
                if command -v htop &>/dev/null; then
                    htop
                else
                    log_error "htop 未安装，请先安装！"
                    press_any_key
                fi
                ;;
            4)
                if command -v btop &>/dev/null; then
                    btop
                else
                    log_error "btop 未安装，请先安装！"
                    press_any_key
                fi
                ;;
            5)
                clear
                draw_title_line "卸载监控工具" 50
                echo ""
                echo -e "  ${CYAN}1.${NC} 卸载 htop"
                echo -e "  ${CYAN}2.${NC} 卸载 btop"
                echo -e "  ${CYAN}3.${NC} 全部卸载"
                echo ""
                read -p "请选择: " uninstall_choice </dev/tty
                case $uninstall_choice in
                    1) pkg_remove htop && log_success "htop 已卸载" ;;
                    2) pkg_remove btop 2>/dev/null; sudo snap remove btop 2>/dev/null; log_success "btop 已卸载" ;;
                    3) pkg_remove htop btop 2>/dev/null; sudo snap remove btop 2>/dev/null; log_success "已全部卸载" ;;
                esac
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

# ================== tmux 管理子菜单 ==================
install_tmux_menu() {
    while true; do
        clear
        draw_title_line "tmux 终端复用" 50
        echo ""

        # 显示当前状态
        if command -v tmux &>/dev/null; then
            local tmux_ver=$(tmux -V 2>/dev/null | awk '{print $2}')
            echo -e "  ${GREEN}✓${NC} tmux 已安装 (${tmux_ver})"
            local sessions=$(tmux ls 2>/dev/null | wc -l)
            echo -e "  ${CYAN}活跃会话:${NC} ${sessions} 个"
        else
            echo -e "  ${GRAY}○${NC} tmux 未安装"
        fi
        echo ""

        draw_menu_item "1" "📦" "安装 tmux"
        draw_menu_item "2" "➕" "新建会话"
        draw_menu_item "3" "📋" "列出会话"
        draw_menu_item "4" "🔗" "连接会话"
        draw_menu_item "5" "❓" "使用帮助"
        draw_menu_item "6" "🗑️" "卸载 tmux"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回上级菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-6]: )" tmux_choice </dev/tty

        case $tmux_choice in
            1)
                clear
                log_info "正在安装 tmux..."
                pkg_update && pkg_install tmux
                log_success "tmux 安装完成！"
                press_any_key
                ;;
            2)
                if ! command -v tmux &>/dev/null; then
                    log_error "tmux 未安装，请先安装！"
                    press_any_key
                    continue
                fi
                read -p "请输入会话名称: " session_name </dev/tty
                if [[ -n "$session_name" ]]; then
                    tmux new-session -d -s "$session_name"
                    log_success "会话 '$session_name' 已创建"
                    read -p "是否立即进入? (y/n): " enter </dev/tty
                    [[ "$enter" == "y" || "$enter" == "Y" ]] && tmux attach -t "$session_name"
                fi
                press_any_key
                ;;
            3)
                clear
                draw_title_line "tmux 会话列表" 50
                echo ""
                if ! command -v tmux &>/dev/null; then
                    log_error "tmux 未安装！"
                else
                    tmux ls 2>/dev/null || echo "  暂无活跃会话"
                fi
                press_any_key
                ;;
            4)
                if ! command -v tmux &>/dev/null; then
                    log_error "tmux 未安装，请先安装！"
                    press_any_key
                    continue
                fi
                echo ""
                tmux ls 2>/dev/null || { echo "  暂无活跃会话"; press_any_key; continue; }
                echo ""
                read -p "请输入要连接的会话名称: " attach_name </dev/tty
                [[ -n "$attach_name" ]] && tmux attach -t "$attach_name"
                ;;
            5)
                clear
                draw_title_line "tmux 使用帮助" 50
                echo ""
                echo -e "  ${WHITE}${BOLD}常用快捷键 (先按 Ctrl+B，再按以下键)${NC}"
                echo ""
                echo -e "  ${CYAN}d${NC}     - 挂起会话（后台运行）"
                echo -e "  ${CYAN}c${NC}     - 新建窗口"
                echo -e "  ${CYAN}n/p${NC}   - 下一个/上一个窗口"
                echo -e "  ${CYAN}%${NC}     - 左右分屏"
                echo -e "  ${CYAN}\"${NC}     - 上下分屏"
                echo -e "  ${CYAN}方向键${NC} - 切换分屏"
                echo -e "  ${CYAN}x${NC}     - 关闭当前面板"
                echo ""
                echo -e "  ${WHITE}${BOLD}常用命令${NC}"
                echo ""
                echo -e "  ${CYAN}tmux new -s 名称${NC}     创建会话"
                echo -e "  ${CYAN}tmux ls${NC}              列出会话"
                echo -e "  ${CYAN}tmux attach -t 名称${NC}  连接会话"
                echo -e "  ${CYAN}tmux kill-session -t 名称${NC}  删除会话"
                press_any_key
                ;;
            6)
                clear
                if ! command -v tmux &>/dev/null; then
                    log_warning "tmux 未安装，无需卸载。"
                    press_any_key
                    continue
                fi
                read -p "确认卸载 tmux? (y/n): " confirm </dev/tty
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    pkg_remove tmux
                    log_success "tmux 已卸载！"
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

# ================== ufw 防火墙管理 ==================
install_ufw_menu() {
    while true; do
        clear
        draw_title_line "ufw 防火墙" 50
        echo ""

        # 显示当前状态
        if command -v ufw &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} ufw 已安装"
            local status=$(sudo ufw status 2>/dev/null | head -1)
            if echo "$status" | grep -q "active"; then
                echo -e "  ${GREEN}●${NC} 防火墙状态: ${GREEN}已启用${NC}"
            else
                echo -e "  ${RED}●${NC} 防火墙状态: ${RED}未启用${NC}"
            fi
        else
            echo -e "  ${GRAY}○${NC} ufw 未安装"
        fi
        echo ""

        draw_menu_item "1" "📦" "安装 ufw"
        draw_menu_item "2" "✅" "启用防火墙"
        draw_menu_item "3" "❌" "禁用防火墙"
        draw_menu_item "4" "➕" "开放端口"
        draw_menu_item "5" "➖" "关闭端口"
        draw_menu_item "6" "📋" "查看规则"
        draw_menu_item "7" "🔄" "重置规则"
        draw_menu_item "8" "🗑️" "卸载 ufw"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回上级菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-8]: )" ufw_choice </dev/tty

        case $ufw_choice in
            1)
                clear
                log_info "正在安装 ufw..."
                pkg_update && pkg_install ufw
                log_success "ufw 安装完成！"
                echo ""
                echo -e "  ${YELLOW}提示: 启用前请先开放 SSH 端口 (22)${NC}"
                press_any_key
                ;;
            2)
                clear
                draw_title_line "启用 ufw" 50
                echo ""
                if ! command -v ufw &>/dev/null; then
                    log_error "ufw 未安装！"
                    press_any_key
                    continue
                fi
                echo -e "  ${YELLOW}⚠ 警告：启用防火墙前请确保已开放 SSH 端口！${NC}"
                echo ""
                read -p "是否先开放 SSH 端口 22? (y/n): " open_ssh </dev/tty
                if [[ "$open_ssh" == "y" || "$open_ssh" == "Y" ]]; then
                    sudo ufw allow 22/tcp
                    log_success "已开放 SSH 端口 22"
                fi
                echo ""
                read -p "确认启用防火墙? (y/n): " confirm </dev/tty
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    sudo ufw --force enable
                    log_success "防火墙已启用！"
                fi
                press_any_key
                ;;
            3)
                sudo ufw disable
                log_success "防火墙已禁用"
                press_any_key
                ;;
            4)
                clear
                draw_title_line "开放端口" 50
                echo ""
                if ! command -v ufw &>/dev/null; then
                    log_error "ufw 未安装！"
                    press_any_key
                    continue
                fi
                read -p "请输入要开放的端口 (如 80 或 80/tcp): " port </dev/tty
                if [[ -n "$port" && "$port" =~ ^[0-9]+(/[a-z]+)?$ ]]; then
                    sudo ufw allow "$port"
                    log_success "已开放端口: $port"
                elif [[ -n "$port" ]]; then
                    log_error "无效端口格式！示例: 80 或 443/tcp"
                fi
                press_any_key
                ;;
            5)
                clear
                draw_title_line "关闭端口" 50
                echo ""
                if ! command -v ufw &>/dev/null; then
                    log_error "ufw 未安装！"
                    press_any_key
                    continue
                fi
                read -p "请输入要关闭的端口 (如 80 或 80/tcp): " port </dev/tty
                if [[ -n "$port" && "$port" =~ ^[0-9]+(/[a-z]+)?$ ]]; then
                    sudo ufw deny "$port"
                    log_success "已关闭端口: $port"
                elif [[ -n "$port" ]]; then
                    log_error "无效端口格式！示例: 80 或 443/tcp"
                fi
                press_any_key
                ;;
            6)
                clear
                draw_title_line "ufw 规则列表" 50
                echo ""
                if ! command -v ufw &>/dev/null; then
                    log_error "ufw 未安装！"
                else
                    sudo ufw status numbered
                fi
                press_any_key
                ;;
            7)
                clear
                draw_title_line "重置 ufw 规则" 50
                echo ""
                echo -e "  ${RED}${BOLD}⚠ 警告：将删除所有防火墙规则！${NC}"
                echo ""
                read -p "请输入 'yes' 确认重置: " confirm </dev/tty
                if [[ "$confirm" == "yes" ]]; then
                    sudo ufw --force reset
                    log_success "ufw 规则已重置！"
                else
                    log_info "操作已取消。"
                fi
                press_any_key
                ;;
            8)
                clear
                if ! command -v ufw &>/dev/null; then
                    log_warning "ufw 未安装，无需卸载。"
                    press_any_key
                    continue
                fi
                read -p "确认卸载 ufw? (y/n): " confirm </dev/tty
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    sudo ufw --force disable 2>/dev/null || true
                    pkg_remove ufw
                    log_success "ufw 已卸载！"
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

# ================== 安全工具子菜单 ==================
# ================== SSH 安全配置 ==================
ssh_security_menu() {
    while true; do
        clear
        draw_title_line "SSH 安全配置" 50
        echo ""

        # 显示当前状态
        local pass_auth=$(grep -E "^PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
        local pubkey_auth=$(grep -E "^PubkeyAuthentication" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')

        echo -e "  ${WHITE}${BOLD}当前 SSH 配置状态${NC}"
        if [[ "$pass_auth" == "no" ]]; then
            echo -e "  ${RED}●${NC} 密码登录: ${RED}已禁用${NC}"
        else
            echo -e "  ${GREEN}●${NC} 密码登录: ${GREEN}已启用${NC}"
        fi
        if [[ "$pubkey_auth" == "no" ]]; then
            echo -e "  ${RED}●${NC} 密钥登录: ${RED}已禁用${NC}"
        else
            echo -e "  ${GREEN}●${NC} 密钥登录: ${GREEN}已启用${NC}"
        fi

        if [[ -f ~/.ssh/authorized_keys ]]; then
            local key_count=$(wc -l < ~/.ssh/authorized_keys 2>/dev/null || echo 0)
            echo -e "  ${CYAN}已授权密钥:${NC} ${key_count} 个"
        else
            echo -e "  ${CYAN}已授权密钥:${NC} 0 个"
        fi
        echo ""

        draw_menu_item "1" "🔑" "生成 SSH 密钥对"
        draw_menu_item "2" "📥" "添加公钥到授权列表"
        draw_menu_item "3" "🔒" "禁用密码登录 (仅密钥)"
        draw_menu_item "4" "🔓" "恢复密码登录"
        draw_menu_item "5" "📋" "查看当前公钥"
        draw_menu_item "6" "📋" "查看当前私钥"
        draw_menu_item "7" "🗑️" "删除密钥文件"
        draw_menu_item "8" "❓" "使用帮助"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回上级菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-8]: )" ssh_choice </dev/tty

        case $ssh_choice in
            1)
                clear
                draw_title_line "生成 SSH 密钥对" 50
                echo ""
                if [[ -f ~/.ssh/id_rsa || -f ~/.ssh/id_ed25519 ]]; then
                    log_warning "检测到已存在密钥文件！"
                    read -p "是否覆盖生成新密钥? (y/n): " confirm </dev/tty
                    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && { press_any_key; continue; }
                fi

                echo ""
                echo -e "  ${CYAN}选择密钥类型:${NC}"
                echo -e "  1. ED25519 (推荐，更安全更快)"
                echo -e "  2. RSA 4096 (兼容性好)"
                echo ""
                read -p "请选择 [1/2]: " key_type </dev/tty

                echo ""
                echo -e "  ${CYAN}是否为私钥设置密码保护？${NC}"
                echo -e "  ${GRAY}(设置密码后，每次使用私钥都需要输入密码)${NC}"
                echo ""
                read -p "设置密码保护? (y/n): " use_pass </dev/tty

                local passphrase=""
                if [[ "$use_pass" == "y" || "$use_pass" == "Y" ]]; then
                    echo ""
                    read -s -p "请输入密钥密码: " passphrase </dev/tty
                    echo ""
                    read -s -p "请再次确认密码: " passphrase2 </dev/tty
                    echo ""
                    if [[ "$passphrase" != "$passphrase2" ]]; then
                        log_error "两次密码不一致！"
                        press_any_key
                        continue
                    fi
                fi

                mkdir -p ~/.ssh
                chmod 700 ~/.ssh

                local pubkey_file=""
                if [[ "$key_type" == "2" ]]; then
                    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "$passphrase" -C "fishtools-$(date +%Y%m%d)"
                    pubkey_file=~/.ssh/id_rsa.pub
                    log_success "RSA 密钥对已生成！"
                    echo ""
                    echo -e "  ${CYAN}私钥位置:${NC} ~/.ssh/id_rsa"
                    echo -e "  ${CYAN}公钥位置:${NC} ~/.ssh/id_rsa.pub"
                else
                    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "$passphrase" -C "fishtools-$(date +%Y%m%d)"
                    pubkey_file=~/.ssh/id_ed25519.pub
                    log_success "ED25519 密钥对已生成！"
                    echo ""
                    echo -e "  ${CYAN}私钥位置:${NC} ~/.ssh/id_ed25519"
                    echo -e "  ${CYAN}公钥位置:${NC} ~/.ssh/id_ed25519.pub"
                fi

                # 自动将公钥添加到 authorized_keys
                cat "$pubkey_file" >> ~/.ssh/authorized_keys
                chmod 600 ~/.ssh/authorized_keys
                echo ""
                echo -e "  ${GREEN}✓ 公钥已自动添加到 authorized_keys${NC}"

                # 自动启用 sshd 公钥认证配置
                log_info "正在配置 sshd 以启用公钥认证..."

                # 备份 sshd_config
                sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d%H%M%S) 2>/dev/null || true

                # 启用 PubkeyAuthentication
                sudo sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
                grep -q "^PubkeyAuthentication" /etc/ssh/sshd_config || echo "PubkeyAuthentication yes" | sudo tee -a /etc/ssh/sshd_config > /dev/null

                # 确保 AuthorizedKeysFile 配置正确
                sudo sed -i 's/^#*AuthorizedKeysFile.*/AuthorizedKeysFile .ssh\/authorized_keys/' /etc/ssh/sshd_config
                grep -q "^AuthorizedKeysFile" /etc/ssh/sshd_config || echo "AuthorizedKeysFile .ssh/authorized_keys" | sudo tee -a /etc/ssh/sshd_config > /dev/null

                # 重启 sshd 服务使配置生效
                sudo systemctl restart sshd 2>/dev/null || sudo service ssh restart 2>/dev/null || true

                echo -e "  ${GREEN}✓ sshd 公钥认证已启用并重启服务${NC}"
                echo ""
                if [[ -n "$passphrase" ]]; then
                    echo -e "  ${GREEN}✓ 私钥已设置密码保护${NC}"
                else
                    echo -e "  ${YELLOW}○ 私钥无密码保护${NC}"
                fi

                # 获取服务器 IP 和当前用户
                local server_ip
                server_ip=$(get_primary_access_host)
                [[ -z "$server_ip" ]] && server_ip="<服务器IP>"
                local current_user=$(whoami)
                local key_name="id_ed25519"
                [[ "$key_type" == "2" ]] && key_name="id_rsa"

                echo ""
                echo -e "  ${WHITE}${BOLD}═══════════════════════════════════════════${NC}"
                echo -e "  ${WHITE}${BOLD}下一步操作 (必读)：${NC}"
                echo -e "  ${WHITE}${BOLD}═══════════════════════════════════════════${NC}"
                echo ""
                echo -e "  ${CYAN}步骤 1:${NC} 复制下方私钥内容到本地文件"
                echo -e "         保存为: ${YELLOW}~/.ssh/${key_name}_server${NC}"
                echo ""
                echo -e "  ${CYAN}步骤 2:${NC} 在本地终端设置私钥权限"
                echo -e "         ${WHITE}chmod 600 ~/.ssh/${key_name}_server${NC}"
                echo ""
                echo -e "  ${CYAN}步骤 3:${NC} 测试密钥登录 (在本地执行)"
                echo -e "         ${WHITE}ssh -i ~/.ssh/${key_name}_server ${current_user}@${server_ip}${NC}"
                echo ""
                echo -e "  ${CYAN}步骤 4:${NC} 确认登录成功后，可禁用密码登录"
                echo -e "         使用菜单选项 3「禁用密码登录」"
                echo ""
                echo -e "  ${RED}${BOLD}⚠ 重要提示：${NC}"
                echo -e "  ${YELLOW}• 私钥必须下载到本地才能使用！${NC}"
                echo -e "  ${YELLOW}• 请妥善保管私钥，丢失后无法恢复！${NC}"
                echo -e "  ${YELLOW}• 禁用密码登录前请务必测试密钥登录！${NC}"
                echo ""
                read -p "是否立即显示私钥内容? (y/n): " show_key </dev/tty
                if [[ "$show_key" == "y" || "$show_key" == "Y" ]]; then
                    echo ""
                    echo -e "  ${WHITE}${BOLD}私钥内容 (请完整复制保存):${NC}"
                    echo -e "  ${GRAY}─────────────── 开始 ───────────────${NC}"
                    if [[ "$key_type" == "2" ]]; then
                        cat ~/.ssh/id_rsa
                    else
                        cat ~/.ssh/id_ed25519
                    fi
                    echo -e "  ${GRAY}─────────────── 结束 ───────────────${NC}"
                fi
                press_any_key
                ;;
            2)
                clear
                draw_title_line "添加公钥" 50
                echo ""
                echo -e "  ${WHITE}请粘贴您的公钥内容 (ssh-rsa 或 ssh-ed25519 开头):${NC}"
                echo ""
                read -p "公钥: " pubkey </dev/tty

                if [[ -z "$pubkey" ]]; then
                    log_error "公钥不能为空！"
                    press_any_key
                    continue
                fi

                if ! echo "$pubkey" | grep -qE "^ssh-(rsa|ed25519|ecdsa)"; then
                    log_error "公钥格式不正确！"
                    press_any_key
                    continue
                fi

                mkdir -p ~/.ssh
                chmod 700 ~/.ssh
                echo "$pubkey" >> ~/.ssh/authorized_keys
                chmod 600 ~/.ssh/authorized_keys
                log_success "公钥已添加到授权列表！"
                press_any_key
                ;;
            3)
                clear
                draw_title_line "禁用密码登录" 50
                echo ""
                echo -e "  ${RED}${BOLD}⚠ 警告：禁用密码登录后只能用密钥登录！${NC}"
                echo ""
                echo -e "  ${YELLOW}请确保：${NC}"
                echo -e "    1. 已配置密钥登录并测试成功"
                echo -e "    2. 已保存私钥到本地"
                echo ""

                if [[ ! -f ~/.ssh/authorized_keys ]] || [[ ! -s ~/.ssh/authorized_keys ]]; then
                    log_error "未检测到已授权的公钥！请先添加公钥。"
                    press_any_key
                    continue
                fi

                read -p "请输入 'yes' 确认禁用密码登录: " confirm </dev/tty
                if [[ "$confirm" != "yes" ]]; then
                    log_info "操作已取消。"
                    press_any_key
                    continue
                fi

                # 备份配置
                sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d%H%M%S)

                # 修改配置
                sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
                sudo sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
                sudo sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config

                # 如果配置项不存在则添加
                grep -q "^PasswordAuthentication" /etc/ssh/sshd_config || echo "PasswordAuthentication no" | sudo tee -a /etc/ssh/sshd_config
                grep -q "^PubkeyAuthentication" /etc/ssh/sshd_config || echo "PubkeyAuthentication yes" | sudo tee -a /etc/ssh/sshd_config

                sudo systemctl restart sshd
                log_success "密码登录已禁用，仅允许密钥登录！"
                echo ""
                echo -e "  ${GREEN}配置已备份到 /etc/ssh/sshd_config.bak.*${NC}"
                press_any_key
                ;;
            4)
                clear
                draw_title_line "恢复密码登录" 50
                echo ""
                read -p "确认恢复密码登录? (y/n): " confirm </dev/tty
                if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                    log_info "操作已取消。"
                    press_any_key
                    continue
                fi

                sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
                sudo systemctl restart sshd
                log_success "密码登录已恢复！"
                press_any_key
                ;;
            5)
                clear
                draw_title_line "当前公钥" 50
                echo ""
                if [[ -f ~/.ssh/id_ed25519.pub ]]; then
                    echo -e "  ${CYAN}ED25519 公钥:${NC}"
                    echo ""
                    cat ~/.ssh/id_ed25519.pub
                    echo ""
                elif [[ -f ~/.ssh/id_rsa.pub ]]; then
                    echo -e "  ${CYAN}RSA 公钥:${NC}"
                    echo ""
                    cat ~/.ssh/id_rsa.pub
                    echo ""
                else
                    log_warning "未找到公钥文件，请先生成密钥对。"
                fi
                echo ""
                echo -e "  ${GRAY}提示: 将此公钥添加到其他服务器即可免密登录${NC}"
                press_any_key
                ;;
            6)
                clear
                draw_title_line "当前私钥" 50
                echo ""
                echo -e "  ${RED}${BOLD}⚠ 警告：私钥是敏感信息，请勿泄露！${NC}"
                echo ""
                if [[ -f ~/.ssh/id_ed25519 ]]; then
                    echo -e "  ${CYAN}ED25519 私钥:${NC}"
                    echo -e "  ${GRAY}--- 开始 ---${NC}"
                    cat ~/.ssh/id_ed25519
                    echo -e "  ${GRAY}--- 结束 ---${NC}"
                elif [[ -f ~/.ssh/id_rsa ]]; then
                    echo -e "  ${CYAN}RSA 私钥:${NC}"
                    echo -e "  ${GRAY}--- 开始 ---${NC}"
                    cat ~/.ssh/id_rsa
                    echo -e "  ${GRAY}--- 结束 ---${NC}"
                else
                    log_warning "未找到私钥文件，请先生成密钥对。"
                fi
                press_any_key
                ;;
            7)
                clear
                draw_title_line "删除密钥文件" 50
                echo ""
                echo -e "  ${WHITE}${BOLD}检测到的密钥文件：${NC}"
                echo ""
                local has_keys=0
                [[ -f ~/.ssh/id_ed25519 ]] && { echo -e "  • ~/.ssh/id_ed25519 (私钥)"; has_keys=1; }
                [[ -f ~/.ssh/id_ed25519.pub ]] && { echo -e "  • ~/.ssh/id_ed25519.pub (公钥)"; has_keys=1; }
                [[ -f ~/.ssh/id_rsa ]] && { echo -e "  • ~/.ssh/id_rsa (私钥)"; has_keys=1; }
                [[ -f ~/.ssh/id_rsa.pub ]] && { echo -e "  • ~/.ssh/id_rsa.pub (公钥)"; has_keys=1; }
                [[ -f ~/.ssh/authorized_keys ]] && echo -e "  • ~/.ssh/authorized_keys (授权公钥列表)"

                if [[ $has_keys -eq 0 ]]; then
                    echo -e "  ${GRAY}未找到密钥文件${NC}"
                    press_any_key
                    continue
                fi

                echo ""
                echo -e "  ${CYAN}选择要删除的内容:${NC}"
                echo -e "  1. 仅删除私钥 (保留公钥)"
                echo -e "  2. 删除密钥对 (私钥+公钥)"
                echo -e "  3. 清空授权公钥列表"
                echo -e "  4. 全部删除"
                echo ""
                read -p "请选择 [1-4]: " del_choice </dev/tty

                case $del_choice in
                    1)
                        rm -f ~/.ssh/id_ed25519 ~/.ssh/id_rsa 2>/dev/null
                        log_success "私钥已删除"
                        ;;
                    2)
                        rm -f ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub ~/.ssh/id_rsa ~/.ssh/id_rsa.pub 2>/dev/null
                        log_success "密钥对已删除"
                        ;;
                    3)
                        rm -f ~/.ssh/authorized_keys 2>/dev/null
                        log_success "授权公钥列表已清空"
                        ;;
                    4)
                        echo ""
                        read -p "请输入 'yes' 确认删除所有密钥文件: " confirm </dev/tty
                        if [[ "$confirm" == "yes" ]]; then
                            rm -f ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub ~/.ssh/id_rsa ~/.ssh/id_rsa.pub ~/.ssh/authorized_keys 2>/dev/null
                            log_success "所有密钥文件已删除"
                        else
                            log_info "操作已取消"
                        fi
                        ;;
                esac
                press_any_key
                ;;
            8)
                clear
                draw_title_line "SSH 密钥登录帮助" 50
                echo ""
                echo -e "  ${WHITE}${BOLD}什么是密钥登录？${NC}"
                echo -e "  使用密钥对（公钥+私钥）代替密码进行 SSH 认证"
                echo -e "  更安全，不怕暴力破解"
                echo ""
                echo -e "  ${WHITE}${BOLD}配置步骤：${NC}"
                echo -e "  1. 生成密钥对（本菜单选项 1）"
                echo -e "  2. 复制私钥到本地电脑保存"
                echo -e "  3. 测试密钥登录是否成功"
                echo -e "  4. 确认无误后禁用密码登录（选项 3）"
                echo ""
                echo -e "  ${WHITE}${BOLD}本地使用私钥登录：${NC}"
                echo -e "  ${CYAN}ssh -i ~/.ssh/id_ed25519 user@server${NC}"
                echo ""
                echo -e "  ${WHITE}${BOLD}Windows 用户：${NC}"
                echo -e "  使用 PuTTY 或 Xshell 导入私钥文件"
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

# ================== 安全工具子菜单 ==================
show_security_menu() {
    while true; do
        clear
        draw_title_line "安全工具" 50
        echo ""
        echo -e "  ${WHITE}${BOLD}VPS 安全防护工具${NC}"
        echo ""
        echo -e "  ${CYAN}fail2ban${NC} - 自动封禁暴力破解 IP"
        echo -e "  ${CYAN}ufw${NC}      - 简化版防火墙管理"
        echo -e "  ${CYAN}SSH 安全${NC} - 密钥登录配置"
        echo ""
        draw_menu_item "1" "🛡️" "fail2ban (防暴力破解)"
        draw_menu_item "2" "🔥" "ufw (防火墙)"
        draw_menu_item "3" "🔑" "SSH 安全 (密钥登录)"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回上级菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-3]: )" sec_choice </dev/tty

        case $sec_choice in
            1) install_fail2ban_menu ;;
            2) install_ufw_menu ;;
            3) ssh_security_menu ;;
            0) break ;;
            *) log_error "无效输入。"; press_any_key ;;
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
        draw_menu_item "2" "🔀" "反代工具 (Nginx / Caddy)"
        draw_menu_item "3" "🛡️" "安全工具 (fail2ban / ufw / SSH密钥)"
        draw_menu_item "4" "📊" "系统监控 (htop / btop)"
        draw_menu_item "5" "🖥️" "tmux (终端复用)"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回主菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-5]: )" install_choice </dev/tty

        case $install_choice in
            1) install_docker_menu ;;
            2) show_proxy_menu ;;
            3) show_security_menu ;;
            4) install_monitor_menu ;;
            5) install_tmux_menu ;;
            0) break ;;
            *) log_error "无效输入。"; press_any_key ;;
        esac
    done
}
