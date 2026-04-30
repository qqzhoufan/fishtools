# --- 更新检查 ---
get_release_ref() {
    local ref_sha
    ref_sha=$(curl -fsSL --connect-timeout 5 --max-time 10 --retry 1 \
        -H "Accept: application/vnd.github+json" \
        -H "Cache-Control: no-cache" \
        "https://api.github.com/repos/${AUTHOR_GITHUB_USER}/${MAIN_REPO_NAME}/git/ref/heads/main" 2>/dev/null \
        | sed -n 's/.*"sha"[[:space:]]*:[[:space:]]*"\([0-9a-f]\{40\}\)".*/\1/p' \
        | head -1)
    echo "${ref_sha:-main}"
}

get_release_url() {
    local ref
    local nonce
    ref="$(get_release_ref)"
    nonce="$(date +%s 2>/dev/null || echo "$RANDOM")"
    echo "https://raw.githubusercontent.com/${AUTHOR_GITHUB_USER}/${MAIN_REPO_NAME}/${ref}/fishtools.sh?ts=${nonce}"
}

download_release_file() {
    local dest="$1"
    curl -fsSL --connect-timeout 10 --max-time 30 --retry 2 --retry-delay 1 \
        -H "Cache-Control: no-cache" \
        -H "Pragma: no-cache" \
        "$(get_release_url)" -o "$dest"
}

read_remote_release() {
    curl -fsSL --connect-timeout 5 --max-time 10 --retry 1 \
        -H "Cache-Control: no-cache" \
        -H "Pragma: no-cache" \
        "$(get_release_url)"
}

check_update() {
    local remote_version
    remote_version=$(read_remote_release 2>/dev/null | grep -oP 'VERSION="v\K[0-9.]+' | head -1)
    local current_version="${VERSION#v}"

    if [[ -n "$remote_version" && "$remote_version" != "$current_version" ]]; then
        echo ""
        echo -e "${YELLOW}  +-------------------------------------------+${NC}"
        echo -e "${YELLOW}  |${NC}  ${WHITE}${BOLD}发现新版本 ${GREEN}v${remote_version}${NC} ${DIM}(当前 ${VERSION})${NC}"
        echo -e "${YELLOW}  |${NC}  运行以下命令更新:"
        echo -e "${YELLOW}  |${NC}  ${CYAN}fish --update${NC}"
        echo -e "${YELLOW}  +-------------------------------------------+${NC}"
        echo ""
    fi
}

# --- 帮助信息 ---
show_help() {
    echo ""
    echo -e "${CYAN}fishtools${NC} - 咸鱼工具箱 ${VERSION}"
    echo ""
    echo -e "${WHITE}用法:${NC}"
    echo "  fish [选项]           # 安装后可直接使用"
    echo "  ./fishtools.sh [选项] # 或直接运行脚本"
    echo ""
    echo -e "${WHITE}选项:${NC}"
    echo "  -h, --help       显示帮助信息"
    echo "  -v, --version    显示版本信息"
    echo "  -u, --update     检查并更新脚本"
    echo "  --install        安装 fish 命令到系统"
    echo "  --uninstall      卸载 fish 命令"
    echo "  --info           显示系统信息"
    echo "  --doctor         运行全功能巡检"
    echo "  --bbr            一键开启 BBR"
    echo "  --docker         进入 Docker 管理"
    echo "  --test           进入性能测试菜单"
    echo ""
    echo -e "${WHITE}示例:${NC}"
    echo "  fish --info      # 快速查看系统信息"
    echo "  fish --bbr       # 一键开启 BBR"
    echo ""
    echo -e "${WHITE}首次安装:${NC}"
    echo "  ./fishtools.sh --install   # 安装后即可使用 fish 命令"
    echo ""
}

