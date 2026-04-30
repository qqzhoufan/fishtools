# ================== OpenClaw AI 助手管理 ==================

# 检查 Node.js 版本是否满足要求 (>=22)
check_node_version() {
    if ! command -v node &>/dev/null; then
        return 1
    fi
    local node_ver=$(node -v 2>/dev/null | sed 's/v//' | cut -d. -f1)
    [[ "$node_ver" -ge 22 ]] 2>/dev/null
}

# 安装 Node.js 22+
install_nodejs() {
    log_info "正在安装 Node.js 22..."
    if command -v apt-get &>/dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
        sudo apt-get install -y nodejs
    elif command -v dnf &>/dev/null; then
        curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -
        sudo dnf install -y nodejs
    elif command -v yum &>/dev/null; then
        curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -
        sudo yum install -y nodejs
    else
        log_error "无法自动安装 Node.js，请手动安装 Node.js 22+"
        return 1
    fi

    if check_node_version; then
        log_success "Node.js $(node -v) 安装成功"
        return 0
    else
        log_error "Node.js 安装失败或版本不满足要求"
        return 1
    fi
}

show_openclaw_menu() {
    while true; do
        clear
        draw_title_line "OpenClaw AI 助手" 50
        echo ""
        echo -e "  ${WHITE}${BOLD}OpenClaw - 开源个人 AI 智能体${NC}"
        echo -e "  ${DIM}可执行任务的 AI 助手，支持操作系统、处理文件、编写代码${NC}"
        echo -e "  ${DIM}https://github.com/openclaw/openclaw${NC}"
        echo ""

        # 检测安装状态
        if command -v openclaw &>/dev/null; then
            local oc_ver=$(openclaw --version 2>/dev/null || echo "未知")
            echo -e "  ${GREEN}✓${NC} OpenClaw 已安装 (npm) - ${oc_ver}"
        elif docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "openclaw"; then
            local oc_status=$(docker inspect -f '{{.State.Status}}' openclaw 2>/dev/null || echo "未知")
            echo -e "  ${GREEN}✓${NC} OpenClaw 已安装 (Docker) - 状态: ${oc_status}"
        else
            echo -e "  ${GRAY}○${NC} OpenClaw 未安装"
        fi
        echo ""

        echo -e "  ${WHITE}${BOLD}【安装】${NC}"
        draw_menu_item "1" "📦" "npm 全局安装 (需要 Node.js 22+)"
        draw_menu_item "2" "🐳" "Docker 部署 (推荐)"
        echo ""
        echo -e "  ${WHITE}${BOLD}【管理】${NC}"
        draw_menu_item "3" "▶️" "启动 / 停止 OpenClaw"
        draw_menu_item "4" "📊" "查看状态 / 日志"
        draw_menu_item "5" "🗑️" "卸载 OpenClaw"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回主菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-5]: )" oc_choice </dev/tty

        case $oc_choice in
            1)
                clear
                draw_title_line "npm 安装 OpenClaw" 50
                echo ""

                # 检查 Node.js
                if ! check_node_version; then
                    local node_ver="未安装"
                    command -v node &>/dev/null && node_ver="v$(node -v 2>/dev/null | sed 's/v//')"
                    echo -e "  ${YELLOW}⚠ Node.js 版本不满足要求${NC}"
                    echo -e "  ${DIM}当前: ${node_ver}，需要: v22+${NC}"
                    echo ""
                    read -p "是否自动安装 Node.js 22? (y/n): " install_node </dev/tty
                    if [[ "$install_node" == "y" || "$install_node" == "Y" ]]; then
                        install_nodejs || { press_any_key; continue; }
                    else
                        log_info "操作已取消"
                        press_any_key
                        continue
                    fi
                else
                    echo -e "  ${GREEN}✓${NC} Node.js $(node -v) 已就绪"
                fi

                echo ""
                log_info "正在通过 npm 安装 OpenClaw..."
                npm install -g openclaw@latest

                if command -v openclaw &>/dev/null; then
                    echo ""
                    log_success "OpenClaw 安装成功！"
                    echo ""

                    # 初始化配置
                    echo -e "  ${WHITE}${BOLD}初始化配置${NC}"
                    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                    echo -e "  ${DIM}OpenClaw 支持多种 AI 服务提供商 (Anthropic/OpenAI 等)${NC}"
                    echo ""
                    read -p "是否现在运行初始化向导? (y/n): " run_onboard </dev/tty
                    if [[ "$run_onboard" == "y" || "$run_onboard" == "Y" ]]; then
                        openclaw onboard --install-daemon
                    else
                        echo ""
                        echo -e "  ${YELLOW}稍后可手动运行:${NC}"
                        echo -e "  ${CYAN}openclaw onboard --install-daemon${NC}"
                    fi
                else
                    log_error "OpenClaw 安装失败"
                fi
                press_any_key
                ;;
            2)
                clear
                draw_title_line "Docker 部署 OpenClaw" 50
                echo ""

                # 检查 Docker
                if ! command -v docker &>/dev/null || ! docker compose version &>/dev/null 2>&1; then
                    echo -e "  ${YELLOW}⚠ Docker 或 Docker Compose 未安装${NC}"
                    echo ""
                    read -p "是否自动安装 Docker? (y/n): " install_docker </dev/tty
                    if [[ "$install_docker" == "y" || "$install_docker" == "Y" ]]; then
                        log_info "正在安装 Docker..."
                        # 国内优先腾讯云源，国外用官方源
                        if curl -s --max-time 3 https://mirrors.cloud.tencent.com >/dev/null 2>&1; then
                            curl -fsSL https://get.docker.com | bash -s docker --mirror https://mirrors.cloud.tencent.com/docker-ce
                        else
                            curl -fsSL https://get.docker.com | bash
                        fi
                        sudo systemctl enable docker 2>/dev/null || true
                        sudo systemctl start docker 2>/dev/null || true

                        if ! command -v docker &>/dev/null || ! docker compose version &>/dev/null 2>&1; then
                            log_error "Docker 安装失败，请手动安装后重试"
                            press_any_key
                            continue
                        fi
                        log_success "Docker 安装成功"
                        echo ""
                    else
                        log_info "操作已取消"
                        press_any_key
                        continue
                    fi
                fi

                local oc_dir="/opt/openclaw"

                echo -e "  ${WHITE}${BOLD}Docker 部署配置${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                echo ""

                # 自定义安装目录
                read -p "安装目录 [${oc_dir}]: " input_dir </dev/tty
                [[ -n "$input_dir" ]] && oc_dir="$input_dir"
                if ! is_safe_project_dir "$oc_dir"; then
                    log_error "安装目录不安全，请使用类似 /opt/openclaw 的独立目录。"
                    press_any_key
                    continue
                fi

                # 端口
                local oc_port="18789"
                read -p "网关端口 [${oc_port}]: " input_port </dev/tty
                [[ -n "$input_port" ]] && oc_port="$input_port"
                if ! is_valid_port "$oc_port"; then
                    log_error "端口无效，请输入 1-65535 之间的数字。"
                    press_any_key
                    continue
                fi
                if ! confirm_port_available "$oc_port" "网关端口"; then
                    log_info "操作已取消"
                    press_any_key
                    continue
                fi

                # API Key 配置
                echo ""
                echo -e "  ${WHITE}${BOLD}API Key 配置 (至少配置一个)${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                echo -e "  ${DIM}留空可跳过，稍后在配置文件中补充${NC}"
                echo ""
                read -s -p "Anthropic API Key (sk-ant-...): " anthropic_key </dev/tty
                echo ""
                read -s -p "OpenAI API Key (sk-...): " openai_key </dev/tty
                echo ""

                # 生成 Gateway Token
                local gw_token
                gw_token=$(generate_secret 32)

                echo ""
                echo -e "  ${WHITE}${BOLD}部署信息${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                echo -e "  安装目录:   ${CYAN}${oc_dir}${NC}"
                echo -e "  网关端口:   ${CYAN}${oc_port}${NC}"
                echo -e "  网关 Token: ${CYAN}${gw_token}${NC}"
                echo ""

                read -p "确认部署? (y/n): " confirm </dev/tty
                if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                    log_info "操作已取消"
                    press_any_key
                    continue
                fi

                if ! sudo mkdir -p "${oc_dir}/config" "${oc_dir}/workspace"; then
                    log_error "创建目录失败，请检查路径和权限"
                    press_any_key
                    continue
                fi

                # 生成 .env 文件
                sudo tee "${oc_dir}/.env" > /dev/null <<EOF
