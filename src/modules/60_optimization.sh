download_bbr_tcp_script() {
    local dest="$1"
    local source_name source_url
    local sources=(
        "NekoNeko 主源|https://sh.nekoneko.cloud/tools.sh"
        "Linux-NetSpeed 主线|https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh"
        "Linux-NetSpeed 备用|https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh"
    )

    for source in "${sources[@]}"; do
        source_name="${source%%|*}"
        source_url="${source#*|}"
        log_info "尝试下载 ${source_name}..."
        if curl -fsSL --connect-timeout 10 --max-time 60 --retry 2 --retry-delay 1 "$source_url" -o "$dest" 2>/dev/null || \
           curl -4 -fsSL --connect-timeout 10 --max-time 60 --retry 2 --retry-delay 1 "$source_url" -o "$dest" 2>/dev/null; then
            if bash -n "$dest" 2>/dev/null; then
                log_success "已下载 ${source_name}"
                return 0
            fi
            log_warning "${source_name} 下载完成但语法检查失败，已跳过。"
        else
            log_warning "${source_name} 下载失败"
        fi
    done

    return 1
}

prepare_bbr_tcp_script() {
    local script_file="$1"

    if grep -q "Powered by NNC.SH" "$script_file" 2>/dev/null; then
        sed -i 's|http://sh.nekoneko.cloud|https://sh.nekoneko.cloud|g' "$script_file" 2>/dev/null || true
        sed -i '/^Update_Shell(){/,/^}/c\
Update_Shell(){\
  echo "fishtools 已接管 BBR/TCP 脚本更新，无需在第三方脚本内升级。请返回菜单选择具体优化项。";\
}' "$script_file" 2>/dev/null || true
    fi
}

run_shell_script_as_root_in_dir() {
    local work_dir="$1"
    local script_file="$2"

    if [[ $EUID -eq 0 ]]; then
        (cd "$work_dir" && bash "$script_file")
    else
        (cd "$work_dir" && sudo bash "$script_file")
    fi
}

cleanup_bbr_work_dir() {
    local work_dir="$1"

    case "$work_dir" in
        /tmp/fishtools-bbr-tcp.*|/var/tmp/fishtools-bbr-tcp.*)
            if [[ $EUID -eq 0 ]]; then
                rm -rf -- "$work_dir"
            else
                sudo rm -rf -- "$work_dir" 2>/dev/null || rm -rf -- "$work_dir" 2>/dev/null || true
            fi
            ;;
    esac
}

run_bbr_tcp_optimization() {
    clear
    draw_title_line "BBR/TCP 优化" 50
    echo ""
    echo -e "  ${YELLOW}⚠ 此功能会执行第三方交互式 TCP 优化脚本。${NC}"
    echo -e "  ${DIM}脚本将在临时目录中以 root/sudo 执行，避免 /opt 等目录权限导致失败。${NC}"
    echo -e "  ${DIM}如果第三方脚本下载失败，可使用内置方式开启基础 BBR。${NC}"
    echo ""

    local work_dir tmp_file
    work_dir="$(mktemp -d /var/tmp/fishtools-bbr-tcp.XXXXXX 2>/dev/null || mktemp -d /tmp/fishtools-bbr-tcp.XXXXXX)"
    tmp_file="${work_dir}/tools.sh"

    if download_bbr_tcp_script "$tmp_file"; then
        prepare_bbr_tcp_script "$tmp_file"
        chmod +x "$tmp_file"
        echo ""
        log_info "正在执行 BBR/TCP 优化脚本..."
        run_shell_script_as_root_in_dir "$work_dir" "$tmp_file"
        cleanup_bbr_work_dir "$work_dir"
        return 0
    fi

    cleanup_bbr_work_dir "$work_dir"
    echo ""
    log_error "所有 BBR/TCP 优化脚本源均下载失败。"
    echo ""
    read -p "是否改用内置方式开启基础 BBR? (y/n): " builtin_bbr </dev/tty
    if [[ "$builtin_bbr" == "y" || "$builtin_bbr" == "Y" ]]; then
        echo ""
        enable_builtin_bbr
    fi
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
                run_bbr_tcp_optimization
                press_any_key
                ;;
            2)
                clear
                draw_title_line "SWAP 管理" 50
                echo ""
                log_info "正在下载并执行 SWAP 管理脚本..."
                if curl -fsL https://www.moerats.com/usr/shell/swap.sh -o swap.sh; then
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
                if curl -fsL "https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh" -o menu.sh; then
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
