# ================== 虾和马 AI 工具 ==================

find_hermes_cmd() {
    local hermes_cmd
    hermes_cmd="$(command -v hermes 2>/dev/null || true)"
    if [[ -n "$hermes_cmd" ]]; then
        echo "$hermes_cmd"
        return 0
    fi

    local candidate
    for candidate in "$HOME/.local/bin/hermes" "$HOME/.cargo/bin/hermes" "/usr/local/bin/hermes"; do
        if [[ -x "$candidate" ]]; then
            echo "$candidate"
            return 0
        fi
    done

    return 1
}

show_openclaw_status_line() {
    if command -v openclaw &>/dev/null; then
        local oc_ver
        oc_ver=$(openclaw --version 2>/dev/null || echo "未知版本")
        echo -e "  ${GREEN}✓${NC} OpenClaw: ${oc_ver}"
    elif docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^openclaw$"; then
        local oc_status
        oc_status=$(docker inspect -f '{{.State.Status}}' openclaw 2>/dev/null || echo "未知")
        echo -e "  ${GREEN}✓${NC} OpenClaw: Docker (${oc_status})"
    else
        echo -e "  ${GRAY}○${NC} OpenClaw: 未安装"
    fi
}

show_hermes_status_line() {
    local hermes_cmd
    if hermes_cmd="$(find_hermes_cmd)"; then
        local hermes_ver
        hermes_ver=$("$hermes_cmd" --version 2>/dev/null || echo "已安装")
        echo -e "  ${GREEN}✓${NC} Hermes Agent: ${hermes_ver}"
    else
        echo -e "  ${GRAY}○${NC} Hermes Agent: 未安装"
    fi
}

run_hermes_cmd() {
    local hermes_cmd
    if ! hermes_cmd="$(find_hermes_cmd)"; then
        log_error "Hermes Agent 未安装，请先执行一键安装。"
        return 1
    fi

    "$hermes_cmd" "$@"
}

install_hermes_agent() {
    clear
    draw_title_line "Hermes Agent 一键安装" 50
    echo ""
    echo -e "  ${WHITE}${BOLD}Hermes Agent - Nous Research 的自托管 AI Agent${NC}"
    echo -e "  ${DIM}官方安装脚本: https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh${NC}"
    echo -e "  ${DIM}安装后可运行 hermes setup 配置模型、工具和消息网关。${NC}"
    echo ""

    if [[ $EUID -eq 0 ]]; then
        echo -e "  ${YELLOW}⚠ 当前正在以 root 运行，Hermes 会安装到 root 用户环境。${NC}"
        echo -e "  ${YELLOW}⚠ 更推荐用日常登录用户运行 fish 后再安装 Hermes。${NC}"
        echo ""
        read -p "仍要继续安装到 root 用户环境? (y/n): " root_confirm </dev/tty
        if [[ "$root_confirm" != "y" && "$root_confirm" != "Y" ]]; then
            log_info "操作已取消"
            press_any_key
            return 0
        fi
    fi

    if ! command -v git &>/dev/null; then
        log_warning "未检测到 git，Hermes 安装过程通常需要它。"
        read -p "是否自动安装 git? (y/n): " install_git </dev/tty
        if [[ "$install_git" == "y" || "$install_git" == "Y" ]]; then
            pkg_update && pkg_install git || {
                log_error "git 安装失败，请手动安装后重试。"
                press_any_key
                return 1
            }
        else
            log_info "操作已取消"
            press_any_key
            return 0
        fi
    fi

    echo ""
    read -p "确认下载并运行 Hermes 官方安装脚本? (y/n): " confirm </dev/tty
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "操作已取消"
        press_any_key
        return 0
    fi

    local tmp_file
    tmp_file="$(mktemp /tmp/hermes-agent-install.XXXXXX)"

    log_info "正在下载安装脚本..."
    if ! curl -fsSL "https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh" -o "$tmp_file"; then
        log_error "下载安装脚本失败，请检查网络或 GitHub 访问。"
        rm -f "$tmp_file"
        press_any_key
        return 1
    fi

    chmod +x "$tmp_file"
    log_info "开始安装 Hermes Agent..."
    if bash "$tmp_file"; then
        rm -f "$tmp_file"
        echo ""
        log_success "Hermes Agent 安装脚本执行完成。"
    else
        rm -f "$tmp_file"
        echo ""
        log_error "Hermes Agent 安装失败，请查看上方输出。"
        press_any_key
        return 1
    fi

    local hermes_cmd
    if hermes_cmd="$(find_hermes_cmd)"; then
        echo ""
        log_success "检测到 Hermes 命令: ${hermes_cmd}"
        echo -e "  ${CYAN}$("$hermes_cmd" --version 2>/dev/null || echo "hermes")${NC}"
        echo ""
        read -p "是否现在运行 hermes setup 配置向导? (y/n): " run_setup </dev/tty
        if [[ "$run_setup" == "y" || "$run_setup" == "Y" ]]; then
            "$hermes_cmd" setup
        else
            echo ""
            echo -e "  ${YELLOW}稍后可手动运行:${NC}"
            echo -e "  ${CYAN}hermes setup${NC}"
        fi
    else
        echo ""
        log_warning "安装脚本已完成，但当前 PATH 中还未检测到 hermes。"
        echo -e "  ${DIM}可尝试重新登录终端，或执行: source ~/.bashrc${NC}"
        echo -e "  ${DIM}常见路径: ~/.local/bin/hermes${NC}"
    fi

    press_any_key
}