# --- 命令行参数处理 ---
handle_args() {
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            echo "fishtools ${VERSION}"
            exit 0
            ;;
        -u|--update)
            echo -e "${CYAN}  ℹ 正在检查更新...${NC}"
            echo -e "${DIM}  当前路径: ${SCRIPT_PATH}${NC}"
            local script_dir
            script_dir="$(dirname "$SCRIPT_PATH")"
            local tmp_file
            tmp_file="$(mktemp "${script_dir}/.fishtools_new.XXXXXX" 2>/dev/null || mktemp /tmp/fishtools_new.XXXXXX)"
            if download_release_file "$tmp_file" 2>/dev/null; then
                local remote_ver=$(grep -oP 'VERSION="v\K[0-9.]+' "$tmp_file" | head -1)
                local current_ver="${VERSION#v}"
                [[ -n "$remote_ver" ]] && echo -e "${DIM}  远端版本: v${remote_ver} / 当前版本: ${VERSION}${NC}"
                if [[ -z "$remote_ver" ]]; then
                    echo -e "${RED}  ✗ 更新文件校验失败：未找到版本号${NC}"
                    rm -f "$tmp_file"
                elif command -v bash &>/dev/null && ! bash -n "$tmp_file" 2>/dev/null; then
                    echo -e "${RED}  ✗ 更新文件语法检查失败，已取消替换${NC}"
                    rm -f "$tmp_file"
                elif [[ "$remote_ver" != "$current_ver" ]] || ! cmp -s "$tmp_file" "$SCRIPT_PATH" 2>/dev/null; then
                    if [[ "$remote_ver" != "$current_ver" ]]; then
                        echo -e "${GREEN}  ✓ 发现新版本 v${remote_ver}，正在更新...${NC}"
                    else
                        echo -e "${GREEN}  ✓ 发现同版本内容更新，正在更新...${NC}"
                    fi
                    chmod +x "$tmp_file"
                    if mv "$tmp_file" "$SCRIPT_PATH" 2>/dev/null || sudo mv "$tmp_file" "$SCRIPT_PATH"; then
                        echo -e "${GREEN}  ✓ 更新完成！请重新运行脚本。${NC}"
                        local resolved_cmd
                        resolved_cmd="$(command -v fish 2>/dev/null || true)"
                        if [[ -n "$resolved_cmd" && "$(realpath "$resolved_cmd" 2>/dev/null || echo "$resolved_cmd")" != "$SCRIPT_PATH" ]]; then
                            echo -e "${YELLOW}  ⚠ 当前 fish 命令指向: ${resolved_cmd}${NC}"
                            echo -e "${YELLOW}  ⚠ 如版本仍未变化，请运行: sudo ${SCRIPT_PATH} --install${NC}"
                        fi
                    else
                        echo -e "${RED}  ✗ 替换脚本失败，请检查权限${NC}"
                        rm -f "$tmp_file"
                    fi
                else
                    echo -e "${GREEN}  ✓ 已是最新版本 ${VERSION}${NC}"
                    rm -f "$tmp_file"
                fi
            else
                echo -e "${RED}  ✗ 检查更新失败${NC}"
                rm -f "$tmp_file"
            fi
            exit 0
            ;;
        --info)
            show_machine_info
            exit 0
            ;;
        --doctor|--check)
            show_system_diagnostics --no-pause
            exit 0
            ;;
        --bbr)
            echo -e "${CYAN}  ℹ 正在开启 BBR...${NC}"
            enable_builtin_bbr
            exit 0
            ;;
        --docker)
            check_dependencies
            install_docker_menu
            exit 0
            ;;
        --test)
            check_dependencies
            show_test_menu
            exit 0
            ;;
        --install)
            echo ""
            echo -e "${CYAN}  ℹ 正在安装 fish 命令...${NC}"
            local install_path="/usr/local/bin/fish"
            local install_cmd="fish"

            # 检测是否已安装 fish shell，避免冲突
            local existing_fish=$(which fish 2>/dev/null)
            if [[ -n "$existing_fish" ]]; then
                # 检查是否是本脚本自身
                local fish_type=$(file -b "$existing_fish" 2>/dev/null || echo "")
                if [[ "$fish_type" != *"shell script"* && "$fish_type" != *"Bourne"* ]]; then
                    echo -e "${YELLOW}  ⚠ 检测到系统已安装 fish shell，将使用 fishtool 作为命令名${NC}"
                    install_path="/usr/local/bin/fishtool"
                    install_cmd="fishtool"
                fi
            fi

            # 复制脚本到目标位置
            if sudo cp "$SCRIPT_PATH" "$install_path" && sudo chmod +x "$install_path"; then
                echo -e "${GREEN}  ✓ 安装成功！${NC}"
                echo ""
                echo -e "  现在可以使用以下命令:"
                echo -e "    ${CYAN}${install_cmd}${NC}          # 启动工具箱"
                echo -e "    ${CYAN}${install_cmd} --help${NC}   # 查看帮助"
                echo -e "    ${CYAN}${install_cmd} --info${NC}   # 查看系统信息"
                echo -e "    ${CYAN}${install_cmd} --bbr${NC}    # 一键开启 BBR"
                echo ""
            else
                echo -e "${RED}  ✗ 安装失败，请使用 sudo 运行${NC}"
            fi
            exit 0
            ;;
        --uninstall)
            echo ""
            echo -e "${CYAN}  ℹ 正在卸载 fish 命令...${NC}"
            local removed=0
            if [[ -f "/usr/local/bin/fish" ]]; then
                sudo rm -f "/usr/local/bin/fish" && removed=1
            fi
            if [[ -f "/usr/local/bin/fishtool" ]]; then
                sudo rm -f "/usr/local/bin/fishtool" && removed=1
            fi
            if [[ $removed -eq 1 ]]; then
                echo -e "${GREEN}  ✓ 卸载成功！${NC}"
            else
                echo -e "${YELLOW}  ⚠ 未找到已安装的命令${NC}"
            fi
            exit 0
            ;;
        "")
            # 无参数，正常启动
            return 0
            ;;
        *)
            echo -e "${RED}未知选项: $1${NC}"
            echo "使用 --help 查看帮助"
            exit 1
            ;;
    esac
}