OPENCLAW_GATEWAY_TOKEN=${gw_token}
ANTHROPIC_API_KEY=${anthropic_key}
OPENAI_API_KEY=${openai_key}
EOF
                sudo chmod 600 "${oc_dir}/.env"

                # 生成 docker-compose.yml
                sudo tee "${oc_dir}/docker-compose.yml" > /dev/null <<EOF
services:
  openclaw:
    image: ghcr.io/openclaw/openclaw:latest
    container_name: openclaw
    ports:
      - "${oc_port}:18789"
    volumes:
      - ./config:/root/.openclaw
      - ./workspace:/root/workspace
    env_file:
      - .env
    environment:
      - NODE_ENV=production
      - NODE_OPTIONS=--max-old-space-size=4096
      - TZ=Asia/Shanghai
    command: node dist/index.js gateway --bind 0.0.0.0 --port 18789 --allow-unconfigured
    restart: unless-stopped
    mem_limit: 2g
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:18789/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF

                log_info "正在拉取 OpenClaw 镜像并启动..."
                if (cd "${oc_dir}" && sudo docker compose up -d); then
                    echo ""
                    log_success "OpenClaw 部署成功！"
                    echo ""
                    echo -e "  ${WHITE}${BOLD}访问信息${NC}"
                    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                    echo -e "  地址:  ${CYAN}http://服务器IP:${oc_port}${NC}"
                    echo -e "  Token: ${CYAN}${gw_token}${NC}"
                    echo -e "  目录:  ${CYAN}${oc_dir}${NC}"
                    echo ""
                    echo -e "  ${YELLOW}提示: 请妥善保存 Gateway Token，连接时需要使用${NC}"
                else
                    log_error "部署失败，请检查 Docker 日志"
                fi
                press_any_key
                ;;
            3)
                clear
                draw_title_line "启动 / 停止 OpenClaw" 50
                echo ""

                # 检测安装方式
                if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "openclaw"; then
                    local status=$(docker inspect -f '{{.State.Status}}' openclaw 2>/dev/null)
                    echo -e "  ${WHITE}安装方式: Docker${NC}"
                    echo -e "  ${WHITE}当前状态: ${NC}${status}"
                    echo ""
                    echo -e "  ${CYAN}1.${NC} 启动"
                    echo -e "  ${CYAN}2.${NC} 停止"
                    echo -e "  ${CYAN}3.${NC} 重启"
                    echo ""
                    read -p "请选择 [1-3]: " oc_action </dev/tty
                    case $oc_action in
                        1) sudo docker start openclaw && log_success "OpenClaw 已启动" ;;
                        2) sudo docker stop openclaw && log_success "OpenClaw 已停止" ;;
                        3) sudo docker restart openclaw && log_success "OpenClaw 已重启" ;;
                    esac
                elif command -v openclaw &>/dev/null; then
                    echo -e "  ${WHITE}安装方式: npm${NC}"
                    echo ""
                    echo -e "  ${CYAN}1.${NC} 启动网关服务"
                    echo -e "  ${CYAN}2.${NC} 停止网关服务"
                    echo ""
                    read -p "请选择 [1-2]: " oc_action </dev/tty
                    case $oc_action in
                        1)
                            local oc_port="18789"
                            read -p "网关端口 [${oc_port}]: " input_port </dev/tty
                            [[ -n "$input_port" ]] && oc_port="$input_port"
                            if ! is_valid_port "$oc_port"; then
                                log_error "端口无效，请输入 1-65535 之间的数字。"
                                press_any_key
                                continue
                            fi
                            if ! confirm_port_available "$oc_port" "网关端口"; then
                                log_info "操作已取消"
                                press_any_key
                                continue
                            fi
                            echo ""
                            log_info "正在后台启动 OpenClaw 网关..."
                            nohup openclaw gateway --port "$oc_port" > /var/log/openclaw.log 2>&1 &
                            log_success "OpenClaw 网关已启动 (端口: $oc_port, PID: $!)"
                            ;;
                        2)
                            pkill -f "openclaw gateway" 2>/dev/null && \
                                log_success "OpenClaw 网关已停止" || \
                                log_warning "未发现运行中的 OpenClaw 进程"
                            ;;
                    esac
                else
                    log_warning "OpenClaw 未安装"
                fi
                press_any_key
                ;;
            4)
                clear
                draw_title_line "OpenClaw 状态 / 日志" 50
                echo ""

                if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "openclaw"; then
                    echo -e "  ${WHITE}${BOLD}Docker 容器状态${NC}"
                    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                    docker ps -a --filter "name=openclaw" --format "table {{.Status}}\t{{.Ports}}" 2>/dev/null
                    echo ""
                    echo -e "  ${WHITE}${BOLD}最近日志 (最后 30 行)${NC}"
                    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                    sudo docker logs --tail 30 openclaw 2>/dev/null || log_error "无法读取日志"
                elif command -v openclaw &>/dev/null; then
                    echo -e "  ${WHITE}${BOLD}npm 安装信息${NC}"
                    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                    echo -e "  版本: $(openclaw --version 2>/dev/null || echo '未知')"
                    echo ""
                    if [[ -f /var/log/openclaw.log ]]; then
                        echo -e "  ${WHITE}${BOLD}最近日志 (最后 30 行)${NC}"
                        echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                        tail -30 /var/log/openclaw.log
                    fi
                else
                    log_warning "OpenClaw 未安装"
                fi
                press_any_key
                ;;
            5)
                clear
                draw_title_line "卸载 OpenClaw" 50
                echo ""

                local has_docker=0 has_npm=0
                docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "openclaw" && has_docker=1
                command -v openclaw &>/dev/null && has_npm=1

                if [[ $has_docker -eq 0 && $has_npm -eq 0 ]]; then
                    log_warning "OpenClaw 未安装，无需卸载"
                    press_any_key
                    continue
                fi

                echo -e "  ${RED}${BOLD}⚠ 警告：此操作将卸载 OpenClaw！${NC}"
                echo ""
                [[ $has_docker -eq 1 ]] && echo -e "  ${CYAN}1.${NC} 卸载 Docker 部署"
                [[ $has_npm -eq 1 ]]    && echo -e "  ${CYAN}2.${NC} 卸载 npm 全局安装"
                echo ""
                read -p "请选择 [1-2]: " uninstall_choice </dev/tty

                case $uninstall_choice in
                    1)
                        if [[ $has_docker -eq 1 ]]; then
                            read -p "确认卸载 Docker 版 OpenClaw? (y/n): " confirm </dev/tty
                            if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                                sudo docker stop openclaw 2>/dev/null || true
                                sudo docker rm openclaw 2>/dev/null || true
                                sudo docker rmi ghcr.io/openclaw/openclaw 2>/dev/null || true
                                echo ""
                                read -p "是否同时删除数据目录? (y/n): " del_data </dev/tty
                                if [[ "$del_data" == "y" || "$del_data" == "Y" ]]; then
                                    read -p "数据目录路径 [/opt/openclaw]: " data_dir </dev/tty
                                    data_dir=${data_dir:-/opt/openclaw}
                                    if is_safe_project_dir "$data_dir"; then
                                        sudo rm -rf -- "$data_dir"
                                        log_info "数据目录已删除"
                                    else
                                        log_error "数据目录路径不安全，已取消删除。"
                                    fi
                                fi
                                log_success "OpenClaw (Docker) 已卸载"
                            fi
                        else
                            log_warning "未检测到 Docker 版 OpenClaw"
                        fi
                        ;;
                    2)
                        if [[ $has_npm -eq 1 ]]; then
                            read -p "确认卸载 npm 版 OpenClaw? (y/n): " confirm </dev/tty
                            if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                                pkill -f "openclaw gateway" 2>/dev/null || true
                                npm uninstall -g openclaw
                                log_success "OpenClaw (npm) 已卸载"
                            fi
                        else
                            log_warning "未检测到 npm 版 OpenClaw"
                        fi
                        ;;
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