show_hermes_menu() {
    while true; do
        clear
        draw_title_line "Hermes Agent" 50
        echo ""
        echo -e "  ${WHITE}${BOLD}Hermes Agent - 自托管、带记忆和技能系统的 AI Agent${NC}"
        echo -e "  ${DIM}https://github.com/NousResearch/hermes-agent${NC}"
        echo ""
        show_hermes_status_line
        echo ""

        draw_menu_item "1" "📦" "一键安装 / 重装 Hermes Agent"
        draw_menu_item "2" "🧭" "运行 setup 配置向导"
        draw_menu_item "3" "💬" "启动终端聊天"
        draw_menu_item "4" "🌉" "启动消息网关"
        draw_menu_item "5" "🩺" "运行 doctor 诊断"
        draw_menu_item "6" "🔁" "从 OpenClaw 迁移配置"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回虾和马"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-6]: )" hermes_choice </dev/tty

        case $hermes_choice in
            1) install_hermes_agent ;;
            2) clear; run_hermes_cmd setup; press_any_key ;;
            3) clear; run_hermes_cmd; press_any_key ;;
            4) clear; run_hermes_cmd gateway; press_any_key ;;
            5) clear; run_hermes_cmd doctor; press_any_key ;;
            6) clear; run_hermes_cmd claw migrate; press_any_key ;;
            0) break ;;
            *) log_error "无效输入。"; press_any_key ;;
        esac
    done
}

show_ai_agent_menu() {
    while true; do
        clear
        draw_title_line "虾和马" 50
        echo ""
        echo -e "  ${WHITE}${BOLD}AI Agent 工具集合${NC}"
        echo -e "  ${DIM}OpenClaw 和 Hermes Agent 放在这里统一管理。${NC}"
        echo ""
        show_openclaw_status_line
        show_hermes_status_line
        echo ""

        draw_menu_item "1" "🤖" "OpenClaw AI 助手"
        draw_menu_item "2" "☤" "Hermes Agent"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回主菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-2]: )" ai_choice </dev/tty

        case $ai_choice in
            1) show_openclaw_menu ;;
            2) show_hermes_menu ;;
            0) break ;;
            *) log_error "无效输入。"; press_any_key ;;
        esac
    done
}
