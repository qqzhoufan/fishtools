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
        draw_menu_item "7" "🔧" "系统工具"
        draw_menu_item "8" "🌐" "网络隧道工具"
        draw_menu_item "9" "🤖" "OpenClaw AI 助手"
        echo ""
        draw_separator 50
        draw_menu_item "0" "👋" "退出脚本"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-9]: )" main_choice </dev/tty

        case $main_choice in
            1) show_status_menu ;;
            2) show_test_menu ;;
            3) show_dd_menu ;;
            4) show_install_menu ;;
            5) show_deployment_menu ;;
            6) show_optimization_menu ;;
            7) show_system_tools_menu ;;
            8) show_gost_menu ;;
            9) show_openclaw_menu ;;
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
handle_args "$@"

# root 权限检测
if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
    echo -e "${YELLOW}  ⚠ 警告: 当前非 root 用户且无免密 sudo，部分功能可能无法使用${NC}"
    echo -e "${YELLOW}  ⚠ 建议以 root 用户运行: ${CYAN}sudo $0${NC}"
    echo ""
fi

check_dependencies
check_update
