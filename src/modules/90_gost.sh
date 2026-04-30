# ================== Gost 隧道管理菜单 ==================

# Gost 主菜单
show_gost_menu() {
    # 检查并加载 gost 管理脚本
    if ! source_repo_script "gost_manager.sh" "init_gost_manager"; then
        clear
        draw_title_line "Gost 隧道管理" 50
        echo ""
        log_error "无法加载 gost_manager.sh 脚本"
        echo ""
        echo -e "  ${DIM}已尝试本地 scripts/ 目录和 GitHub 自动下载。${NC}"
        echo -e "  ${DIM}请检查网络连通性，或确认 scripts/gost_manager.sh 存在。${NC}"
        press_any_key
        return 1
    fi

    # 检查 jq 是否安装
    if ! command -v jq &> /dev/null; then
        clear
        draw_title_line "Gost 隧道管理" 50
        echo ""
        log_error "缺少必要依赖 jq，正在尝试安装..."
        echo ""
        pkg_update && pkg_install jq

        if ! command -v jq &> /dev/null; then
            log_error "jq 安装失败，无法使用 Gost 管理功能"
            press_any_key
            return 1
        fi
        log_success "jq 安装成功"
    fi

    # 初始化 gost 管理器
    init_gost_manager

    while true; do
        clear
        draw_title_line "Gost 隧道管理" 50
        echo ""

        echo -e "  ${WHITE}${BOLD}本地配置模式（推荐）${NC}"
        draw_menu_item "1" "🎯" "配置本机为落地鸡"
        draw_menu_item "2" "🚀" "配置本机为线路鸡"
        draw_menu_item "3" "📋" "查看本机配置"
        draw_menu_item "4" "▶️" "启动/停止服务"
        draw_menu_item "5" "🗑️" "清除本机配置"
        echo ""

        echo -e "  ${WHITE}${BOLD}中心化管理模式（高级）${NC}"
        draw_menu_item "6" "🔧" "节点管理与配置生成"
        echo ""

        draw_separator 50
        draw_menu_item "0" "🔙" "返回主菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-6]: )" gost_choice </dev/tty

        case $gost_choice in
            1) configure_local_target ;;
            2) configure_local_relay ;;
            3) show_local_gost_config ;;
            4) manage_local_gost_service ;;
            5) clear_local_gost_config ;;
            6) show_centralized_menu ;;
            0) break ;;
            *) log_error "无效输入。"; press_any_key ;;
        esac
    done
}

# 配置本机为落地鸡
configure_local_target() {
    # 加载本地配置脚本
    source_local_script || return 1

    clear
    draw_title_line "配置本机为落地鸡" 50
    echo ""

    # 检查并安装 gost
    if ! check_gost_installed; then
        log_info "gost 未安装，正在安装..."
        if ! install_gost_binary; then
            log_error "gost 安装失败"
            press_any_key
            return 1
        fi
    fi

    echo -e "  ${WHITE}${BOLD}落地鸡配置${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    echo ""

    read -p "TLS 监听端口 [8443]: " tls_port </dev/tty
    tls_port=${tls_port:-8443}
    if ! is_valid_port "$tls_port"; then
        log_error "TLS 端口无效，请输入 1-65535 之间的数字。"
        press_any_key
        return 1
    fi
    if ! confirm_port_available "$tls_port" "TLS 监听端口"; then
        log_info "操作已取消"
        press_any_key
        return 0
    fi

    read -p "转发目标 [127.0.0.1:80]: " forward_target </dev/tty
    forward_target=${forward_target:-127.0.0.1:80}

    echo ""
    echo -e "  ${WHITE}${BOLD}配置摘要${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    echo -e "  模式: ${CYAN}落地鸡${NC}"
    echo -e "  TLS 端口: ${CYAN}${tls_port}${NC}"
    echo -e "  转发目标: ${CYAN}${forward_target}${NC}"
    echo ""

    read -p "确认配置并启动服务? (y/n): " confirm </dev/tty
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "操作已取消"
        press_any_key
        return 0
    fi

    # 保存配置
    configure_as_target "$tls_port" "$forward_target"

    # 启动服务
    log_info "正在启动 gost 服务..."
    if start_gost_service; then
        echo ""
        log_success "配置完成！服务已启动"
        echo ""
        echo -e "  ${WHITE}${BOLD}服务信息${NC}"
        echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
        echo -e "  监听端口: ${CYAN}${tls_port}${NC} (TLS)"
        echo -e "  转发到: ${CYAN}${forward_target}${NC}"
        echo -e "  服务状态: ${GREEN}运行中${NC}"
        echo ""
        echo -e "  ${DIM}线路鸡可以连接到: ${NC}${CYAN}本机IP:${tls_port}${NC}"
    else
        log_error "服务启动失败"
    fi

    press_any_key
}

