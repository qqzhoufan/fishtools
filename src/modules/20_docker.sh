# ================== Docker 安装子菜单 ==================
install_docker_menu() {
    while true; do
        clear
        draw_title_line "Docker 管理" 50
        echo ""

        # 显示当前安装状态
        if command -v docker &>/dev/null; then
            local docker_ver=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')
            echo -e "  ${GREEN}✓${NC} Docker 已安装 (${docker_ver})"
            if systemctl is-active --quiet docker 2>/dev/null; then
                echo -e "  ${GREEN}●${NC} Docker 状态: ${GREEN}运行中${NC}"
            else
                echo -e "  ${RED}●${NC} Docker 状态: ${RED}已停止${NC}"
            fi
            # 显示容器和镜像数量
            local container_count=$(docker ps -aq 2>/dev/null | wc -l)
            local running_count=$(docker ps -q 2>/dev/null | wc -l)
            local image_count=$(docker images -q 2>/dev/null | wc -l)
            echo -e "  ${CYAN}容器:${NC} ${running_count}/${container_count} 运行中  ${CYAN}镜像:${NC} ${image_count} 个"
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

        echo -e "  ${WHITE}${BOLD}【安装与卸载】${NC}"
        draw_menu_item "1" "🇨🇳" "使用腾讯云源安装 (国内首选)"
        draw_menu_item "2" "🇨🇳" "使用阿里云源安装"
        draw_menu_item "3" "🇨🇳" "使用中科大源安装"
        draw_menu_item "4" "🌍" "使用官方源安装 (国外推荐)"
        draw_menu_item "5" "🗑️" "卸载 Docker"
        echo ""
        echo -e "  ${WHITE}${BOLD}【容器管理】${NC}"
        draw_menu_item "6" "📋" "查看容器列表"
        draw_menu_item "7" "▶️" "启动/停止/重启容器"
        draw_menu_item "8" "📝" "查看容器日志"
        echo ""
        echo -e "  ${WHITE}${BOLD}【镜像与清理】${NC}"
        draw_menu_item "9" "🖼️" "查看镜像列表"
        draw_menu_item "10" "🧹" "清理 Docker 空间"
        draw_menu_item "11" "🚀" "配置镜像加速 (国内)"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回上级菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-11]: )" docker_choice </dev/tty

        case $docker_choice in
            1)
                clear
                draw_title_line "使用腾讯云源安装 Docker" 50
                echo ""
                if command -v docker &>/dev/null; then
                    log_warning "Docker 已安装，是否重新安装？"
                    read -p "输入 y 继续，其他键取消: " confirm </dev/tty
                    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && continue
                fi
                log_info "正在从腾讯云源安装..."
                curl -fsSL https://get.docker.com | bash -s docker --mirror https://mirrors.cloud.tencent.com/docker-ce
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
                draw_title_line "使用中科大源安装 Docker" 50
                echo ""
                if command -v docker &>/dev/null; then
                    log_warning "Docker 已安装，是否重新安装？"
                    read -p "输入 y 继续，其他键取消: " confirm </dev/tty
                    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && continue
                fi
                log_info "正在从中科大源安装..."
                curl -fsSL https://get.docker.com | bash -s docker --mirror https://mirrors.ustc.edu.cn/docker-ce
                sudo usermod -aG docker "$USER" 2>/dev/null || true
                echo ""
                log_success "Docker 安装完成！"
                docker --version
                docker compose version 2>/dev/null || true
                echo ""
                echo -e "  ${YELLOW}提示: 如需使用当前用户运行 Docker，请重新登录终端${NC}"
                press_any_key
                ;;
            4)
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
            5)
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
                pkg_remove docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker.io docker-compose docker-doc podman-docker 2>/dev/null || true
                log_info "正在清理 Docker 数据..."
                sudo rm -rf /var/lib/docker
                sudo rm -rf /var/lib/containerd
                sudo rm -rf /etc/docker
                echo ""
                log_success "Docker 已完全卸载！"
                press_any_key
                ;;
            6)
                clear
                draw_title_line "容器列表" 50
                echo ""
                if ! command -v docker &>/dev/null; then
                    log_error "Docker 未安装！"
                    press_any_key
                    continue
                fi
                echo -e "  ${WHITE}${BOLD}运行中的容器${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "  暂无运行中的容器"
                echo ""
                echo -e "  ${WHITE}${BOLD}所有容器${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null || echo "  暂无容器"
                press_any_key
                ;;
            7)
                clear
                draw_title_line "容器操作" 50
                echo ""
                if ! command -v docker &>/dev/null; then
                    log_error "Docker 未安装！"
                    press_any_key
                    continue
                fi
                docker ps -a --format "table {{.Names}}\t{{.Status}}" 2>/dev/null
                echo ""
                read -p "请输入容器名称: " container_name </dev/tty
                if [[ -z "$container_name" ]]; then
                    press_any_key
                    continue
                fi
                echo ""
                echo -e "  ${CYAN}1.${NC} 启动"
                echo -e "  ${CYAN}2.${NC} 停止"
                echo -e "  ${CYAN}3.${NC} 重启"
                echo -e "  ${CYAN}4.${NC} 删除"
                echo ""
                read -p "请选择操作: " op </dev/tty
                case $op in
                    1) docker start "$container_name" && log_success "容器已启动" ;;
                    2) docker stop "$container_name" && log_success "容器已停止" ;;
                    3) docker restart "$container_name" && log_success "容器已重启" ;;
                    4)
                        read -p "确认删除容器 $container_name? (y/n): " confirm </dev/tty
                        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                            docker rm -f "$container_name" && log_success "容器已删除"
                        fi
                        ;;
                esac
                press_any_key
                ;;
            8)
                clear
                draw_title_line "容器日志" 50
                echo ""
                if ! command -v docker &>/dev/null; then
                    log_error "Docker 未安装！"
                    press_any_key
                    continue
                fi
                docker ps --format "{{.Names}}" 2>/dev/null
                echo ""
                read -p "请输入容器名称: " container_name </dev/tty
                if [[ -n "$container_name" ]]; then
                    echo ""
                    echo -e "  ${DIM}(按 Ctrl+C 退出日志查看)${NC}"
                    echo ""
                    docker logs -f --tail 100 "$container_name" 2>/dev/null || log_error "无法获取日志"
                fi
                press_any_key
                ;;
            9)
                clear
                draw_title_line "镜像列表" 50
                echo ""
                if ! command -v docker &>/dev/null; then
                    log_error "Docker 未安装！"
                    press_any_key
                    continue
                fi
                echo -e "  ${WHITE}${BOLD}本地镜像${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}" 2>/dev/null || echo "  暂无镜像"
                echo ""
                # 显示磁盘占用
                local disk_usage=$(docker system df 2>/dev/null | grep -E "^(Images|Containers|Volumes)" || true)
                if [[ -n "$disk_usage" ]]; then
                    echo -e "  ${WHITE}${BOLD}磁盘占用${NC}"
                    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                    echo "$disk_usage" | while read line; do echo "  $line"; done
                fi
                press_any_key
                ;;
            10)
                clear
                draw_title_line "清理 Docker 空间" 50
                echo ""
                if ! command -v docker &>/dev/null; then
                    log_error "Docker 未安装！"
                    press_any_key
                    continue
                fi

                # 显示当前占用
                echo -e "  ${WHITE}${BOLD}当前 Docker 磁盘占用${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                docker system df 2>/dev/null || true
                echo ""

                echo -e "  ${CYAN}1.${NC} 清理悬空镜像 (无标签镜像)"
                echo -e "  ${CYAN}2.${NC} 清理已停止的容器"
                echo -e "  ${CYAN}3.${NC} 清理未使用的网络"
                echo -e "  ${CYAN}4.${NC} 全部清理 (推荐)"
                echo -e "  ${RED}5.${NC} 深度清理 (包括未使用的卷，谨慎!)"
                echo ""
                read -p "请选择清理方式: " clean_choice </dev/tty
                echo ""
                case $clean_choice in
                    1)
                        log_info "清理悬空镜像..."
                        docker image prune -f
                        ;;
                    2)
                        log_info "清理已停止的容器..."
                        docker container prune -f
                        ;;
                    3)
                        log_info "清理未使用的网络..."
                        docker network prune -f
                        ;;
                    4)
                        log_info "执行全面清理..."
                        docker system prune -f
                        ;;
                    5)
                        echo -e "  ${RED}${BOLD}⚠ 警告：这将删除所有未使用的卷数据！${NC}"
                        read -p "请输入 'yes' 确认: " confirm </dev/tty
                        if [[ "$confirm" == "yes" ]]; then
                            docker system prune -a --volumes -f
                        else
                            log_info "操作已取消"
                        fi
                        ;;
                esac
                echo ""
                log_success "清理完成！"
                echo ""
                echo -e "  ${WHITE}${BOLD}清理后磁盘占用${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                docker system df 2>/dev/null || true
                press_any_key
                ;;
            11)
                clear
                draw_title_line "Docker 镜像加速配置" 50
                echo ""
                if ! command -v docker &>/dev/null; then
                    log_error "Docker 未安装！"
                    press_any_key
                    continue
                fi

                # 显示当前配置
                echo -e "  ${WHITE}${BOLD}当前镜像源配置${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                if [[ -f /etc/docker/daemon.json ]]; then
                    local current_mirrors=$(cat /etc/docker/daemon.json 2>/dev/null | grep -o '"https://[^"]*"' | tr '\n' ' ')
                    if [[ -n "$current_mirrors" ]]; then
                        echo -e "  ${GREEN}已配置:${NC} $current_mirrors"
                    else
                        echo -e "  ${GRAY}未配置镜像加速${NC}"
                    fi
                else
                    echo -e "  ${GRAY}未配置镜像加速${NC}"
                fi
                echo ""

                echo -e "  ${WHITE}${BOLD}选择镜像加速源:${NC}"
                echo -e "  ${CYAN}1.${NC} DaoCloud (docker.m.daocloud.io) ${DIM}(推荐)${NC}"
                echo -e "  ${CYAN}2.${NC} 南京大学 (docker.nju.edu.cn)"
                echo -e "  ${CYAN}3.${NC} Docker 官方中国镜像"
                echo -e "  ${CYAN}4.${NC} 自定义镜像地址"
                echo -e "  ${CYAN}5.${NC} 移除镜像加速配置"
                echo ""
                read -p "请选择 [1-5]: " mirror_choice </dev/tty

                local mirror_url=""
                case $mirror_choice in
                    1) mirror_url="https://docker.m.daocloud.io" ;;
                    2) mirror_url="https://docker.nju.edu.cn" ;;
                    3) mirror_url="https://registry.docker-cn.com" ;;
                    4)
                        read -p "请输入镜像地址 (如 https://xxx.mirror.aliyuncs.com): " mirror_url </dev/tty
                        ;;
                    5)
                        if [[ -f /etc/docker/daemon.json ]]; then
                            sudo rm -f /etc/docker/daemon.json
                            sudo systemctl restart docker 2>/dev/null || true
                            log_success "镜像加速配置已移除"
                        else
                            log_info "未配置镜像加速，无需移除"
                        fi
                        press_any_key
                        continue
                        ;;
                esac

                if [[ -n "$mirror_url" ]]; then
                    sudo mkdir -p /etc/docker
                    sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "registry-mirrors": ["${mirror_url}"]
}
EOF
                    sudo systemctl daemon-reload 2>/dev/null || true
                    sudo systemctl restart docker 2>/dev/null || true
                    log_success "镜像加速已配置: ${mirror_url}"
                    echo -e "  ${CYAN}Docker 服务已重启生效${NC}"
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
