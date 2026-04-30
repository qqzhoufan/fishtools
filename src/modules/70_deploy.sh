# 核心功能：部署单个预设项目的逻辑
# 获取项目默认端口
get_project_default_port() {
    case "$1" in
        homepage) echo "3000" ;;
        nginx-proxy-manager) echo "81" ;;
        navidrome) echo "4533" ;;
        qbittorrent) echo "8081" ;;
        moontv) echo "3002" ;;
        portainer) echo "9000" ;;
        alist) echo "5244" ;;
        uptime-kuma) echo "3001" ;;
        vaultwarden) echo "8088" ;;
        filebrowser) echo "8080" ;;
        adguardhome) echo "3004" ;;
        calibre-web) echo "8083" ;;
        gitea) echo "3003" ;;
        jellyfin) echo "8096" ;;
        nextcloud) echo "8090" ;;
        photoprism) echo "2342" ;;
        syncthing) echo "8384" ;;
        transmission) echo "9091" ;;
        *) echo "8080" ;;
    esac
}

# 显示项目信息
show_project_info() {
    local project_name="$1"
    local port=$(get_project_default_port "$project_name")

    echo -e "  ${WHITE}${BOLD}项目信息${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"

    case "$project_name" in
        homepage)
            echo -e "  端口: ${CYAN}${port}${NC}"
            echo -e "  账号: ${CYAN}无需登录${NC}"
            echo -e "  说明: 精美个人导航仪表盘"
            ;;
        nginx-proxy-manager)
            echo -e "  端口: ${CYAN}80, ${port}, 443${NC}"
            echo -e "  账号: ${CYAN}admin@example.com${NC}"
            echo -e "  密码: ${CYAN}changeme${NC}"
            echo -e "  说明: 可视化反向代理管理器"
            ;;
        navidrome)
            echo -e "  端口: ${CYAN}${port}${NC}"
            echo -e "  账号: ${CYAN}首次访问自行创建${NC}"
            echo -e "  说明: 自托管音乐流媒体服务器"
            ;;
        qbittorrent)
            echo -e "  端口: ${CYAN}${port} (WebUI), 6881 (BT)${NC}"
            echo -e "  账号: ${CYAN}admin${NC}"
            echo -e "  密码: ${CYAN}docker logs qbittorrent 查看${NC}"
            echo -e "  说明: 高性能 BT/磁力下载器"
            ;;
        moontv)
            echo -e "  端口: ${CYAN}${port}${NC}"
            echo -e "  账号: ${CYAN}admin${NC}"
            echo -e "  密码: ${CYAN}部署时自动生成${NC}"
            echo -e "  说明: 影视聚合平台"
            ;;
        portainer)
            echo -e "  端口: ${CYAN}${port}${NC}"
            echo -e "  账号: ${CYAN}首次访问自行创建${NC}"
            echo -e "  说明: Docker 可视化管理面板"
            ;;
        alist)
            echo -e "  端口: ${CYAN}${port}${NC}"
            echo -e "  账号: ${CYAN}admin${NC}"
            echo -e "  密码: ${CYAN}docker logs alist 查看${NC}"
            echo -e "  说明: 网盘聚合工具"
            ;;
        uptime-kuma)
            echo -e "  端口: ${CYAN}${port}${NC}"
            echo -e "  账号: ${CYAN}首次访问自行创建${NC}"
            echo -e "  说明: 轻量级服务监控面板"
            ;;
        vaultwarden)
            echo -e "  端口: ${CYAN}${port}${NC}"
            echo -e "  账号: ${CYAN}首次访问自行注册${NC}"
            echo -e "  说明: 自托管密码管理器"
            ;;
        filebrowser)
            echo -e "  端口: ${CYAN}${port}${NC}"
            echo -e "  账号: ${CYAN}admin${NC}"
            echo -e "  密码: ${CYAN}admin${NC}"
            echo -e "  说明: Web 文件管理器"
            ;;
        *)
            echo -e "  端口: ${CYAN}${port}${NC}"
            ;;
    esac
    echo ""
}

GENERATED_CREDENTIALS=()