# 配置本机为线路鸡
configure_local_relay() {
    # 加载本地配置脚本
    source_local_script || return 1

    while true; do
        clear
        draw_title_line "配置本机为线路鸡" 50
        echo ""

        # 检查并安装 gost
        if ! check_gost_installed; then
            log_info "gost 未安装，正在安装..."
            if ! install_gost_binary; then
                log_error "gost 安装失败"
                press_any_key
                return 1
            fi
        fi

        # 显示现有转发规则
        echo -e "  ${WHITE}${BOLD}当前转发规则${NC}"
        echo -e "  ${GRAY}──────────────────────────────────────────${NC}"

        local config=$(load_local_config)
        local count=$(echo "$config" | jq '.relay.forwards | length')

        if [[ "$count" -eq 0 ]]; then
            echo -e "  ${DIM}暂无转发规则${NC}"
        else
            echo "$config" | jq -r '.relay.forwards[] | "  [\(.listen_port)] → \(.name) (\(.target_ip):\(.target_port))"'
        fi

        echo ""
        draw_menu_item "1" "➕" "添加转发规则"
        draw_menu_item "2" "🗑️" "删除转发规则"
        draw_menu_item "3" "▶️" "应用配置并启动服务"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回上级菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-3]: )" relay_choice </dev/tty

        case $relay_choice in
            1)
                clear
                draw_title_line "添加转发规则" 50
                echo ""

                read -p "落地鸡名称 (如: 美国落地): " name </dev/tty
                [[ -z "$name" ]] && { log_warning "操作已取消"; press_any_key; continue; }

                read -p "落地鸡 IP: " target_ip </dev/tty
                [[ -z "$target_ip" ]] && { log_warning "操作已取消"; press_any_key; continue; }

                read -p "落地鸡 TLS 端口 [8443]: " target_port </dev/tty
                target_port=${target_port:-8443}
                if ! is_valid_port "$target_port"; then
                    log_error "TLS 端口无效，请输入 1-65535 之间的数字。"
                    press_any_key
                    continue
                fi

                local next_port=$(get_next_listen_port)
                read -p "本地监听端口 [${next_port}]: " listen_port </dev/tty
                listen_port=${listen_port:-$next_port}
                if ! is_valid_port "$listen_port"; then
                    log_error "本地监听端口无效，请输入 1-65535 之间的数字。"
                    press_any_key
                    continue
                fi
                if ! confirm_port_available "$listen_port" "本地监听端口"; then
                    log_info "操作已取消"
                    press_any_key
                    continue
                fi

                echo ""
                log_info "正在添加转发规则..."
                if add_relay_forward "$name" "$target_ip" "$target_port" "$listen_port"; then
                    log_success "转发规则已添加"
                    echo ""
                    echo -e "  ${YELLOW}提示：请选择「应用配置并启动服务」使规则生效${NC}"
                else
                    log_error "添加失败（可能端口已被使用）"
                fi
                press_any_key
                ;;
            2)
                if [[ "$count" -eq 0 ]]; then
                    log_warning "暂无转发规则可删除"
                    press_any_key
                    continue
                fi

                clear
                draw_title_line "删除转发规则" 50
                echo ""

                echo "$config" | jq -r '.relay.forwards[] | "  [\(.listen_port)] → \(.name)"'
                echo ""

                read -p "请输入要删除的监听端口: " del_port </dev/tty
                [[ -z "$del_port" ]] && { log_warning "操作已取消"; press_any_key; continue; }

                remove_relay_forward "$del_port"
                log_success "转发规则已删除"
                echo ""
                echo -e "  ${YELLOW}提示：请选择「应用配置并启动服务」使更改生效${NC}"
                press_any_key
                ;;
            3)
                log_info "正在应用配置并启动服务..."
                if start_gost_service; then
                    echo ""
                    log_success "服务已启动"
                    echo ""
                    echo -e "  ${WHITE}${BOLD}访问方式${NC}"
                    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"

                    config=$(load_local_config)
                    echo "$config" | jq -r '.relay.forwards[] | "  http://本机IP:\(.listen_port) → \(.name)"'
                else
                    log_error "服务启动失败"
                fi
                press_any_key
                ;;
            0) break ;;
            *) log_error "无效输入。"; press_any_key ;;
        esac
    done
}

