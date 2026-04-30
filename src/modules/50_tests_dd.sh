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
                local work_dir script_file
                work_dir="$(make_fishtools_work_dir backtrace 2>/dev/null || true)"
                script_file="${work_dir}/backtrace.sh"
                if [[ -n "$work_dir" ]] && download_file_with_fallback "$script_file" \
                    "https://raw.githubusercontent.com/zhanghanyun/backtrace/main/install.sh"; then
                    log_success "下载成功，开始执行..."
                    echo ""
                    chmod +x "$script_file" 2>/dev/null || true
                    run_shell_script_in_dir "$work_dir" "$script_file" 0 || true
                else
                    log_error "脚本下载失败！"
                fi
                cleanup_fishtools_work_dir "$work_dir"
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
                local vps_ip=$(get_public_ipv4)
                if [[ -n "$vps_ip" ]]; then
                    echo -e "  ${WHITE}${BOLD}您的 VPS IP: ${CYAN}${vps_ip}${NC}"
                    echo ""
                fi

                log_info "正在安装 NextTrace 路由追踪工具..."
                echo ""

                # 使用官方安装脚本
                local work_dir script_file
                work_dir="$(make_fishtools_work_dir nexttrace 2>/dev/null || true)"
                script_file="${work_dir}/nt_install.sh"
                if [[ -n "$work_dir" ]] && download_file_with_fallback "$script_file" \
                    "https://raw.githubusercontent.com/nxtrace/NTrace-core/main/nt_install.sh"; then
                    run_shell_script_in_dir "$work_dir" "$script_file" 1 || true
                    cleanup_fishtools_work_dir "$work_dir"
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
                    cleanup_fishtools_work_dir "$work_dir"
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
        draw_menu_item "4" "📡" "Speedtest 测速"
        draw_menu_item "5" "🌐" "三网测速 (电信/联通/移动)"
        draw_menu_item "6" "💾" "磁盘 IO 测试"
        draw_menu_item "7" "📺" "流媒体解锁检测"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回主菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-7]: )" test_choice </dev/tty
        case $test_choice in
            1)
                clear
                draw_title_line "融合怪测试" 50
                echo ""
                log_info "开始运行 融合怪 (ecs.sh) 测试脚本..."
                log_info "尝试从主链接 (gitlab) 下载..."
                local work_dir script_file
                work_dir="$(make_fishtools_work_dir ecs 2>/dev/null || true)"
                script_file="${work_dir}/ecs.sh"
                if [[ -n "$work_dir" ]] && download_file_with_fallback "$script_file" \
                    "https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh"; then
                    log_success "主链接下载成功。"
                    chmod +x "$script_file" 2>/dev/null || true
                    run_shell_script_in_dir "$work_dir" "$script_file" 0
                else
                    log_warning "主链接下载失败，尝试从备用链接 (github) 下载..."
                    if [[ -n "$work_dir" ]] && download_file_with_fallback "$script_file" \
                        "https://github.com/spiritLHLS/ecs/raw/main/ecs.sh"; then
                        log_success "备用链接下载成功。"
                        chmod +x "$script_file" 2>/dev/null || true
                        run_shell_script_in_dir "$work_dir" "$script_file" 0
                    else
                        log_error "主链接和备用链接均下载失败！"
                    fi
                fi
                cleanup_fishtools_work_dir "$work_dir"
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
                    local work_dir script_file
                    work_dir="$(make_fishtools_work_dir fish-ipcheck 2>/dev/null || true)"
                    script_file="${work_dir}/fish_ipcheck.sh"
                    if [[ -n "$work_dir" ]] && download_file_with_fallback "$script_file" \
                        "https://raw.githubusercontent.com/${AUTHOR_GITHUB_USER}/${MAIN_REPO_NAME}/main/scripts/fish_ipcheck.sh"; then
                        log_success "下载成功，开始执行..."
                        echo ""
                        run_shell_script_in_dir "$work_dir" "$script_file" 0 || true
                    else
                        log_error "脚本下载失败！"
                    fi
                    cleanup_fishtools_work_dir "$work_dir"
                fi
                press_any_key
                ;;
            3)
                show_route_menu
                ;;
            4)
                clear
                draw_title_line "Speedtest 测速" 50
                echo ""
                # 检查 speedtest 是否已安装
                if ! command -v speedtest &>/dev/null; then
                    log_info "正在安装 Speedtest CLI..."
                    # 尝试使用官方安装脚本
                    if curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash 2>/dev/null; then
                        sudo apt-get install -y speedtest 2>/dev/null
                    else
                        # 备用方案：使用 speedtest-cli (Python 版本)
                        log_warning "官方安装失败，尝试安装 Python 版本..."
                        if command -v pip3 &>/dev/null; then
                            sudo pip3 install speedtest-cli 2>/dev/null
                        elif command -v pip &>/dev/null; then
                            sudo pip install speedtest-cli 2>/dev/null
                        else
                            sudo apt-get install -y speedtest-cli 2>/dev/null || \
                            sudo apt-get install -y python3-pip && sudo pip3 install speedtest-cli
                        fi
                    fi
                fi

                echo ""
                if command -v speedtest &>/dev/null; then
                    log_info "开始测速..."
                    echo ""
                    speedtest --accept-license --accept-gdpr 2>/dev/null || speedtest 2>/dev/null
                elif command -v speedtest-cli &>/dev/null; then
                    log_info "开始测速..."
                    echo ""
                    speedtest-cli
                else
                    log_error "Speedtest 安装失败，请手动安装"
                fi
                press_any_key
                ;;
            5)
                clear
                draw_title_line "三网测速" 50
                echo ""
                log_info "正在下载三网测速脚本..."
                log_info "将测试电信、联通、移动三大运营商的速度"
                echo ""

                # 使用 bench.sh 的三网测速
                local work_dir script_file
                work_dir="$(make_fishtools_work_dir superspeed 2>/dev/null || true)"
                script_file="${work_dir}/superspeed.sh"
                if [[ -n "$work_dir" ]] && download_file_with_fallback "$script_file" \
                    "https://raw.githubusercontent.com/uxh/superspeed/master/superspeed.sh"; then
                    log_success "下载成功，开始执行..."
                    echo ""
                    run_shell_script_in_dir "$work_dir" "$script_file" 0 || true
                else
                    # 备用方案
                    log_warning "主脚本下载失败，尝试备用方案..."
                    bash <(curl -Lso- https://bench.im/hyperspeed) || \
                    log_error "三网测速脚本下载失败！"
                fi
                cleanup_fishtools_work_dir "$work_dir"
                press_any_key
                ;;
            6)
                clear
                draw_title_line "磁盘 IO 测试" 50
                echo ""
                log_info "开始磁盘 IO 测试..."
                echo ""
                local work_dir test_file fio_file
                work_dir="$(make_fishtools_work_dir disk-io 2>/dev/null || true)"
                if [[ -z "$work_dir" ]]; then
                    log_error "无法创建临时测试目录，已取消磁盘 IO 测试。"
                    press_any_key
                    continue
                fi
                test_file="${work_dir}/test_io_file"
                fio_file="${work_dir}/fio_test"

                echo -e "  ${WHITE}${BOLD}顺序写入测试 (1GB)${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                sync
                local write_result=$(dd if=/dev/zero of="$test_file" bs=1M count=1024 conv=fdatasync 2>&1)
                local write_speed=$(echo "$write_result" | grep -oP '\d+\.?\d*\s*(MB|GB)/s' | tail -1)
                echo -e "  ${GREEN}写入速度:${NC} ${write_speed:-解析失败}"

                echo ""
                echo -e "  ${WHITE}${BOLD}顺序读取测试${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                # 清除缓存
                sync && echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || true
                local read_result=$(dd if="$test_file" of=/dev/null bs=1M 2>&1)
                local read_speed=$(echo "$read_result" | grep -oP '\d+\.?\d*\s*(MB|GB)/s' | tail -1)
                echo -e "  ${GREEN}读取速度:${NC} ${read_speed:-解析失败}"

                # 清理测试文件
                rm -f "$test_file"

                echo ""
                echo -e "  ${WHITE}${BOLD}4K 随机读写测试${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                if command -v fio &>/dev/null; then
                    local fio_result=$(fio --name=random-rw --ioengine=sync --rw=randrw --bs=4k --size=64m --numjobs=1 --time_based --runtime=10 --group_reporting --filename="$fio_file" 2>&1)
                    local read_iops=$(echo "$fio_result" | grep "read:" | grep -oP 'IOPS=\K[\d.]+[kKmM]?' | head -1)
                    local write_iops=$(echo "$fio_result" | grep "write:" | grep -oP 'IOPS=\K[\d.]+[kKmM]?' | head -1)
                    echo -e "  ${GREEN}4K 随机读 IOPS:${NC} ${read_iops:-N/A}"
                    echo -e "  ${GREEN}4K 随机写 IOPS:${NC} ${write_iops:-N/A}"
                    rm -f "$fio_file"
                else
                    echo -e "  ${YELLOW}fio 未安装，跳过 4K 随机读写测试${NC}"
                    echo -e "  ${DIM}可通过 apt install fio 安装${NC}"
                fi

                cleanup_fishtools_work_dir "$work_dir"
                echo ""
                press_any_key
                ;;
            7)
                clear
                draw_title_line "流媒体解锁检测" 50
                echo ""
                log_info "正在下载流媒体解锁检测脚本..."
                log_info "将检测 Netflix, Disney+, YouTube Premium 等平台解锁状态"
                echo ""

                # 使用 lmc999/RegionRestrictionCheck
                if bash <(curl -L -s https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/check.sh) 2>/dev/null; then
                    :
                else
                    log_error "流媒体检测脚本执行失败！"
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

                local work_dir script_file
                work_dir="$(make_fishtools_work_dir reinstall 2>/dev/null || true)"
                script_file="${work_dir}/reinstall.sh"

                log_info "尝试从主链接 (github) 下载 reinstall.sh..."
                if [[ -n "$work_dir" ]] && download_file_with_fallback "$script_file" \
                    "https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh"; then
                    log_success "主链接下载成功。"
                else
                    log_warning "主链接下载失败，尝试从备用链接 (cnb.cool) 下载..."
                    if [[ -z "$work_dir" ]] || ! download_file_with_fallback "$script_file" \
                        "https://cnb.cool/bin456789/reinstall/-/git/raw/main/reinstall.sh"; then
                         log_error "主链接和备用链接均下载失败！"
                         cleanup_fishtools_work_dir "$work_dir"
                         press_any_key
                         continue
                    fi
                    log_success "备用链接下载成功。"
                fi

                # 验证下载的文件是否为有效的 shell 脚本
                if [[ ! -f "$script_file" ]] || ! head -1 "$script_file" | grep -qE '^#!.*bash'; then
                    log_error "下载的文件不是有效的 shell 脚本！"
                    cleanup_fishtools_work_dir "$work_dir"
                    press_any_key
                    continue
                fi

                log_info "脚本已下载，即将执行。请根据后续脚本提示操作！"
                echo ""
                run_shell_script_in_dir "$work_dir" "$script_file" 1
                local reinstall_exit=$?
                cleanup_fishtools_work_dir "$work_dir"
                echo ""
                if [[ $reinstall_exit -ne 0 ]]; then
                    log_error "reinstall.sh 执行异常退出 (退出码: $reinstall_exit)"
                else
                    log_success "reinstall.sh 已执行完成。"
                fi
                press_any_key
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

                local work_dir script_file
                work_dir="$(make_fishtools_work_dir osmutation 2>/dev/null || true)"
                script_file="${work_dir}/OsMutation.sh"

                log_info "尝试从主链接 (github) 下载 OsMutation.sh..."
                if [[ -n "$work_dir" ]] && download_file_with_fallback "$script_file" \
                    "https://raw.githubusercontent.com/LloydAsp/OsMutation/main/OsMutation.sh"; then
                    log_success "主链接下载成功。"
                else
                    log_warning "主链接下载失败，尝试从备用链接 (cnb.cool) 下载..."
                    if [[ -z "$work_dir" ]] || ! download_file_with_fallback "$script_file" \
                        "https://cnb.cool/LloydAsp/OsMutation/-/raw/main/OsMutation.sh"; then
                        log_error "主链接和备用链接均下载失败！"
                        cleanup_fishtools_work_dir "$work_dir"
                        press_any_key
                        continue
                    fi
                    log_success "备用链接下载成功。"
                fi

                # 验证下载的文件是否为有效的 shell 脚本
                if [[ ! -f "$script_file" ]] || ! head -1 "$script_file" | grep -qE '^#!.*bash'; then
                    log_error "下载的文件不是有效的 shell 脚本！"
                    cleanup_fishtools_work_dir "$work_dir"
                    press_any_key
                    continue
                fi

                log_info "脚本已下载，即将执行。请根据后续脚本提示操作！"
                echo ""
                run_shell_script_in_dir "$work_dir" "$script_file" 1
                local osmu_exit=$?
                cleanup_fishtools_work_dir "$work_dir"
                echo ""
                if [[ $osmu_exit -ne 0 ]]; then
                    log_error "OsMutation.sh 执行异常退出 (退出码: $osmu_exit)"
                else
                    log_success "OsMutation.sh 已执行完成。"
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
