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
                if curl -fsL https://sh.nekoneko.cloud/tools.sh -o tools.sh; then
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