# 加载本地配置脚本
source_local_script() {
    source_repo_script "gost_local.sh" "load_local_config" && return 0

    log_error "无法加载 gost_local.sh 脚本"
    echo -e "  ${DIM}已尝试本地 scripts/ 目录和 GitHub 自动下载。${NC}"
    press_any_key
    return 1
}

# 查看本机配置
show_local_gost_config() {
    source_local_script || return 1

    clear
    draw_title_line "本机 Gost 配置" 50
    echo ""

    echo -e "  ${WHITE}${BOLD}配置信息${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    get_local_config_summary
    echo ""

    echo -e "  ${WHITE}${BOLD}服务状态${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    local status=$(get_gost_service_status)
    if [[ "$status" == "running" ]]; then
        echo -e "  ${GREEN}● 运行中${NC}"
    else
        echo -e "  ${RED}○ 已停止${NC}"
    fi

    echo ""
    press_any_key
}

# 管理本地服务
manage_local_gost_service() {
    source_local_script || return 1

    clear
    draw_title_line "Gost 服务管理" 50
    echo ""

    local status=$(get_gost_service_status)

    echo -e "  ${WHITE}${BOLD}当前状态${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    if [[ "$status" == "running" ]]; then
        echo -e "  ${GREEN}● 运行中${NC}"
    else
        echo -e "  ${RED}○ 已停止${NC}"
    fi
    echo ""

    if [[ "$status" == "running" ]]; then
        draw_menu_item "1" "⏹️" "停止服务"
        draw_menu_item "2" "🔄" "重启服务"
    else
        draw_menu_item "1" "▶️" "启动服务"
    fi
    draw_menu_item "3" "📊" "查看日志"
    echo ""
    draw_separator 50
    draw_menu_item "0" "🔙" "返回"
    draw_footer 50
    echo ""
    read -p "$(echo -e ${CYAN}请输入选择${NC}): " service_choice </dev/tty

    case $service_choice in
        1)
            if [[ "$status" == "running" ]]; then
                stop_gost_service
                log_success "服务已停止"
            else
                start_gost_service
                log_success "服务已启动"
            fi
            press_any_key
            ;;
        2)
            if [[ "$status" == "running" ]]; then
                start_gost_service
                log_success "服务已重启"
                press_any_key
            fi
            ;;
        3)
            clear
            echo "=== Gost 服务日志 (最近 50 行) ==="
            echo ""
            sudo journalctl -u gost -n 50 --no-pager
            echo ""
            press_any_key
            ;;
        0) ;;
        *) log_error "无效输入。"; press_any_key ;;
    esac
}