harden_preset_secrets() {
    local project_name="$1"
    local dest_file="$2"
    GENERATED_CREDENTIALS=()

    case "$project_name" in
        moontv)
            local admin_password
            admin_password=$(generate_secret 20)
            sudo sed -i "s|PASSWORD=admin_password|PASSWORD=${admin_password}|g" "$dest_file"
            GENERATED_CREDENTIALS+=("MoonTV 登录: admin / ${admin_password}")
            ;;
        transmission)
            local admin_password
            admin_password=$(generate_secret 20)
            sudo sed -i "s|PASS=admin123|PASS=${admin_password}|g" "$dest_file"
            GENERATED_CREDENTIALS+=("Transmission 登录: admin / ${admin_password}")
            ;;
        gitea)
            local db_password
            db_password=$(generate_secret 24)
            sudo sed -i "s|POSTGRES_PASSWORD=gitea|POSTGRES_PASSWORD=${db_password}|g" "$dest_file"
            sudo sed -i "s|GITEA__database__PASSWD=gitea|GITEA__database__PASSWD=${db_password}|g" "$dest_file"
            GENERATED_CREDENTIALS+=("Gitea 数据库密码: ${db_password}")
            ;;
        nextcloud)
            local root_password db_password
            root_password=$(generate_secret 24)
            db_password=$(generate_secret 24)
            sudo sed -i "s|MYSQL_ROOT_PASSWORD=nextcloud_root|MYSQL_ROOT_PASSWORD=${root_password}|g" "$dest_file"
            sudo sed -i "s|MYSQL_PASSWORD=nextcloud|MYSQL_PASSWORD=${db_password}|g" "$dest_file"
            GENERATED_CREDENTIALS+=("Nextcloud 数据库 root 密码: ${root_password}")
            GENERATED_CREDENTIALS+=("Nextcloud 数据库用户密码: ${db_password}")
            ;;
        photoprism)
            local admin_password root_password db_password
            admin_password=$(generate_secret 20)
            root_password=$(generate_secret 24)
            db_password=$(generate_secret 24)
            sudo sed -i "s|PHOTOPRISM_ADMIN_PASSWORD=admin123|PHOTOPRISM_ADMIN_PASSWORD=${admin_password}|g" "$dest_file"
            sudo sed -i "s|MYSQL_ROOT_PASSWORD=photoprism_root|MYSQL_ROOT_PASSWORD=${root_password}|g" "$dest_file"
            sudo sed -i "s|MYSQL_PASSWORD=photoprism|MYSQL_PASSWORD=${db_password}|g" "$dest_file"
            sudo sed -i "s|PHOTOPRISM_DATABASE_PASSWORD=photoprism|PHOTOPRISM_DATABASE_PASSWORD=${db_password}|g" "$dest_file"
            GENERATED_CREDENTIALS+=("PhotoPrism 登录: admin / ${admin_password}")
            GENERATED_CREDENTIALS+=("PhotoPrism 数据库 root 密码: ${root_password}")
            GENERATED_CREDENTIALS+=("PhotoPrism 数据库用户密码: ${db_password}")
            ;;
    esac

    if [[ ${#GENERATED_CREDENTIALS[@]} -gt 0 ]]; then
        sudo chmod 600 "$dest_file" 2>/dev/null || true
    fi
}

# 部署预设项目
deploy_preset_project() {
    local project_name="$1"
    if [[ -z "$project_name" ]]; then log_error "内部错误。"; return 1; fi

    local default_port=$(get_project_default_port "$project_name")
    local project_dir="/opt/${project_name}"
    local dest_file="${project_dir}/docker-compose.yml"
    local url_yaml="https://raw.githubusercontent.com/${AUTHOR_GITHUB_USER}/${MAIN_REPO_NAME}/main/presets/${project_name}/docker-compose.yaml"
    local url_yml="https://raw.githubusercontent.com/${AUTHOR_GITHUB_USER}/${MAIN_REPO_NAME}/main/presets/${project_name}/docker-compose.yml"

    clear
    draw_title_line "部署 ${project_name}" 50
    echo ""
    log_info "即将部署精选项目: ${project_name}"
    echo ""

    # 显示项目信息
    show_project_info "$project_name"

    # 检查 Docker
    if ! command -v docker &>/dev/null || ! docker compose version &>/dev/null; then
        log_error "Docker 或 Compose 未安装。"
        return 1
    fi

    # 选择部署方式
    echo -e "  ${WHITE}${BOLD}请选择部署方式:${NC}"
    echo -e "  ${CYAN}1.${NC} 使用默认配置 ${DIM}(推荐)${NC}"
    echo -e "  ${CYAN}2.${NC} 自定义配置"
    echo ""
    read -p "请选择 [1-2]: " deploy_mode </dev/tty
    if [[ "$deploy_mode" != "1" && "$deploy_mode" != "2" ]]; then
        log_error "无效部署方式。"
        return 1
    fi

    local custom_dir="$project_dir"
    local custom_port="$default_port"
    local custom_tz="Asia/Shanghai"

    if [[ "$deploy_mode" == "2" ]]; then
        echo ""
        echo -e "  ${WHITE}${BOLD}自定义配置${NC}"
        echo -e "  ${GRAY}──────────────────────────────────────────${NC}"

        # 自定义安装目录
        read -p "安装目录 [${project_dir}]: " input_dir </dev/tty
        [[ -n "$input_dir" ]] && custom_dir="$input_dir"

        # 自定义端口
        read -p "主端口 [${default_port}]: " input_port </dev/tty
        [[ -n "$input_port" ]] && custom_port="$input_port"

        # 自定义时区
        read -p "时区 [Asia/Shanghai]: " input_tz </dev/tty
        [[ -n "$input_tz" ]] && custom_tz="$input_tz"

        project_dir="$custom_dir"
        dest_file="${project_dir}/docker-compose.yml"
    fi

    if ! is_safe_project_dir "$project_dir"; then
        log_error "安装目录不安全，请使用类似 /opt/${project_name} 的独立目录。"
        return 1
    fi
    if ! is_valid_port "$custom_port"; then
        log_error "端口无效，请输入 1-65535 之间的数字。"
        return 1
    fi
    if ! is_valid_timezone "$custom_tz"; then
        log_error "时区格式无效，请使用类似 Asia/Shanghai 或 Etc/UTC 的格式。"
        return 1
    fi
    if ! confirm_port_available "$custom_port" "主端口"; then
        log_info "操作已取消。"
        return 0
    fi

    echo ""
    echo -e "  ${WHITE}${BOLD}部署信息${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    echo -e "  安装目录: ${CYAN}${project_dir}${NC}"
    echo -e "  主端口:   ${CYAN}${custom_port}${NC}"
    echo -e "  时区:     ${CYAN}${custom_tz}${NC}"
    echo ""

    read -p "确认部署? (y/n): " confirm </dev/tty
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "操作已取消。"
        return 0
    fi

    local project_dir_created=0
    [[ ! -e "$project_dir" ]] && project_dir_created=1

    log_info "正在创建项目目录..."
    if ! sudo mkdir -p "$project_dir"; then
        log_error "创建项目目录失败，请检查路径和权限。"
        return 1
    fi
    log_info "正在下载配置文件..."

    if sudo curl -sLf -o "${dest_file}" "${url_yaml}"; then
        log_success "成功下载 docker-compose.yaml。"
    else
        log_warning "未找到 docker-compose.yaml，正在尝试 docker-compose.yml ..."
        if sudo curl -sLf -o "${dest_file}" "${url_yml}"; then
            log_success "成功下载 docker-compose.yml。"
        else
            log_error "下载失败！"
            cleanup_failed_project_dir "$project_dir" "$dest_file" "$project_dir_created"
            return 1
        fi
    fi

    # 如果是自定义配置，替换配置文件中的端口和时区
    if [[ "$deploy_mode" == "2" ]]; then
        log_info "正在应用自定义配置..."
        # 只替换端口映射左侧的宿主机端口，避免改坏容器内部端口
        sudo sed -i "s/- ${default_port}:/- ${custom_port}:/g" "${dest_file}" 2>/dev/null || true
        sudo sed -i "s/'${default_port}:/'${custom_port}:/g" "${dest_file}" 2>/dev/null || true
        sudo sed -i "s/\"${default_port}:/\"${custom_port}:/g" "${dest_file}" 2>/dev/null || true
        sudo sed -i "s|localhost:${default_port}|localhost:${custom_port}|g" "${dest_file}" 2>/dev/null || true
        # 替换时区
        sudo sed -i "s|Asia/Shanghai|${custom_tz}|g" "${dest_file}" 2>/dev/null || true
        sudo sed -i "s|TZ=.*|TZ=${custom_tz}|g" "${dest_file}" 2>/dev/null || true
    fi

    harden_preset_secrets "$project_name" "$dest_file"

    log_info "启动项目中..."
    if (cd "$project_dir" && sudo docker compose up -d); then
        echo ""
        log_success "项目 '$project_name' 已成功部署！"
        echo ""
        echo -e "  ${WHITE}${BOLD}访问地址${NC}"
        echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
        echo -e "  http://服务器IP:${custom_port}"
    else
        log_error "项目部署失败！"
        return 1
    fi
}

# 新增功能：安装后提示信息
show_post_install_message() {
    local project_name="$1"
    echo ""
    if [[ ${#GENERATED_CREDENTIALS[@]} -gt 0 ]]; then
        echo -e "  ${YELLOW}╭───────────────────────────────────────╮${NC}"
        echo -e "  ${YELLOW}│${NC}  ${WHITE}${BOLD}已自动生成随机凭据${NC}                  ${YELLOW}│${NC}"
        echo -e "  ${YELLOW}├───────────────────────────────────────┤${NC}"
        local item
        for item in "${GENERATED_CREDENTIALS[@]}"; do
            echo -e "  ${YELLOW}│${NC}  ${CYAN}${item}${NC}"
        done
        echo -e "  ${YELLOW}╰───────────────────────────────────────╯${NC}"
        echo -e "  ${YELLOW}提示: 这些凭据只显示一次，已写入 docker-compose.yml。${NC}"
        GENERATED_CREDENTIALS=()
        return
    fi
    case $project_name in
        "qbittorrent")
            echo -e "  ${YELLOW}╭───────────────────────────────────────╮${NC}"
            echo -e "  ${YELLOW}│${NC}  ${WHITE}${BOLD}qBittorrent 默认登录信息${NC}            ${YELLOW}│${NC}"
            echo -e "  ${YELLOW}├───────────────────────────────────────┤${NC}"
            echo -e "  ${YELLOW}│${NC}  用户名: ${CYAN}admin${NC}                      ${YELLOW}│${NC}"
            echo -e "  ${YELLOW}│${NC}  查看密码: ${CYAN}sudo docker logs qbittorrent${NC}${YELLOW}│${NC}"
            echo -e "  ${YELLOW}╰───────────────────────────────────────╯${NC}"
            ;;
        "moontv")
            echo -e "  ${YELLOW}╭───────────────────────────────────────╮${NC}"
            echo -e "  ${YELLOW}│${NC}  ${WHITE}${BOLD}MoonTV 默认登录信息${NC}                 ${YELLOW}│${NC}"
            echo -e "  ${YELLOW}├───────────────────────────────────────┤${NC}"
            echo -e "  ${YELLOW}│${NC}  用户名: ${CYAN}admin${NC}                      ${YELLOW}│${NC}"
            echo -e "  ${YELLOW}│${NC}  密  码: ${CYAN}admin_password${NC}             ${YELLOW}│${NC}"
            echo -e "  ${YELLOW}╰───────────────────────────────────────╯${NC}"
            ;;
        "nginx-proxy-manager")
            echo -e "  ${YELLOW}╭───────────────────────────────────────╮${NC}"
            echo -e "  ${YELLOW}│${NC}  ${WHITE}${BOLD}Nginx Proxy Manager 默认登录信息${NC}    ${YELLOW}│${NC}"
            echo -e "  ${YELLOW}├───────────────────────────────────────┤${NC}"
            echo -e "  ${YELLOW}│${NC}  邮  箱: ${CYAN}admin@example.com${NC}          ${YELLOW}│${NC}"
            echo -e "  ${YELLOW}│${NC}  密  码: ${CYAN}changeme${NC}                   ${YELLOW}│${NC}"
            echo -e "  ${YELLOW}│${NC}  ${RED}首次登录后请立即修改！${NC}              ${YELLOW}│${NC}"
            echo -e "  ${YELLOW}╰───────────────────────────────────────╯${NC}"
            ;;
        *)
            # 其他项目没有特殊提示
            ;;
    esac
}

# 子菜单：显示预设项目
show_preset_deployment_menu() {
    while true; do
        clear
        draw_title_line "一键部署精选项目" 50
        echo -e "  ${DIM}by 咸鱼银河${NC}"
        echo ""
        echo -e "  ${WHITE}${BOLD}【常用服务】${NC}"
        draw_menu_item "1" "🏠" "Homepage (精美起始页)"
        draw_menu_item "2" "🔀" "Nginx-Proxy-Manager (反代神器)"
        draw_menu_item "3" "🐳" "Portainer (Docker 可视化管理)"
        draw_menu_item "4" "📁" "Alist (网盘聚合)"
        draw_menu_item "5" "📊" "Uptime Kuma (服务监控)"
        echo ""
        echo -e "  ${WHITE}${BOLD}【媒体娱乐】${NC}"
        draw_menu_item "6" "🎵" "Navidrome (音乐服务器)"
        draw_menu_item "7" "📥" "qBittorrent (下载器)"
        draw_menu_item "8" "📺" "MoonTV (观影聚合)"
        draw_menu_item "9" "🎬" "Jellyfin (媒体服务器)"
        draw_menu_item "10" "📷" "PhotoPrism (AI 照片管理)"
        echo ""
        echo -e "  ${WHITE}${BOLD}【工具应用】${NC}"
        draw_menu_item "11" "🔐" "Vaultwarden (密码管理器)"
        draw_menu_item "12" "📂" "FileBrowser (文件管理器)"
        draw_menu_item "13" "☁️" "Nextcloud (私有云盘)"
        draw_menu_item "14" "🔧" "Gitea (Git 服务)"
        draw_menu_item "15" "📚" "Calibre-Web (电子书管理)"
        draw_menu_item "16" "🔄" "Syncthing (文件同步)"
        echo ""
        echo -e "  ${WHITE}${BOLD}【网络工具】${NC}"
        draw_menu_item "17" "🌐" "AdGuard Home (DNS 广告过滤)"
        draw_menu_item "18" "⬇️" "Transmission (BT 下载)"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回上一级菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请选择要部署的项目${NC} [0-18]: )" preset_choice </dev/tty

        local project_to_deploy=""
        case $preset_choice in
            1) project_to_deploy="homepage" ;;
            2) project_to_deploy="nginx-proxy-manager" ;;
            3) project_to_deploy="portainer" ;;
            4) project_to_deploy="alist" ;;
            5) project_to_deploy="uptime-kuma" ;;
            6) project_to_deploy="navidrome" ;;
            7) project_to_deploy="qbittorrent" ;;
            8) project_to_deploy="moontv" ;;
            9) project_to_deploy="jellyfin" ;;
            10) project_to_deploy="photoprism" ;;
            11) project_to_deploy="vaultwarden" ;;
            12) project_to_deploy="filebrowser" ;;
            13) project_to_deploy="nextcloud" ;;
            14) project_to_deploy="gitea" ;;
            15) project_to_deploy="calibre-web" ;;
            16) project_to_deploy="syncthing" ;;
            17) project_to_deploy="adguardhome" ;;
            18) project_to_deploy="transmission" ;;
            0) break ;;
            *) log_error "无效输入。"; press_any_key; continue ;;
        esac

        if [[ -n "$project_to_deploy" ]]; then
            if deploy_preset_project "$project_to_deploy"; then
                show_post_install_message "$project_to_deploy"
            fi
            press_any_key
        fi
    done
}
# 从自定义 GitHub 仓库部署
deploy_from_github() {
    clear
    draw_title_line "从 GitHub 仓库部署" 50
    echo ""
    echo -e "  ${WHITE}${BOLD}支持的仓库格式${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    echo -e "  • https://github.com/owner/repo"
    echo -e "  • github.com/owner/repo"
    echo -e "  • owner/repo"
    echo ""

    read -p "请输入 GitHub 仓库地址: " repo_url </dev/tty
    [[ -z "$repo_url" ]] && return 0

    # 解析仓库信息
    local owner repo
    repo_url="${repo_url#https://}"
    repo_url="${repo_url#http://}"
    repo_url="${repo_url#github.com/}"

    owner=$(echo "$repo_url" | cut -d'/' -f1)
    repo=$(echo "$repo_url" | cut -d'/' -f2)
    repo="${repo%.git}"

    if [[ -z "$owner" || -z "$repo" ]] || [[ ! "$owner" =~ ^[A-Za-z0-9_.-]+$ ]] || [[ ! "$repo" =~ ^[A-Za-z0-9_.-]+$ ]]; then
        log_error "无法解析仓库地址！"
        return 1
    fi

    echo ""
    log_info "仓库: ${owner}/${repo}"

    # 检查 Docker
    if ! command -v docker &>/dev/null || ! docker compose version &>/dev/null; then
        log_error "Docker 或 Compose 未安装。"
        return 1
    fi

    # 输入安装目录
    local default_dir="/opt/${repo}"
    read -p "安装目录 [${default_dir}]: " project_dir </dev/tty
    [[ -z "$project_dir" ]] && project_dir="$default_dir"

    if ! is_safe_project_dir "$project_dir"; then
        log_error "安装目录不安全，请使用类似 /opt/${repo} 的独立目录。"
        return 1
    fi

    local dest_file="${project_dir}/docker-compose.yml"
    local project_dir_created=0
    [[ ! -e "$project_dir" ]] && project_dir_created=1

    # 尝试下载 docker-compose 文件
    log_info "正在从仓库下载配置文件..."
    if ! sudo mkdir -p "$project_dir"; then
        log_error "创建项目目录失败，请检查路径和权限。"
        return 1
    fi

    local raw_base="https://raw.githubusercontent.com/${owner}/${repo}/main"
    local downloaded=0

    # 尝试多个可能的路径
    for path in "docker-compose.yml" "docker-compose.yaml" "compose.yml" "compose.yaml"; do
        if sudo curl -sLf -o "${dest_file}" "${raw_base}/${path}" 2>/dev/null; then
            log_success "成功下载 ${path}"
            downloaded=1
            break
        fi
    done

    # 尝试 master 分支
    if [[ $downloaded -eq 0 ]]; then
        raw_base="https://raw.githubusercontent.com/${owner}/${repo}/master"
        for path in "docker-compose.yml" "docker-compose.yaml" "compose.yml" "compose.yaml"; do
            if sudo curl -sLf -o "${dest_file}" "${raw_base}/${path}" 2>/dev/null; then
                log_success "成功下载 ${path} (master 分支)"
                downloaded=1
                break
            fi
        done
    fi

    if [[ $downloaded -eq 0 ]]; then
        log_error "未找到 docker-compose 配置文件！"
        log_warning "请确认仓库根目录存在 docker-compose.yml 或 compose.yml"
        cleanup_failed_project_dir "$project_dir" "$dest_file" "$project_dir_created"
        return 1
    fi

    echo ""
    echo -e "  ${WHITE}${BOLD}部署信息${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    echo -e "  仓库:     ${CYAN}${owner}/${repo}${NC}"
    echo -e "  安装目录: ${CYAN}${project_dir}${NC}"
    echo ""

    read -p "确认部署? (y/n): " confirm </dev/tty
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_info "操作已取消。"
        cleanup_failed_project_dir "$project_dir" "$dest_file" "$project_dir_created"
        return 0
    fi

    log_info "启动项目中..."
    if (cd "$project_dir" && sudo docker compose up -d); then
        echo ""
        log_success "项目 '${repo}' 已成功部署！"
        echo ""
        echo -e "  ${WHITE}${BOLD}项目目录${NC}"
        echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
        echo -e "  ${project_dir}"
    else
        log_error "项目部署失败！"
        return 1
    fi
}

# 子菜单：部署功能主菜单
show_deployment_menu() {
    while true; do
        clear
        draw_title_line "Docker Compose 部署" 50
        echo ""
        draw_menu_item "1" "⭐" "一键部署精选项目 (推荐)"
        draw_menu_item "2" "🔧" "从自定义 GitHub 仓库部署 (高级)"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回主菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请选择部署方式${NC} [0-2]: )" deploy_choice </dev/tty
        case $deploy_choice in
            1) show_preset_deployment_menu ;;
            2) deploy_from_github; press_any_key ;;
            0) break ;;
            *) log_error "无效输入。"; press_any_key ;;
        esac
    done
}