# 清除本机配置
clear_local_gost_config() {
    source_local_script || return 1

    clear
    draw_title_line "清除本机配置" 50
    echo ""

    echo -e "  ${RED}${BOLD}⚠ 警告：此操作将删除所有本地配置！${NC}"
    echo ""

    read -p "确认清除? 请输入 'yes' 确认: " confirm </dev/tty

    if [[ "$confirm" == "yes" ]]; then
        # 停止服务
        stop_gost_service 2>/dev/null

        # 删除配置文件
        sudo rm -f "$LOCAL_GOST_CONFIG"
        sudo rm -f "$GOST_SERVICE_FILE"
        sudo systemctl daemon-reload

        log_success "本地配置已清除"
    else
        log_info "操作已取消"
    fi

    press_any_key
}

# 中心化管理菜单（原功能）
show_centralized_menu() {
    while true; do
        clear
        draw_title_line "中心化管理模式" 50
        echo ""

        # 显示统计信息
        local relay_count=$(count_relay_nodes 2>/dev/null || echo "0")
        local target_count=$(count_target_nodes 2>/dev/null || echo "0")
        echo -e "  ${WHITE}${BOLD}节点统计${NC}"
        echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
        echo -e "  线路鸡: ${CYAN}${relay_count}${NC} 个"
        echo -e "  落地鸡: ${CYAN}${target_count}${NC} 个"
        echo ""

        draw_menu_item "1" "🚀" "线路鸡（中转节点）管理"
        draw_menu_item "2" "🎯" "落地鸡（目标节点）管理"
        draw_menu_item "3" "🔗" "配置节点关联"
        draw_menu_item "4" "📋" "查看当前配置"
        draw_menu_item "5" "⚙️" "生成配置脚本"
        draw_menu_item "6" "🗑️" "清除所有配置"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回主菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-6]: )" gost_choice </dev/tty

        case $gost_choice in
            1) show_relay_nodes_menu ;;
            2) show_target_nodes_menu ;;
            3) show_link_nodes_menu ;;
            4) show_gost_config ;;
            5) generate_all_gost_scripts ;;
            6) clear_all_gost_config ;;
            0) break ;;
            *) log_error "无效输入。"; press_any_key ;;
        esac
    done
}

# 线路鸡管理子菜单
show_relay_nodes_menu() {
    while true; do
        clear
        draw_title_line "线路鸡管理" 50
        echo ""

        # 显示现有线路鸡列表
        echo -e "  ${WHITE}${BOLD}现有线路鸡节点${NC}"
        echo -e "  ${GRAY}──────────────────────────────────────────${NC}"

        local config=$(load_gost_config)
        local relay_count=$(echo "$config" | jq '.relay_nodes | length')

        if [[ "$relay_count" -eq 0 ]]; then
            echo -e "  ${DIM}暂无线路鸡节点${NC}"
        else
            echo "$config" | jq -r '.relay_nodes[] | "  [\(.id)] \(.name) - \(.ip) (关联: \(.targets | length)个目标)"'
        fi

        echo ""
        draw_menu_item "1" "➕" "添加线路鸡节点"
        draw_menu_item "2" "🗑️" "删除线路鸡节点"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回上级菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-2]: )" relay_choice </dev/tty

        case $relay_choice in
            1)
                clear
                draw_title_line "添加线路鸡节点" 50
                echo ""

                read -p "节点名称 (如: 香港中转): " node_name </dev/tty
                [[ -z "$node_name" ]] && { log_warning "操作已取消"; press_any_key; continue; }

                read -p "节点 IP 地址: " node_ip </dev/tty
                [[ -z "$node_ip" ]] && { log_warning "操作已取消"; press_any_key; continue; }

                echo ""
                echo -e "  ${YELLOW}提示：线路鸡使用 TLS 转发模式，不需要 SSH 访问${NC}"
                echo ""
                log_info "正在添加线路鸡节点..."
                local new_id=$(add_relay_node "$node_name" "$node_ip")

                if [[ $? -eq 0 ]]; then
                    log_success "线路鸡节点已添加！ID: $new_id"
                else
                    log_error "添加失败"
                fi
                press_any_key
                ;;
            2)
                if [[ "$relay_count" -eq 0 ]]; then
                    log_warning "暂无线路鸡节点可删除"
                    press_any_key
                    continue
                fi

                clear
                draw_title_line "删除线路鸡节点" 50
                echo ""

                echo -e "  ${WHITE}${BOLD}现有线路鸡节点${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                echo "$config" | jq -r '.relay_nodes[] | "  \(.id) - \(.name)"'
                echo ""

                read -p "请输入要删除的节点ID: " delete_id </dev/tty
                [[ -z "$delete_id" ]] && { log_warning "操作已取消"; press_any_key; continue; }

                read -p "确认删除节点 $delete_id? (y/n): " confirm </dev/tty
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    delete_relay_node "$delete_id"
                    log_success "节点已删除"
                else
                    log_info "操作已取消"
                fi
                press_any_key
                ;;
            0) break ;;
            *) log_error "无效输入。"; press_any_key ;;
        esac
    done
}

# 落地鸡管理子菜单
show_target_nodes_menu() {
    while true; do
        clear
        draw_title_line "落地鸡管理" 50
        echo ""

        # 显示现有落地鸡列表
        echo -e "  ${WHITE}${BOLD}现有落地鸡节点${NC}"
        echo -e "  ${GRAY}──────────────────────────────────────────${NC}"

        local config=$(load_gost_config)
        local target_count=$(echo "$config" | jq '.target_nodes | length')

        if [[ "$target_count" -eq 0 ]]; then
            echo -e "  ${DIM}暂无落地鸡节点${NC}"
        else
            echo "$config" | jq -r '.target_nodes[] | "  [\(.id)] \(.name) - \(.ip):\(.tls_port)"'
        fi

        echo ""
        draw_menu_item "1" "➕" "添加落地鸡节点"
        draw_menu_item "2" "🗑️" "删除落地鸡节点"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回上级菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-2]: )" target_choice </dev/tty

        case $target_choice in
            1)
                clear
                draw_title_line "添加落地鸡节点" 50
                echo ""

                read -p "节点名称 (如: 美国落地): " node_name </dev/tty
                [[ -z "$node_name" ]] && { log_warning "操作已取消"; press_any_key; continue; }

                read -p "节点 IP 地址: " node_ip </dev/tty
                [[ -z "$node_ip" ]] && { log_warning "操作已取消"; press_any_key; continue; }

                read -p "TLS 监听端口 [8443]: " tls_port </dev/tty
                tls_port=${tls_port:-8443}

                read -p "转发目标 [127.0.0.1:80]: " forward_target </dev/tty
                forward_target=${forward_target:-127.0.0.1:80}

                echo ""
                echo -e "  ${YELLOW}提示：落地鸡需要运行 gost 监听 TLS 端口 $tls_port${NC}"
                echo ""
                log_info "正在添加落地鸡节点..."
                local new_id=$(add_target_node "$node_name" "$node_ip" "$tls_port" "$forward_target")

                if [[ $? -eq 0 ]]; then
                    log_success "落地鸡节点已添加！ID: $new_id"
                    echo ""
                    echo -e "  ${YELLOW}提示：新节点已添加，但尚未与任何线路鸡关联${NC}"
                    echo -e "  ${DIM}请在「配置节点关联」菜单中配置转发关系${NC}"
                else
                    log_error "添加失败"
                fi
                press_any_key
                ;;
            2)
                if [[ "$target_count" -eq 0 ]]; then
                    log_warning "暂无落地鸡节点可删除"
                    press_any_key
                    continue
                fi

                clear
                draw_title_line "删除落地鸡节点" 50
                echo ""

                echo -e "  ${WHITE}${BOLD}现有落地鸡节点${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                echo "$config" | jq -r '.target_nodes[] | "  \(.id) - \(.name)"'
                echo ""

                read -p "请输入要删除的节点ID: " delete_id </dev/tty
                [[ -z "$delete_id" ]] && { log_warning "操作已取消"; press_any_key; continue; }

                echo ""
                log_warning "删除落地鸡节点将同时移除所有线路鸡的关联"
                read -p "确认删除节点 $delete_id? (y/n): " confirm </dev/tty
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    delete_target_node "$delete_id"
                    log_success "节点已删除，相关关联已自动清除"
                else
                    log_info "操作已取消"
                fi
                press_any_key
                ;;
            0) break ;;
            *) log_error "无效输入。"; press_any_key ;;
        esac
    done
}

# 配置节点关联菜单
show_link_nodes_menu() {
    while true; do
        clear
        draw_title_line "配置节点关联" 50
        echo ""

        local config=$(load_gost_config)
        local relay_count=$(echo "$config" | jq '.relay_nodes | length')
        local target_count=$(echo "$config" | jq '.target_nodes | length')

        if [[ "$relay_count" -eq 0 || "$target_count" -eq 0 ]]; then
            echo -e "  ${YELLOW}⚠ 请先添加线路鸡和落地鸡节点${NC}"
            echo ""
            echo -e "  当前线路鸡: ${CYAN}${relay_count}${NC} 个"
            echo -e "  当前落地鸡: ${CYAN}${target_count}${NC} 个"
            echo ""
            press_any_key
            break
        fi

        draw_menu_item "1" "➕" "添加关联"
        draw_menu_item "2" "🗑️" "删除关联"
        draw_menu_item "3" "📋" "查看关联关系"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回上级菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-3]: )" link_choice </dev/tty

        case $link_choice in
            1)
                clear
                draw_title_line "添加节点关联" 50
                echo ""

                echo -e "  ${WHITE}${BOLD}线路鸡节点${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                echo "$config" | jq -r '.relay_nodes[] | "  \(.id) - \(.name)"'
                echo ""

                read -p "请输入线路鸡ID: " relay_id </dev/tty
                [[ -z "$relay_id" ]] && { log_warning "操作已取消"; press_any_key; continue; }

                # 验证线路鸡是否存在
                local relay_exists=$(echo "$config" | jq -r ".relay_nodes[] | select(.id == \"$relay_id\") | .id")
                if [[ -z "$relay_exists" ]]; then
                    log_error "线路鸡节点不存在"
                    press_any_key
                    continue
                fi

                echo ""
                echo -e "  ${WHITE}${BOLD}落地鸡节点${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                echo "$config" | jq -r '.target_nodes[] | "  \(.id) - \(.name)"'
                echo ""

                read -p "请输入落地鸡ID: " target_id </dev/tty
                [[ -z "$target_id" ]] && { log_warning "操作已取消"; press_any_key; continue; }

                # 验证落地鸡是否存在
                local target_exists=$(echo "$config" | jq -r ".target_nodes[] | select(.id == \"$target_id\") | .id")
                if [[ -z "$target_exists" ]]; then
                    log_error "落地鸡节点不存在"
                    press_any_key
                    continue
                fi

                echo ""
                log_info "正在添加关联..."
                if link_relay_to_target "$relay_id" "$target_id"; then
                    log_success "关联已添加"
                else
                    log_warning "关联可能已存在或添加失败"
                fi
                press_any_key
                ;;
            2)
                clear
                draw_title_line "删除节点关联" 50
                echo ""

                echo -e "  ${WHITE}${BOLD}线路鸡节点${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                echo "$config" | jq -r '.relay_nodes[] | "  \(.id) - \(.name) (关联: \(.targets | length)个目标)"'
                echo ""

                read -p "请输入线路鸡ID: " relay_id </dev/tty
                [[ -z "$relay_id" ]] && { log_warning "操作已取消"; press_any_key; continue; }

                # 显示该线路鸡的关联目标
                echo ""
                echo -e "  ${WHITE}${BOLD}当前关联的落地鸡${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                local targets=$(get_relay_targets "$relay_id")
                if [[ -z "$targets" ]]; then
                    echo -e "  ${DIM}暂无关联${NC}"
                    press_any_key
                    continue
                fi

                echo "$targets" | while read -r tid; do
                    local tname=$(echo "$config" | jq -r ".target_nodes[] | select(.id == \"$tid\") | .name")
                    echo "  $tid - $tname"
                done
                echo ""

                read -p "请输入要移除的落地鸡ID: " target_id </dev/tty
                [[ -z "$target_id" ]] && { log_warning "操作已取消"; press_any_key; continue; }

                unlink_relay_from_target "$relay_id" "$target_id"
                log_success "关联已删除"
                press_any_key
                ;;
            3)
                clear
                draw_title_line "查看关联关系" 50
                echo ""

                echo -e "  ${WHITE}${BOLD}节点关联关系${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"

                local has_links=0
                while read -r relay; do
                    local rid=$(echo "$relay" | jq -r '.id')
                    local rname=$(echo "$relay" | jq -r '.name')
                    local targets=$(echo "$relay" | jq -r '.targets[]' 2>/dev/null)

                    if [[ -n "$targets" ]]; then
                        echo ""
                        echo -e "  ${CYAN}${BOLD}$rname ($rid)${NC}"
                        while read -r tid; do
                            local tname=$(echo "$config" | jq -r ".target_nodes[] | select(.id == \"$tid\") | .name")
                            echo -e "    └─→ $tname ($tid)"
                        done <<< "$targets"
                        has_links=1
                    fi
                done <<< "$(echo "$config" | jq -c '.relay_nodes[]')"

                if [[ $has_links -eq 0 ]]; then
                    echo -e "  ${DIM}暂无配置的关联关系${NC}"
                fi

                echo ""
                press_any_key
                ;;
            0) break ;;
            *) log_error "无效输入。"; press_any_key ;;
        esac
    done
}

# 查看当前配置
show_gost_config() {
    clear
    draw_title_line "当前 Gost 配置" 50
    echo ""

    local config=$(load_gost_config)

    echo -e "  ${WHITE}${BOLD}配置文件路径${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    echo -e "  ${GOST_CONFIG_FILE}"
    echo ""

    echo -e "  ${WHITE}${BOLD}线路鸡节点${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    local relay_count=$(echo "$config" | jq '.relay_nodes | length')
    if [[ "$relay_count" -eq 0 ]]; then
        echo -e "  ${DIM}暂无线路鸡节点${NC}"
    else
        echo "$config" | jq -r '.relay_nodes[] | "  • \(.name) (\(.ip)) - 关联 \(.targets | length) 个目标"'
    fi

    echo ""
    echo -e "  ${WHITE}${BOLD}落地鸡节点${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    local target_count=$(echo "$config" | jq '.target_nodes | length')
    if [[ "$target_count" -eq 0 ]]; then
        echo -e "  ${DIM}暂无落地鸡节点${NC}"
    else
        echo "$config" | jq -r '.target_nodes[] | "  • \(.name) (\(.ip):\(.tls_port)) - 转发到 \(.forward_target)"'
    fi

    echo ""
    press_any_key
}

# 生成所有配置脚本
generate_all_gost_scripts() {
    clear
    draw_title_line "生成配置脚本" 50
    echo ""

    local config=$(load_gost_config)
    local relay_count=$(echo "$config" | jq '.relay_nodes | length')
    local target_count=$(echo "$config" | jq '.target_nodes | length')

    if [[ "$relay_count" -eq 0 && "$target_count" -eq 0 ]]; then
        log_warning "暂无节点，无法生成配置"
        press_any_key
        return
    fi

    mkdir -p "$GOST_DEPLOY_DIR"

    echo -e "  ${WHITE}${BOLD}生成配置脚本${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    echo ""

    # 生成落地鸡脚本
    if [[ "$target_count" -gt 0 ]]; then
        log_info "正在生成落地鸡脚本..."
        echo ""
        generate_all_target_scripts
        echo ""
    fi

    # 生成线路鸡脚本
    if [[ "$relay_count" -gt 0 ]]; then
        log_info "正在生成线路鸡脚本..."
        echo ""

        while read -r relay; do
            local rid=$(echo "$relay" | jq -r '.id')
            local rname=$(echo "$relay" | jq -r '.name')

            local script_file
            script_file=$(generate_relay_gost_script "$rid")

            if [[ $? -eq 0 && -f "$script_file" ]]; then
                echo -e "  ${GREEN}✓${NC} 已生成线路鸡脚本: ${script_file}"
            else
                echo -e "  ${RED}✗${NC} 生成失败: $rname"
            fi
        done <<< "$(echo "$config" | jq -c '.relay_nodes[]')"
    fi

    echo ""
    log_success "配置脚本已生成到: $GOST_DEPLOY_DIR"
    echo ""
    echo -e "  ${WHITE}${BOLD}部署步骤（TLS 加密转发模式）${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    echo ""
    echo -e "  ${CYAN}${BOLD}第一步：在所有落地鸡上部署${NC}"
    echo -e "  1. 复制落地鸡脚本到对应服务器"
    echo -e "     ${DIM}scp /opt/gost_deploy/gost_target_*.sh root@落地鸡IP:/root/${NC}"
    echo ""
    echo -e "  2. 在落地鸡上安装 gost"
    echo -e "     ${DIM}wget https://github.com/ginuerzh/gost/releases/download/v2.11.5/gost-linux-amd64-2.11.5.gz${NC}"
    echo -e "     ${DIM}gunzip gost-linux-amd64-2.11.5.gz${NC}"
    echo -e "     ${DIM}mv gost-linux-amd64-2.11.5 /usr/local/bin/gost && chmod +x /usr/local/bin/gost${NC}"
    echo ""
    echo -e "  3. 运行落地鸡脚本（监听 TLS 端口）"
    echo -e "     ${DIM}bash gost_target_*.sh${NC}"
    echo -e "     ${DIM}或使用 nohup: nohup bash gost_target_*.sh > gost.log 2>&1 &${NC}"
    echo ""
    echo -e "  ${CYAN}${BOLD}第二步：在所有线路鸡上部署${NC}"
    echo -e "  1. 复制线路鸡脚本到对应服务器"
    echo -e "     ${DIM}scp /opt/gost_deploy/gost_relay_*.sh root@线路鸡IP:/root/${NC}"
    echo ""
    echo -e "  2. 在线路鸡上安装 gost（同上）"
    echo ""
    echo -e "  3. 运行线路鸡脚本（连接落地鸡）"
    echo -e "     ${DIM}bash gost_relay_*.sh${NC}"
    echo ""
    echo -e "  ${YELLOW}${BOLD}注意事项：${NC}"
    echo -e "  • 必须先启动落地鸡，再启动线路鸡"
    echo -e "  • 确保落地鸡的 TLS 端口已开放"
    echo -e "  • 线路鸡会监听 10001+ 端口提供服务"
    echo -e "  • 所有流量通过 TLS 加密传输，无需 SSH"
    echo ""

    press_any_key
}

# 清除所有配置
clear_all_gost_config() {
    clear
    draw_title_line "清除所有配置" 50
    echo ""

    echo -e "  ${RED}${BOLD}⚠ 警告：此操作将删除所有节点和配置！${NC}"
    echo ""

    read -p "确认清除所有配置? 请输入 'yes' 确认: " confirm </dev/tty

    if [[ "$confirm" == "yes" ]]; then
        # 备份配置
        if [[ -f "$GOST_CONFIG_FILE" ]]; then
            local backup_file="${GOST_CONFIG_FILE}.backup.$(date +%Y%m%d%H%M%S)"
            cp "$GOST_CONFIG_FILE" "$backup_file"
            log_info "配置已备份到: $backup_file"
        fi

        # 重新初始化配置
        cat > "$GOST_CONFIG_FILE" <<'EOF'
{
  "version": "1.0",
  "relay_nodes": [],
  "target_nodes": []
}
EOF

        # 清除生成的脚本
        rm -rf "$GOST_DEPLOY_DIR"/*.sh 2>/dev/null

        log_success "所有配置已清除"
    else
        log_info "操作已取消"
    fi

    press_any_key
}
