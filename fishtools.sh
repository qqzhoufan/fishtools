#!/bin/bash

# =================================================================
# fishtools (咸鱼工具箱) v1.4.6
# Author: 咸鱼银河 (Xianyu Yinhe)
# Github: https://github.com/qqzhoufan/fishtools
#
# A powerful and modular toolkit for VPS management.
# =================================================================
#
# Release note:
#   fishtools.sh is generated from src/ by scripts/build-release.sh.
#   Edit src/* during development, then rebuild the single-file release.

# --- 全局配置 ---
AUTHOR_GITHUB_USER="qqzhoufan"
MAIN_REPO_NAME="fishtools"
VERSION="v1.4.6"
SCRIPT_PATH="$(realpath "$0" 2>/dev/null || echo "$0")"

# --- 颜色和样式定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# --- 临时文件清理 ---
_fishtools_cleanup() {
    rm -f reinstall.sh OsMutation.sh ecs.sh nt_install.sh \
          backtrace.sh superspeed.sh tools.sh swap.sh menu.sh \
          fish_ipcheck.sh 2>/dev/null
}
trap _fishtools_cleanup EXIT

# --- 通用包管理器工具 ---
# 检测系统包管理器类型（带缓存）
CACHED_PKG_MANAGER=""
detect_pkg_manager() {
    if [[ -n "$CACHED_PKG_MANAGER" ]]; then
        echo "$CACHED_PKG_MANAGER"
        return
    fi
    if command -v apt-get &>/dev/null; then
        CACHED_PKG_MANAGER="apt"
    elif command -v dnf &>/dev/null; then
        CACHED_PKG_MANAGER="dnf"
    elif command -v yum &>/dev/null; then
        CACHED_PKG_MANAGER="yum"
    else
        CACHED_PKG_MANAGER="unknown"
    fi
    echo "$CACHED_PKG_MANAGER"
}

# 获取公网 IPv4 地址
get_public_ipv4() {
    local ip=""
    ip=$(curl -s4 --connect-timeout 3 ip.sb 2>/dev/null) \
        || ip=$(curl -s4 --connect-timeout 3 ifconfig.me 2>/dev/null) \
        || ip=""
    echo "$ip"
}

# 更新包索引
pkg_update() {
    local pm=$(detect_pkg_manager)
    case "$pm" in
        apt) sudo apt-get update -qq ;;
        dnf) sudo dnf check-update -q 2>/dev/null; true ;;
        yum) sudo yum check-update -q 2>/dev/null; true ;;
        *) log_error "不支持的包管理器"; return 1 ;;
    esac
}

# 安装软件包 (支持 apt/dnf/yum)
pkg_install() {
    local pm=$(detect_pkg_manager)
    case "$pm" in
        apt) sudo apt-get install -y "$@" ;;
        dnf) sudo dnf install -y "$@" ;;
        yum) sudo yum install -y "$@" ;;
        *) log_error "不支持的包管理器，请手动安装: $*"; return 1 ;;
    esac
}

# 卸载软件包
pkg_remove() {
    local pm=$(detect_pkg_manager)
    case "$pm" in
        apt) sudo apt-get purge -y "$@" && sudo apt-get autoremove -y --purge ;;
        dnf) sudo dnf remove -y "$@" ;;
        yum) sudo yum remove -y "$@" ;;
        *) log_error "不支持的包管理器，请手动卸载: $*"; return 1 ;;
    esac
}

# --- 依赖检查 ---
check_dependencies() {
    local missing_deps=()
    local optional_deps=()

    # 必须依赖
    for cmd in curl; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    # 可选依赖（用于特定功能）
    for cmd in bc jq dig; do
        if ! command -v "$cmd" &>/dev/null; then
            optional_deps+=("$cmd")
        fi
    done

    # 如果缺少必须依赖，尝试安装
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${YELLOW}  ⚠ 检测到缺少必要依赖: ${missing_deps[*]}${NC}"
        echo -e "${CYAN}  ℹ 正在尝试自动安装...${NC}"
        if command -v apt-get &>/dev/null; then
            sudo apt-get update -qq && sudo apt-get install -y "${missing_deps[@]}" 2>/dev/null
        elif command -v yum &>/dev/null; then
            sudo yum install -y "${missing_deps[@]}" 2>/dev/null
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y "${missing_deps[@]}" 2>/dev/null
        fi
    fi

    # 可选依赖提示
    if [[ ${#optional_deps[@]} -gt 0 ]]; then
        : # 静默处理，不影响正常使用
    fi
}

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
        --bbr)
            echo -e "${CYAN}  ℹ 正在开启 BBR...${NC}"
            if grep -q "net.core.default_qdisc" /etc/sysctl.conf 2>/dev/null; then
                sudo sed -i 's/net.core.default_qdisc.*/net.core.default_qdisc=fq/' /etc/sysctl.conf
            else
                echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.conf >/dev/null
            fi
            if grep -q "net.ipv4.tcp_congestion_control" /etc/sysctl.conf 2>/dev/null; then
                sudo sed -i 's/net.ipv4.tcp_congestion_control.*/net.ipv4.tcp_congestion_control=bbr/' /etc/sysctl.conf
            else
                echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf >/dev/null
            fi
            sudo sysctl -p >/dev/null 2>&1
            if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q bbr; then
                echo -e "${GREEN}  ✓ BBR 已成功开启！${NC}"
            else
                echo -e "${RED}  ✗ BBR 开启失败，请检查内核版本${NC}"
            fi
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

# --- 边框字符 ---
# 默认使用 ASCII，避免 SSH/终端编码不一致时出现乱码。
# 如确认终端支持 box-drawing 字符，可使用 FISHTOOLS_UNICODE=1 fish 开启。
if [[ "${FISHTOOLS_UNICODE:-0}" == "1" ]]; then
    LINE_H="─"
    LINE_V="│"
    CORNER_TL="┌"
    CORNER_TR="┐"
    CORNER_BL="└"
    CORNER_BR="┘"
    T_LEFT="├"
    T_RIGHT="┤"
else
    LINE_H="-"
    LINE_V="|"
    CORNER_TL="+"
    CORNER_TR="+"
    CORNER_BL="+"
    CORNER_BR="+"
    T_LEFT="+"
    T_RIGHT="+"
fi

# --- 基础日志函数 ---
log_info() {
    echo -e "${CYAN}  ℹ ${NC}$1"
}
log_success() {
    echo -e "${GREEN}  ✓ ${NC}$1"
}
log_warning() {
    echo -e "${YELLOW}  ⚠ ${NC}$1"
}
log_error() {
    echo -e "${RED}  ✗ ${NC}$1"
}

# --- 通用安全与校验函数 ---
is_valid_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ ]] && [[ "$port" -ge 1 ]] && [[ "$port" -le 65535 ]]
}

is_valid_timezone() {
    local tz="$1"
    [[ "$tz" =~ ^[A-Za-z0-9_./+-]+$ ]] && [[ "$tz" != */../* ]] && [[ "$tz" != ../* ]]
}

is_valid_domain() {
    local domain="$1"
    [[ "$domain" =~ ^(\*\.)?[A-Za-z0-9]([A-Za-z0-9.-]{0,251}[A-Za-z0-9])?$ ]] && [[ "$domain" == *.* ]]
}

normalize_backend_url() {
    local backend="$1"
    if [[ "$backend" == http://* || "$backend" == https://* ]]; then
        echo "$backend"
    else
        echo "http://${backend}"
    fi
}

is_valid_backend_url() {
    local backend="$1"
    [[ "$backend" =~ ^https?://[A-Za-z0-9._-]+(:[0-9]{1,5})?$ ]] || return 1
    local port="${backend##*:}"
    if [[ "$port" =~ ^[0-9]+$ && "$backend" == *:* ]]; then
        is_valid_port "$port"
        return $?
    fi
    return 0
}

is_safe_project_dir() {
    local dir="$1"
    [[ "$dir" == /* ]] || return 1
    [[ "$dir" != *$'\n'* && "$dir" != *$'\r'* ]] || return 1
    [[ "$dir" != *"/../"* && "$dir" != */.. && "$dir" != */. ]] || return 1
    case "$dir" in
        "/"|"/bin"|"/boot"|"/dev"|"/etc"|"/home"|"/lib"|"/lib64"|"/opt"|"/proc"|"/root"|"/run"|"/sbin"|"/srv"|"/sys"|"/tmp"|"/usr"|"/usr/local"|"/usr/local/bin"|"/var"|"/var/lib")
            return 1
            ;;
    esac
    return 0
}

cleanup_failed_project_dir() {
    local project_dir="$1"
    local dest_file="$2"
    local was_created="$3"

    if [[ "$was_created" == "1" ]] && is_safe_project_dir "$project_dir"; then
        sudo rm -rf -- "$project_dir"
    else
        sudo rm -f -- "$dest_file"
    fi
}

safe_clean_tmp_files() {
    sudo find /tmp -xdev -mindepth 1 -maxdepth 1 -mmin +60 \
        ! -type s ! -name '.X11-unix' ! -name '.ICE-unix' \
        -exec rm -rf -- {} + 2>/dev/null || true
}

safe_clean_user_cache() {
    [[ -d "$HOME/.cache" ]] || return 0
    find "$HOME/.cache" -mindepth 1 -maxdepth 1 -mtime +7 \
        -exec rm -rf -- {} + 2>/dev/null || true
}

generate_secret() {
    local length="${1:-24}"
    local secret=""
    if command -v openssl &>/dev/null; then
        secret=$(openssl rand -base64 48 2>/dev/null | tr -dc 'A-Za-z0-9' | head -c "$length")
    fi
    if [[ -z "$secret" ]]; then
        secret=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$length")
    fi
    if [[ -z "$secret" ]]; then
        secret="fish$(date +%s%N)"
    fi
    echo "$secret"
}

get_primary_access_host() {
    local host=""
    host=$(get_public_ipv4 2>/dev/null || true)
    if [[ -z "$host" ]]; then
        host=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
    fi
    echo "$host"
}

print_service_access_url() {
    local port="$1"
    local scheme="${2:-http}"
    local prefix="${3:-  }"
    local host
    host=$(get_primary_access_host)

    if [[ -n "$host" ]]; then
        echo -e "${prefix}${CYAN}${scheme}://${host}:${port}${NC}"
    else
        echo -e "${prefix}${YELLOW}${scheme}://<服务器IP>:${port}${NC}"
        echo -e "  ${DIM}未能自动获取服务器 IP，请将 <服务器IP> 替换为 VPS 公网 IP。${NC}"
    fi
}

test_sshd_config() {
    if command -v sshd &>/dev/null; then
        sudo "$(command -v sshd)" -t
    elif [[ -x /usr/sbin/sshd ]]; then
        sudo /usr/sbin/sshd -t
    else
        log_warning "未找到 sshd 命令，已跳过 SSH 配置语法检查"
        return 0
    fi
}

backup_config_file() {
    local file_path="$1"
    [[ -e "$file_path" ]] || return 0

    local backup_dir="/var/backups/fishtools"
    local timestamp
    local safe_name
    local backup_file
    timestamp=$(date +%Y%m%d%H%M%S)
    safe_name="${file_path#/}"
    safe_name="${safe_name//\//_}"
    backup_file="${backup_dir}/${safe_name}.${timestamp}.bak"

    sudo mkdir -p "$backup_dir" || return 1
    sudo cp -a "$file_path" "$backup_file" || return 1
    echo "$file_path" | sudo tee "${backup_file}.path" >/dev/null 2>&1 || true
    echo "$backup_file"
}

is_port_in_use() {
    local port="$1"
    is_valid_port "$port" || return 1

    if command -v ss &>/dev/null; then
        ss -tuln 2>/dev/null | awk '{print $5}' | grep -Eq "(:|\\])${port}$"
    elif command -v netstat &>/dev/null; then
        netstat -tuln 2>/dev/null | awk '{print $4}' | grep -Eq "(:|\\])${port}$"
    elif command -v lsof &>/dev/null; then
        lsof -iTCP:"$port" -sTCP:LISTEN -P -n &>/dev/null || lsof -iUDP:"$port" -P -n &>/dev/null
    else
        return 1
    fi
}

confirm_port_available() {
    local port="$1"
    local label="${2:-端口}"

    if is_port_in_use "$port"; then
        log_warning "${label} ${port} 已被占用，继续可能导致服务启动失败。"
        read -p "是否仍要继续? (y/n): " continue_with_used_port </dev/tty
        [[ "$continue_with_used_port" == "y" || "$continue_with_used_port" == "Y" ]]
        return $?
    fi
    return 0
}

source_repo_script() {
    local script_name="$1"
    local required_func="$2"
    local script_path
    local script_paths=(
        "${SCRIPT_PATH%/*}/scripts/${script_name}"
        "$(dirname "$SCRIPT_PATH")/scripts/${script_name}"
        "/opt/fishtools/scripts/${script_name}"
        "./scripts/${script_name}"
    )

    for script_path in "${script_paths[@]}"; do
        if [[ -f "$script_path" ]] && source "$script_path" 2>/dev/null; then
            if [[ -z "$required_func" ]] || declare -F "$required_func" >/dev/null; then
                return 0
            fi
        fi
    done

    local uid_part="${EUID:-$(id -u 2>/dev/null || echo 0)}"
    local cache_dir="${TMPDIR:-/tmp}/fishtools-scripts-${uid_part}"
    local cached_script="${cache_dir}/${script_name}"
    local url="https://raw.githubusercontent.com/${AUTHOR_GITHUB_USER}/${MAIN_REPO_NAME}/main/scripts/${script_name}"

    mkdir -p "$cache_dir" || return 1
    if curl -fsSL "$url" -o "$cached_script" 2>/dev/null; then
        chmod 600 "$cached_script" 2>/dev/null || true
        if bash -n "$cached_script" 2>/dev/null && source "$cached_script" 2>/dev/null; then
            if [[ -z "$required_func" ]] || declare -F "$required_func" >/dev/null; then
                return 0
            fi
        fi
    fi

    return 1
}

# --- 绘制工具函数 ---
# 绘制水平线
draw_line() {
    local width=${1:-50}
    local color=${2:-$CYAN}
    local line
    line=$(printf '%*s' "$width" '' | tr ' ' "$LINE_H")
    echo -e "${color}${line}${NC}"
}

# 绘制带文字的标题行
draw_title_line() {
    local text="$1"
    local width=${2:-50}
    local color=${3:-$CYAN}
    local text_len=${#text}
    local padding=$(( (width - text_len - 4) / 2 ))
    local left_pad
    local right_pad
    left_pad=$(printf '%*s' "$padding" '' | tr ' ' "$LINE_H")
    right_pad=$(printf '%*s' "$padding" '' | tr ' ' "$LINE_H")
    # 处理奇数长度
    local extra=$(( (width - text_len - 4) % 2 ))
    if [[ $extra -gt 0 ]]; then
        right_pad="${right_pad}${LINE_H}"
    fi
    echo -e "${color}${CORNER_TL}${left_pad}${NC} ${WHITE}${BOLD}${text}${NC} ${color}${right_pad}${CORNER_TR}${NC}"
}

# 绘制菜单项
draw_menu_item() {
    local num="$1"
    local icon="$2"
    local text="$3"

    if [[ "${FISHTOOLS_EMOJI:-0}" == "1" ]]; then
        printf "  ${CYAN}${BOLD}%2s.${NC} %-2s ${WHITE}%s${NC}\n" "$num" "$icon" "$text"
    else
        printf "  ${CYAN}${BOLD}%2s.${NC} ${WHITE}%s${NC}\n" "$num" "$text"
    fi
}

# 绘制分隔线
draw_separator() {
    local width=${1:-50}
    local line=""
    for ((i=0; i<width; i++)); do
        line+="$LINE_H"
    done
    echo -e "${GRAY}${T_LEFT}${line}${T_RIGHT}${NC}"
}

# 绘制底部边框
draw_footer() {
    local width=${1:-50}
    local line=""
    for ((i=0; i<width; i++)); do
        line+="$LINE_H"
    done
    echo -e "${CYAN}${CORNER_BL}${line}${CORNER_BR}${NC}"
}

press_any_key() {
    echo ""
    echo -e "${DIM}按任意键返回菜单...${NC}"
    read -n 1 -s -r </dev/tty
}

# --- ASCII Art Logo ---
show_logo() {
    echo -e "${CYAN}"
    cat << 'EOF'
    _____ _     _   _____           _
   |  ___(_)___| |_|_   _|__   ___ | |___
   | |_  | / __| '_ \| |/ _ \ / _ \| / __|
   |  _| | \__ \ | | | | (_) | (_) | \__ \
   |_|   |_|___/_| |_|_|\___/ \___/|_|___/

EOF
    echo -e "${NC}"
    echo -e "${GRAY}           咸鱼工具箱 ${VERSION} by 咸鱼银河${NC}"
    echo -e "${GRAY}        https://github.com/${AUTHOR_GITHUB_USER}/${MAIN_REPO_NAME}${NC}"
    echo ""
}

# --- 功能实现区 ---

# 子菜单：系统状态监控
show_status_menu() {
    while true; do
        clear
        draw_title_line "系统状态监控" 50
        echo ""
        draw_menu_item "1" "📊" "显示 VPS 基本信息"
        draw_menu_item "2" "📈" "显示 VPS 实时性能"
        draw_menu_item "3" "🌐" "网络流量监控"
        draw_menu_item "4" "⚙️" "进程管理"
        draw_menu_item "5" "🔌" "端口查看"
        draw_menu_item "6" "🔧" "系统服务管理"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回主菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-6]: )" status_choice </dev/tty

        case $status_choice in
            1)
                show_machine_info
                press_any_key
                ;;
            2)
                show_live_performance
                press_any_key
                ;;
            3)
                show_network_traffic
                press_any_key
                ;;
            4)
                show_process_manager
                ;;
            5)
                show_open_ports
                press_any_key
                ;;
            6)
                show_service_manager
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

show_machine_info() {
    clear
    draw_title_line "VPS 基本信息" 50
    echo ""

    # 基础硬件信息
    echo -e "  ${WHITE}${BOLD}硬件信息${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    echo -e "  ${CYAN}CPU 型号${NC}    │ $(lscpu | grep 'Model name' | sed -E 's/.*Model name:\s*//' | head -1)"
    echo -e "  ${CYAN}CPU 核心${NC}    │ $(nproc) 核"
    echo -e "  ${CYAN}内存总量${NC}    │ $(free -m | awk 'NR==2{print $2}') MB"
    echo -e "  ${CYAN}磁盘总量${NC}    │ $(df -h / | awk 'NR==2{print $2}')"
    echo -e "  ${CYAN}系统架构${NC}    │ $(uname -m)"

    # 虚拟化检测
    local virt_type="物理机"
    if command -v systemd-detect-virt &>/dev/null; then
        virt_type=$(systemd-detect-virt 2>/dev/null || echo "未知")
        [[ "$virt_type" == "none" ]] && virt_type="物理机"
    elif [[ -f /proc/vz/veinfo ]]; then
        virt_type="OpenVZ"
    elif grep -q "hypervisor" /proc/cpuinfo 2>/dev/null; then
        virt_type="虚拟机"
    fi
    echo -e "  ${CYAN}虚拟化${NC}      │ ${virt_type}"

    echo ""
    echo -e "  ${WHITE}${BOLD}系统信息${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    echo -e "  ${CYAN}操作系统${NC}    │ $(. /etc/os-release && echo $PRETTY_NAME)"
    echo -e "  ${CYAN}内核版本${NC}    │ $(uname -r)"
    echo -e "  ${CYAN}运行时间${NC}    │ $(uptime -p 2>/dev/null | sed 's/up //' || uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')"

    # 负载
    local load_avg=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
    echo -e "  ${CYAN}系统负载${NC}    │ ${load_avg} (1/5/15分钟)"

    echo ""
    echo -e "  ${WHITE}${BOLD}网络信息${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"

    # 获取公网 IPv4
    local ipv4=$(get_public_ipv4)
    [[ -z "$ipv4" ]] && ipv4="获取失败"
    echo -e "  ${CYAN}公网 IPv4${NC}   │ ${ipv4}"

    # 获取公网 IPv6
    local ipv6=$(curl -s6 --connect-timeout 3 ip.sb 2>/dev/null || echo "无/获取失败")
    echo -e "  ${CYAN}公网 IPv6${NC}   │ ${ipv6}"

    # 主机名
    echo -e "  ${CYAN}主机名${NC}      │ $(hostname)"

    echo ""
    draw_footer 50
}

show_live_performance() {
    clear
    draw_title_line "VPS 实时性能" 50
    echo ""

    echo -e "  ${WHITE}${BOLD}CPU & 内存${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"

    # CPU 使用率
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')

    # IO 等待
    local iowait
    iowait=$(top -bn1 | grep "Cpu(s)" | awk '{for(i=1;i<=NF;i++) if($i ~ /wa/) print $(i-1)}' | tr -d ',')
    [[ -z "$iowait" ]] && iowait="0.0"

    # CPU 使用率颜色
    local cpu_color=$GREEN
    if (( $(echo "$cpu_usage > 70" | bc -l) )); then
        cpu_color=$RED
    elif (( $(echo "$cpu_usage > 40" | bc -l) )); then
        cpu_color=$YELLOW
    fi
    echo -e "  ${CYAN}CPU 使用率${NC}  │ ${cpu_color}${cpu_usage}%${NC}  ${DIM}(IO等待: ${iowait}%)${NC}"

    # 内存使用
    local mem_total=$(free -m | awk 'NR==2{print $2}')
    local mem_used=$(free -m | awk 'NR==2{print $3}')
    local mem_percent=$((mem_used * 100 / mem_total))

    local mem_color=$GREEN
    if (( mem_percent > 80 )); then
        mem_color=$RED
    elif (( mem_percent > 50 )); then
        mem_color=$YELLOW
    fi
    echo -e "  ${CYAN}内存使用${NC}    │ ${mem_color}${mem_used}MB${NC} / ${mem_total}MB (${mem_color}${mem_percent}%${NC})"

    # SWAP 使用
    local swap_total=$(free -m | awk 'NR==3{print $2}')
    local swap_used=$(free -m | awk 'NR==3{print $3}')
    if [[ "$swap_total" -gt 0 ]]; then
        local swap_percent=$((swap_used * 100 / swap_total))
        local swap_color=$GREEN
        if (( swap_percent > 80 )); then
            swap_color=$RED
        elif (( swap_percent > 50 )); then
            swap_color=$YELLOW
        fi
        echo -e "  ${CYAN}SWAP 使用${NC}   │ ${swap_color}${swap_used}MB${NC} / ${swap_total}MB (${swap_color}${swap_percent}%${NC})"
    else
        echo -e "  ${CYAN}SWAP 使用${NC}   │ ${GRAY}未配置${NC}"
    fi

    echo ""
    echo -e "  ${WHITE}${BOLD}磁盘 & 网络${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"

    # 磁盘使用
    local disk_info=$(df -h / | awk 'NR==2{printf "%s / %s (%s)", $3, $2, $5}')
    local disk_percent=$(df -h / | awk 'NR==2{print $5}' | tr -d '%')

    local disk_color=$GREEN
    if (( disk_percent > 80 )); then
        disk_color=$RED
    elif (( disk_percent > 60 )); then
        disk_color=$YELLOW
    fi
    echo -e "  ${CYAN}磁盘空间${NC}    │ ${disk_color}${disk_info}${NC}"

    # 网络连接数
    local tcp_conn=$(ss -t state established 2>/dev/null | wc -l)
    local tcp_listen=$(ss -tln 2>/dev/null | grep -c LISTEN || echo 0)
    echo -e "  ${CYAN}网络连接${NC}    │ TCP 已建立: ${tcp_conn}  监听端口: ${tcp_listen}"

    # 系统负载
    local load_avg=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
    echo -e "  ${CYAN}系统负载${NC}    │ ${load_avg}"

    echo ""
    echo -e "  ${DIM}(此为快照信息，非持续刷新)${NC}"
    echo ""
    draw_footer 50
}

# 网络流量监控（实时刷新）
show_network_traffic() {
    # 获取所有活动网卡（排除 lo）
    local interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | tr '\n' ' ')

    # 如果没有找到网卡，使用默认的 eth0
    if [[ -z "$interfaces" ]]; then
        interfaces="eth0"
    fi

    # 获取默认网关所在的网卡（公网网卡）
    local default_iface=$(ip route | grep default | awk '{print $5}' | head -1)

    # 初始化上一次的采样数据
    declare -A rx_prev tx_prev
    for iface in $interfaces; do
        rx_prev[$iface]=$(cat /proc/net/dev 2>/dev/null | grep -w "$iface" | awk '{print $2}')
        tx_prev[$iface]=$(cat /proc/net/dev 2>/dev/null | grep -w "$iface" | awk '{print $10}')
    done

    # 实时刷新循环
    while true; do
        clear
        draw_title_line "网络流量监控 (实时)" 50
        echo ""
        echo -e "  ${WHITE}${BOLD}网卡流量统计${NC}  ${DIM}(每2秒刷新，按 q 退出)${NC}"
        echo -e "  ${GRAY}──────────────────────────────────────────${NC}"

        for iface in $interfaces; do
            # 获取当前数据
            local rx_curr=$(cat /proc/net/dev 2>/dev/null | grep -w "$iface" | awk '{print $2}')
            local tx_curr=$(cat /proc/net/dev 2>/dev/null | grep -w "$iface" | awk '{print $10}')

            # 跳过无效数据
            if [[ -z "$rx_curr" || -z "$tx_curr" || "$rx_curr" == "0" ]]; then
                continue
            fi

            # 获取上次数据
            local rx_last=${rx_prev[$iface]:-$rx_curr}
            local tx_last=${tx_prev[$iface]:-$tx_curr}

            # 计算速率 (bytes/2s -> KB/s)
            local rx_diff=$((rx_curr - rx_last))
            local tx_diff=$((tx_curr - tx_last))
            local rx_rate=$((rx_diff / 2 / 1024))
            local tx_rate=$((tx_diff / 2 / 1024))

            # 更新上次数据
            rx_prev[$iface]=$rx_curr
            tx_prev[$iface]=$tx_curr

            # 计算总流量 (使用 awk 进行浮点运算)
            local rx_total=$(awk "BEGIN {printf \"%.2f\", $rx_curr / 1024 / 1024 / 1024}")
            local tx_total=$(awk "BEGIN {printf \"%.2f\", $tx_curr / 1024 / 1024 / 1024}")

            # 判断是公网还是内网网卡
            local iface_type=""
            if [[ "$iface" == "$default_iface" ]]; then
                iface_type="${MAGENTA}[公网]${NC}"
            else
                iface_type="${GRAY}[内网]${NC}"
            fi

            # 速率单位自动调整
            local rx_display tx_display
            if [[ $rx_rate -ge 1024 ]]; then
                rx_display=$(awk "BEGIN {printf \"%.2f MB/s\", $rx_rate / 1024}")
            else
                rx_display="${rx_rate} KB/s"
            fi
            if [[ $tx_rate -ge 1024 ]]; then
                tx_display=$(awk "BEGIN {printf \"%.2f MB/s\", $tx_rate / 1024}")
            else
                tx_display="${tx_rate} KB/s"
            fi

            echo ""
            echo -e "  ${CYAN}${BOLD}$iface${NC} $iface_type"
            echo -e "    ${GREEN}↓ 下载${NC}  ${rx_display}  │  累计 ${rx_total} GB"
            echo -e "    ${YELLOW}↑ 上传${NC}  ${tx_display}  │  累计 ${tx_total} GB"
        done

        echo ""
        draw_footer 50

        # 等待2秒，期间检测是否按下 q 键退出
        read -t 2 -n 1 key </dev/tty 2>/dev/null || true
        if [[ "$key" == "q" || "$key" == "Q" ]]; then
            break
        fi
    done
}

# 进程管理
show_process_manager() {
    while true; do
        clear
        draw_title_line "进程管理" 50
        echo ""

        # 显示CPU占用前10的进程
        echo -e "  ${WHITE}${BOLD}CPU 占用 TOP 10${NC}"
        echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
        echo -e "  ${CYAN}PID      CPU%   MEM%   命令${NC}"
        ps aux --sort=-%cpu | head -11 | tail -10 | awk '{printf "  %-8s %-6s %-6s %s\n", $2, $3, $4, $11}'

        echo ""
        echo -e "  ${WHITE}${BOLD}内存 占用 TOP 10${NC}"
        echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
        echo -e "  ${CYAN}PID      CPU%   MEM%   命令${NC}"
        ps aux --sort=-%mem | head -11 | tail -10 | awk '{printf "  %-8s %-6s %-6s %s\n", $2, $3, $4, $11}'

        echo ""
        draw_separator 50
        echo -e "  ${YELLOW}输入 PID 杀死进程，或输入 0 返回${NC}"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入${NC}): " pid_input </dev/tty

        if [[ "$pid_input" == "0" ]]; then
            break
        elif [[ "$pid_input" =~ ^[0-9]+$ ]]; then
            read -p "确认杀死进程 $pid_input? (y/n): " confirm </dev/tty
            if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                if kill -9 "$pid_input" 2>/dev/null; then
                    log_success "进程 $pid_input 已终止"
                else
                    log_error "无法终止进程 $pid_input（可能需要 sudo 权限）"
                fi
                press_any_key
            fi
        fi
    done
}

# 端口查看
show_open_ports() {
    clear
    draw_title_line "开放端口查看" 50
    echo ""

    echo -e "  ${WHITE}${BOLD}TCP 监听端口${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    echo -e "  ${CYAN}端口       状态       进程${NC}"

    if command -v ss &>/dev/null; then
        ss -tlnp 2>/dev/null | grep LISTEN | awk '{
            split($4, a, ":")
            port = a[length(a)]
            proc = $6
            gsub(/users:\(\("/, "", proc)
            gsub(/".*/, "", proc)
            if (proc == "") proc = "-"
            printf "  %-10s %-10s %s\n", port, "LISTEN", proc
        }' | sort -t' ' -k1 -n | uniq || true
    else
        netstat -tlnp 2>/dev/null | grep LISTEN | awk '{
            split($4, a, ":")
            port = a[length(a)]
            proc = $7
            printf "  %-10s %-10s %s\n", port, "LISTEN", proc
        }' | sort -t' ' -k1 -n | uniq || true
    fi

    echo ""
    echo -e "  ${WHITE}${BOLD}UDP 监听端口${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"

    if command -v ss &>/dev/null; then
        ss -ulnp 2>/dev/null | grep -v "State" | awk '{
            split($4, a, ":")
            port = a[length(a)]
            proc = $6
            gsub(/users:\(\("/, "", proc)
            gsub(/".*/, "", proc)
            if (proc == "") proc = "-"
            if (port != "*") printf "  %-10s %-10s %s\n", port, "UDP", proc
        }' | sort -t' ' -k1 -n | uniq || true
    else
        netstat -ulnp 2>/dev/null | awk '{
            split($4, a, ":")
            port = a[length(a)]
            proc = $6
            if (NR > 2) printf "  %-10s %-10s %s\n", port, "UDP", proc
        }' | sort -t' ' -k1 -n | uniq || true
    fi

    echo ""
    draw_footer 50
}

# ================== 系统服务管理 ==================
show_service_manager() {
    while true; do
        clear
        draw_title_line "系统服务管理" 50
        echo ""
        draw_menu_item "1" "📋" "查看运行中的服务"
        draw_menu_item "2" "🔍" "搜索服务"
        draw_menu_item "3" "▶️" "启动服务"
        draw_menu_item "4" "⏹️" "停止服务"
        draw_menu_item "5" "🔄" "重启服务"
        draw_menu_item "6" "📊" "查看服务状态"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回上级菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-6]: )" svc_choice </dev/tty

        case $svc_choice in
            1)
                clear
                draw_title_line "运行中的服务" 50
                echo ""
                echo -e "  ${WHITE}${BOLD}活跃的系统服务 (前30个)${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                echo ""
                systemctl list-units --type=service --state=running --no-pager 2>/dev/null | head -35 || \
                    service --status-all 2>/dev/null | grep '\[ + \]' | head -30
                press_any_key
                ;;
            2)
                clear
                draw_title_line "搜索服务" 50
                echo ""
                read -p "请输入服务名关键词: " keyword </dev/tty
                if [[ -n "$keyword" ]]; then
                    echo ""
                    echo -e "  ${WHITE}${BOLD}搜索结果:${NC}"
                    echo ""
                    systemctl list-units --type=service --all --no-pager 2>/dev/null | grep -i "$keyword" || \
                        echo "  未找到匹配的服务"
                fi
                press_any_key
                ;;
            3)
                clear
                draw_title_line "启动服务" 50
                echo ""
                read -p "请输入要启动的服务名: " svc_name </dev/tty
                if [[ -n "$svc_name" ]]; then
                    if sudo systemctl start "$svc_name" 2>/dev/null; then
                        log_success "服务 $svc_name 已启动"
                    else
                        log_error "启动服务 $svc_name 失败"
                    fi
                fi
                press_any_key
                ;;
            4)
                clear
                draw_title_line "停止服务" 50
                echo ""
                read -p "请输入要停止的服务名: " svc_name </dev/tty
                if [[ -n "$svc_name" ]]; then
                    read -p "确认停止服务 $svc_name? (y/n): " confirm </dev/tty
                    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                        if sudo systemctl stop "$svc_name" 2>/dev/null; then
                            log_success "服务 $svc_name 已停止"
                        else
                            log_error "停止服务 $svc_name 失败"
                        fi
                    fi
                fi
                press_any_key
                ;;
            5)
                clear
                draw_title_line "重启服务" 50
                echo ""
                read -p "请输入要重启的服务名: " svc_name </dev/tty
                if [[ -n "$svc_name" ]]; then
                    if sudo systemctl restart "$svc_name" 2>/dev/null; then
                        log_success "服务 $svc_name 已重启"
                    else
                        log_error "重启服务 $svc_name 失败"
                    fi
                fi
                press_any_key
                ;;
            6)
                clear
                draw_title_line "查看服务状态" 50
                echo ""
                read -p "请输入服务名: " svc_name </dev/tty
                if [[ -n "$svc_name" ]]; then
                    echo ""
                    sudo systemctl status "$svc_name" --no-pager 2>/dev/null || \
                        log_error "无法获取服务 $svc_name 的状态"
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

# ================== Nginx 管理子菜单 ==================
install_nginx_menu() {
    while true; do
        clear
        draw_title_line "Nginx 管理" 50
        echo ""

        # 显示当前状态
        if command -v nginx &>/dev/null; then
            local nginx_ver=$(nginx -v 2>&1 | awk -F'/' '{print $2}')
            echo -e "  ${GREEN}✓${NC} Nginx 已安装 (${nginx_ver})"
            if systemctl is-active --quiet nginx 2>/dev/null; then
                echo -e "  ${GREEN}●${NC} 运行状态: ${GREEN}运行中${NC}"
            else
                echo -e "  ${RED}●${NC} 运行状态: ${RED}已停止${NC}"
            fi
        else
            echo -e "  ${GRAY}○${NC} Nginx 未安装"
        fi
        echo ""

        draw_menu_item "1" "📦" "安装 Nginx"
        draw_menu_item "2" "🔀" "配置反向代理"
        draw_menu_item "3" "🔒" "申请 HTTPS 证书 (Certbot)"
        draw_menu_item "4" "▶️" "启动 Nginx"
        draw_menu_item "5" "⏹️" "停止 Nginx"
        draw_menu_item "6" "🔄" "重启 Nginx"
        draw_menu_item "7" "📊" "查看状态"
        draw_menu_item "8" "🗑️" "卸载 Nginx"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回上级菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-8]: )" nginx_choice </dev/tty

        case $nginx_choice in
            1)
                clear
                draw_title_line "安装 Nginx" 50
                echo ""
                log_info "正在安装 Nginx..."
                pkg_update && pkg_install nginx
                log_success "Nginx 安装完成！"
                nginx -v
                echo ""
                echo -e "  ${CYAN}配置目录:${NC} /etc/nginx/"
                echo -e "  ${CYAN}站点目录:${NC} /var/www/html/"
                press_any_key
                ;;
            2)
                clear
                draw_title_line "配置 Nginx 反向代理" 50
                echo ""
                if ! command -v nginx &>/dev/null; then
                    log_error "Nginx 未安装，请先安装！"
                    press_any_key
                    continue
                fi

                read -p "请输入域名 (如 example.com): " domain </dev/tty
                read -p "请输入后端地址 (如 127.0.0.1:3000): " backend </dev/tty
                local backend_url
                backend_url=$(normalize_backend_url "$backend")

                if ! is_valid_domain "$domain"; then
                    log_error "域名格式无效！"
                    press_any_key
                    continue
                fi
                if ! is_valid_backend_url "$backend_url"; then
                    log_error "后端地址格式无效，请使用 127.0.0.1:3000 或 http://127.0.0.1:3000。"
                    press_any_key
                    continue
                fi

                local conf_name="${domain//\*/wildcard}"
                local conf_file="/etc/nginx/sites-available/${conf_name}"
                local backup_file=""
                if [[ -e "$conf_file" ]]; then
                    backup_file=$(backup_config_file "$conf_file" 2>/dev/null || echo "")
                fi
                sudo tee "$conf_file" > /dev/null <<EOF
server {
    listen 80;
    server_name ${domain};

    location / {
        proxy_pass ${backend_url};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
                sudo ln -sf "$conf_file" /etc/nginx/sites-enabled/
                if sudo nginx -t && sudo systemctl reload nginx; then
                    log_success "反向代理配置完成！"
                    echo -e "  ${CYAN}域名:${NC} ${domain}"
                    echo -e "  ${CYAN}后端:${NC} ${backend_url}"
                    echo -e "  ${YELLOW}提示: 如需 HTTPS，请选择菜单选项3申请证书${NC}"
                else
                    sudo rm -f "/etc/nginx/sites-enabled/${conf_name}" 2>/dev/null || true
                    [[ -n "$backup_file" ]] && sudo cp "$backup_file" "$conf_file" 2>/dev/null || true
                    log_error "Nginx 配置测试失败，已移除启用链接，请检查输入。"
                fi
                press_any_key
                ;;
            3)
                clear
                draw_title_line "申请 HTTPS 证书" 50
                echo ""
                if ! command -v nginx &>/dev/null; then
                    log_error "Nginx 未安装，请先安装！"
                    press_any_key
                    continue
                fi

                # 检测 Certbot
                if ! command -v certbot &>/dev/null; then
                    log_info "Certbot 未安装，正在自动安装..."
                    pkg_update
                    pkg_install certbot python3-certbot-nginx
                    log_success "Certbot 安装完成！"
                    echo ""
                fi

                read -p "请输入域名 (如 example.com): " domain </dev/tty

                if [[ -z "$domain" ]]; then
                    log_error "域名不能为空！"
                    press_any_key
                    continue
                fi

                echo ""
                log_info "正在为 ${domain} 申请证书..."
                echo -e "  ${YELLOW}请确保域名已解析到此服务器 IP${NC}"
                echo ""

                if sudo certbot --nginx -d "$domain" --non-interactive --agree-tos --register-unsafely-without-email; then
                    echo ""
                    log_success "HTTPS 证书申请成功！"
                    echo -e "  ${GREEN}✓${NC} 站点已启用 HTTPS"
                    echo -e "  ${GREEN}✓${NC} 证书将自动续期"
                    echo -e "  ${CYAN}访问:${NC} https://${domain}"
                else
                    echo ""
                    log_error "证书申请失败！"
                    echo -e "  ${YELLOW}可能原因：${NC}"
                    echo -e "    • 域名未解析到此服务器"
                    echo -e "    • 80/443 端口未开放"
                    echo -e "    • Nginx 配置中没有该域名"
                fi
                press_any_key
                ;;
            4)
                sudo systemctl start nginx
                log_success "Nginx 已启动"
                press_any_key
                ;;
            5)
                sudo systemctl stop nginx
                log_success "Nginx 已停止"
                press_any_key
                ;;
            6)
                sudo systemctl restart nginx
                log_success "Nginx 已重启"
                press_any_key
                ;;
            7)
                clear
                draw_title_line "Nginx 状态" 50
                echo ""
                sudo systemctl status nginx --no-pager || true
                press_any_key
                ;;
            8)
                clear
                draw_title_line "卸载 Nginx" 50
                echo ""
                if ! command -v nginx &>/dev/null; then
                    log_warning "Nginx 未安装，无需卸载。"
                    press_any_key
                    continue
                fi
                echo -e "  ${RED}${BOLD}⚠ 警告：将卸载 Nginx 及其配置文件！${NC}"
                echo ""
                read -p "请输入 'yes' 确认卸载: " confirm </dev/tty
                if [[ "$confirm" != "yes" ]]; then
                    log_info "操作已取消。"
                    press_any_key
                    continue
                fi
                log_info "正在停止 Nginx..."
                sudo systemctl stop nginx 2>/dev/null || true
                log_info "正在卸载 Nginx..."
                pkg_remove nginx nginx-common nginx-full nginx-core 2>/dev/null || true
                log_info "正在清理配置..."
                sudo rm -rf /etc/nginx
                sudo rm -rf /var/log/nginx
                echo ""
                log_success "Nginx 已完全卸载！"
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

# ================== Caddy 管理子菜单 ==================
install_caddy_menu() {
    while true; do
        clear
        draw_title_line "Caddy 管理" 50
        echo ""

        # 显示当前状态
        if command -v caddy &>/dev/null; then
            local caddy_ver=$(caddy version 2>/dev/null | awk '{print $1}')
            echo -e "  ${GREEN}✓${NC} Caddy 已安装 (${caddy_ver})"
            if systemctl is-active --quiet caddy 2>/dev/null; then
                echo -e "  ${GREEN}●${NC} 运行状态: ${GREEN}运行中${NC}"
            else
                echo -e "  ${RED}●${NC} 运行状态: ${RED}已停止${NC}"
            fi
        else
            echo -e "  ${GRAY}○${NC} Caddy 未安装"
        fi
        echo ""

        draw_menu_item "1" "📦" "安装 Caddy"
        draw_menu_item "2" "🔀" "配置反向代理 (自动 HTTPS)"
        draw_menu_item "3" "▶️" "启动 Caddy"
        draw_menu_item "4" "⏹️" "停止 Caddy"
        draw_menu_item "5" "🔄" "重启 Caddy"
        draw_menu_item "6" "📊" "查看状态"
        draw_menu_item "7" "🗑️" "卸载 Caddy"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回上级菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-7]: )" caddy_choice </dev/tty

        case $caddy_choice in
            1)
                clear
                draw_title_line "安装 Caddy" 50
                echo ""
                log_info "正在安装 Caddy..."
                sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https &>/dev/null
                curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg --yes
                curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
                sudo apt-get update && sudo apt-get install -y caddy
                log_success "Caddy 安装完成！"
                caddy version
                echo ""
                echo -e "  ${CYAN}配置文件:${NC} /etc/caddy/Caddyfile"
                echo -e "  ${GREEN}特性: 自动 HTTPS 证书申请与续期${NC}"
                press_any_key
                ;;
            2)
                clear
                draw_title_line "配置 Caddy 反向代理" 50
                echo ""
                if ! command -v caddy &>/dev/null; then
                    log_error "Caddy 未安装，请先安装！"
                    press_any_key
                    continue
                fi

                read -p "请输入域名 (如 example.com): " domain </dev/tty
                read -p "请输入后端地址 (如 127.0.0.1:3000): " backend </dev/tty
                local backend_url
                backend_url=$(normalize_backend_url "$backend")

                if ! is_valid_domain "$domain"; then
                    log_error "域名格式无效！"
                    press_any_key
                    continue
                fi
                if ! is_valid_backend_url "$backend_url"; then
                    log_error "后端地址格式无效，请使用 127.0.0.1:3000 或 http://127.0.0.1:3000。"
                    press_any_key
                    continue
                fi

                # 追加到 Caddyfile
                local backup_file
                backup_file=$(backup_config_file /etc/caddy/Caddyfile 2>/dev/null || echo "")
                echo "" | sudo tee -a /etc/caddy/Caddyfile >/dev/null
                echo "${domain} {" | sudo tee -a /etc/caddy/Caddyfile >/dev/null
                echo "    reverse_proxy ${backend_url}" | sudo tee -a /etc/caddy/Caddyfile >/dev/null
                echo "}" | sudo tee -a /etc/caddy/Caddyfile >/dev/null

                if sudo caddy validate --config /etc/caddy/Caddyfile >/dev/null 2>&1 && sudo systemctl reload caddy; then
                    log_success "反向代理配置完成！"
                    echo -e "  ${CYAN}域名:${NC} ${domain}"
                    echo -e "  ${CYAN}后端:${NC} ${backend_url}"
                    echo -e "  ${GREEN}Caddy 将自动为该域名申请 HTTPS 证书${NC}"
                else
                    [[ -n "$backup_file" ]] && sudo cp "$backup_file" /etc/caddy/Caddyfile 2>/dev/null || true
                    sudo systemctl reload caddy 2>/dev/null || true
                    log_error "Caddy 配置测试失败，已恢复原配置。"
                fi
                press_any_key
                ;;
            3)
                sudo systemctl start caddy
                log_success "Caddy 已启动"
                press_any_key
                ;;
            4)
                sudo systemctl stop caddy
                log_success "Caddy 已停止"
                press_any_key
                ;;
            5)
                sudo systemctl restart caddy
                log_success "Caddy 已重启"
                press_any_key
                ;;
            6)
                clear
                draw_title_line "Caddy 状态" 50
                echo ""
                sudo systemctl status caddy --no-pager || true
                press_any_key
                ;;
            7)
                clear
                draw_title_line "卸载 Caddy" 50
                echo ""
                if ! command -v caddy &>/dev/null; then
                    log_warning "Caddy 未安装，无需卸载。"
                    press_any_key
                    continue
                fi
                echo -e "  ${RED}${BOLD}⚠ 警告：将卸载 Caddy 及其配置文件！${NC}"
                echo ""
                read -p "请输入 'yes' 确认卸载: " confirm </dev/tty
                if [[ "$confirm" != "yes" ]]; then
                    log_info "操作已取消。"
                    press_any_key
                    continue
                fi
                log_info "正在停止 Caddy..."
                sudo systemctl stop caddy 2>/dev/null || true
                log_info "正在卸载 Caddy..."
                pkg_remove caddy 2>/dev/null || true
                log_info "正在清理配置..."
                sudo rm -rf /etc/caddy
                sudo rm -rf /var/lib/caddy
                sudo rm -rf /var/log/caddy
                sudo rm -f /etc/apt/sources.list.d/caddy-stable.list
                sudo rm -f /usr/share/keyrings/caddy-stable-archive-keyring.gpg
                echo ""
                log_success "Caddy 已完全卸载！"
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

# ================== 反代工具子菜单 ==================
show_proxy_menu() {
    while true; do
        clear
        draw_title_line "反代工具" 50
        echo ""
        echo -e "  ${WHITE}${BOLD}选择您需要的反向代理工具${NC}"
        echo ""
        echo -e "  ${CYAN}Nginx${NC}  - 经典高性能，需手动配置 HTTPS"
        echo -e "  ${CYAN}Caddy${NC}  - 现代化，自动 HTTPS 证书"
        echo ""
        draw_menu_item "1" "🌐" "Nginx 管理"
        draw_menu_item "2" "🔒" "Caddy 管理"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回上级菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-2]: )" proxy_choice </dev/tty

        case $proxy_choice in
            1) install_nginx_menu ;;
            2) install_caddy_menu ;;
            0) break ;;
            *) log_error "无效输入。"; press_any_key ;;
        esac
    done
}

# ================== fail2ban 管理子菜单 ==================
install_fail2ban_menu() {
    while true; do
        clear
        draw_title_line "fail2ban 安全防护" 50
        echo ""

        # 显示当前状态
        if command -v fail2ban-client &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} fail2ban 已安装"
            if systemctl is-active --quiet fail2ban 2>/dev/null; then
                echo -e "  ${GREEN}●${NC} 运行状态: ${GREEN}运行中${NC}"
                local banned=$(sudo fail2ban-client status sshd 2>/dev/null | grep "Currently banned" | awk '{print $NF}')
                echo -e "  ${CYAN}当前封禁:${NC} ${banned:-0} 个 IP"
            else
                echo -e "  ${RED}●${NC} 运行状态: ${RED}已停止${NC}"
            fi
        else
            echo -e "  ${GRAY}○${NC} fail2ban 未安装"
        fi
        echo ""

        draw_menu_item "1" "📦" "安装 fail2ban"
        draw_menu_item "2" "📋" "查看封禁列表"
        draw_menu_item "3" "🔓" "解封指定 IP"
        draw_menu_item "4" "📊" "查看状态"
        draw_menu_item "5" "🗑️" "卸载 fail2ban"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回上级菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-5]: )" f2b_choice </dev/tty

        case $f2b_choice in
            1)
                clear
                draw_title_line "安装 fail2ban" 50
                echo ""
                log_info "正在安装 fail2ban..."
                pkg_update && pkg_install fail2ban

                # 自动检测日志后端并生成对应配置
                local f2b_backend=""
                local f2b_logpath=""
                if [[ -f /var/log/auth.log ]]; then
                    # Debian/Ubuntu 传统 rsyslog 模式
                    f2b_backend="auto"
                    f2b_logpath="logpath = /var/log/auth.log"
                elif [[ -f /var/log/secure ]]; then
                    # CentOS/RHEL/Fedora
                    f2b_backend="auto"
                    f2b_logpath="logpath = /var/log/secure"
                else
                    # Debian 12+/现代 systemd 系统 - 使用 journald
                    f2b_backend="systemd"
                    f2b_logpath=""
                fi

                sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[sshd]
enabled = true
port = ssh
filter = sshd
backend = ${f2b_backend}
${f2b_logpath}
maxretry = 5
bantime = 3600
findtime = 600
EOF
                sudo systemctl enable fail2ban
                sudo systemctl restart fail2ban
                log_success "fail2ban 安装完成！"
                echo ""
                echo -e "  ${CYAN}配置说明:${NC}"
                echo -e "    • 5 次失败后封禁 IP"
                echo -e "    • 封禁时长: 1 小时"
                echo -e "    • 日志后端: ${f2b_backend}"
                echo -e "    • 配置文件: /etc/fail2ban/jail.local"
                press_any_key
                ;;
            2)
                clear
                draw_title_line "封禁列表" 50
                echo ""
                if ! command -v fail2ban-client &>/dev/null; then
                    log_error "fail2ban 未安装！"
                    press_any_key
                    continue
                fi
                log_info "当前被封禁的 IP 列表:"
                echo ""
                sudo fail2ban-client status sshd 2>/dev/null || echo "  暂无封禁记录"
                press_any_key
                ;;
            3)
                clear
                draw_title_line "解封 IP" 50
                echo ""
                if ! command -v fail2ban-client &>/dev/null; then
                    log_error "fail2ban 未安装！"
                    press_any_key
                    continue
                fi
                read -p "请输入要解封的 IP: " unban_ip </dev/tty
                if [[ -n "$unban_ip" ]]; then
                    sudo fail2ban-client set sshd unbanip "$unban_ip" && \
                        log_success "已解封 IP: $unban_ip" || \
                        log_error "解封失败，IP 可能不在封禁列表中"
                fi
                press_any_key
                ;;
            4)
                clear
                draw_title_line "fail2ban 状态" 50
                echo ""
                sudo systemctl status fail2ban --no-pager || true
                press_any_key
                ;;
            5)
                clear
                draw_title_line "卸载 fail2ban" 50
                echo ""
                if ! command -v fail2ban-client &>/dev/null; then
                    log_warning "fail2ban 未安装，无需卸载。"
                    press_any_key
                    continue
                fi
                read -p "确认卸载 fail2ban? (y/n): " confirm </dev/tty
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    sudo systemctl stop fail2ban 2>/dev/null || true
                    pkg_remove fail2ban
                    log_success "fail2ban 已卸载！"
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

# ================== 系统监控工具子菜单 ==================
install_monitor_menu() {
    while true; do
        clear
        draw_title_line "系统监控工具" 50
        echo ""

        # 显示当前状态
        if command -v htop &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} htop 已安装"
        else
            echo -e "  ${GRAY}○${NC} htop 未安装"
        fi
        if command -v btop &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} btop 已安装"
        else
            echo -e "  ${GRAY}○${NC} btop 未安装"
        fi
        echo ""

        echo -e "  ${CYAN}htop${NC}  - 经典轻量，兼容性好"
        echo -e "  ${CYAN}btop${NC}  - 现代美观，功能丰富"
        echo ""
        draw_menu_item "1" "📦" "安装 htop"
        draw_menu_item "2" "📦" "安装 btop"
        draw_menu_item "3" "▶️" "运行 htop"
        draw_menu_item "4" "▶️" "运行 btop"
        draw_menu_item "5" "🗑️" "卸载 htop/btop"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回上级菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-5]: )" mon_choice </dev/tty

        case $mon_choice in
            1)
                clear
                log_info "正在安装 htop..."
                pkg_update && pkg_install htop
                log_success "htop 安装完成！运行命令: htop"
                press_any_key
                ;;
            2)
                clear
                log_info "正在安装 btop..."
                pkg_update && pkg_install btop 2>/dev/null || {
                    log_warning "包管理器中无 btop，尝试 snap 安装..."
                    sudo snap install btop 2>/dev/null || {
                        log_error "btop 安装失败，您的系统可能不支持"
                    }
                }
                command -v btop &>/dev/null && log_success "btop 安装完成！运行命令: btop"
                press_any_key
                ;;
            3)
                if command -v htop &>/dev/null; then
                    htop
                else
                    log_error "htop 未安装，请先安装！"
                    press_any_key
                fi
                ;;
            4)
                if command -v btop &>/dev/null; then
                    btop
                else
                    log_error "btop 未安装，请先安装！"
                    press_any_key
                fi
                ;;
            5)
                clear
                draw_title_line "卸载监控工具" 50
                echo ""
                echo -e "  ${CYAN}1.${NC} 卸载 htop"
                echo -e "  ${CYAN}2.${NC} 卸载 btop"
                echo -e "  ${CYAN}3.${NC} 全部卸载"
                echo ""
                read -p "请选择: " uninstall_choice </dev/tty
                case $uninstall_choice in
                    1) pkg_remove htop && log_success "htop 已卸载" ;;
                    2) pkg_remove btop 2>/dev/null; sudo snap remove btop 2>/dev/null; log_success "btop 已卸载" ;;
                    3) pkg_remove htop btop 2>/dev/null; sudo snap remove btop 2>/dev/null; log_success "已全部卸载" ;;
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

# ================== tmux 管理子菜单 ==================
install_tmux_menu() {
    while true; do
        clear
        draw_title_line "tmux 终端复用" 50
        echo ""

        # 显示当前状态
        if command -v tmux &>/dev/null; then
            local tmux_ver=$(tmux -V 2>/dev/null | awk '{print $2}')
            echo -e "  ${GREEN}✓${NC} tmux 已安装 (${tmux_ver})"
            local sessions=$(tmux ls 2>/dev/null | wc -l)
            echo -e "  ${CYAN}活跃会话:${NC} ${sessions} 个"
        else
            echo -e "  ${GRAY}○${NC} tmux 未安装"
        fi
        echo ""

        draw_menu_item "1" "📦" "安装 tmux"
        draw_menu_item "2" "➕" "新建会话"
        draw_menu_item "3" "📋" "列出会话"
        draw_menu_item "4" "🔗" "连接会话"
        draw_menu_item "5" "❓" "使用帮助"
        draw_menu_item "6" "🗑️" "卸载 tmux"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回上级菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-6]: )" tmux_choice </dev/tty

        case $tmux_choice in
            1)
                clear
                log_info "正在安装 tmux..."
                pkg_update && pkg_install tmux
                log_success "tmux 安装完成！"
                press_any_key
                ;;
            2)
                if ! command -v tmux &>/dev/null; then
                    log_error "tmux 未安装，请先安装！"
                    press_any_key
                    continue
                fi
                read -p "请输入会话名称: " session_name </dev/tty
                if [[ -n "$session_name" ]]; then
                    tmux new-session -d -s "$session_name"
                    log_success "会话 '$session_name' 已创建"
                    read -p "是否立即进入? (y/n): " enter </dev/tty
                    [[ "$enter" == "y" || "$enter" == "Y" ]] && tmux attach -t "$session_name"
                fi
                press_any_key
                ;;
            3)
                clear
                draw_title_line "tmux 会话列表" 50
                echo ""
                if ! command -v tmux &>/dev/null; then
                    log_error "tmux 未安装！"
                else
                    tmux ls 2>/dev/null || echo "  暂无活跃会话"
                fi
                press_any_key
                ;;
            4)
                if ! command -v tmux &>/dev/null; then
                    log_error "tmux 未安装，请先安装！"
                    press_any_key
                    continue
                fi
                echo ""
                tmux ls 2>/dev/null || { echo "  暂无活跃会话"; press_any_key; continue; }
                echo ""
                read -p "请输入要连接的会话名称: " attach_name </dev/tty
                [[ -n "$attach_name" ]] && tmux attach -t "$attach_name"
                ;;
            5)
                clear
                draw_title_line "tmux 使用帮助" 50
                echo ""
                echo -e "  ${WHITE}${BOLD}常用快捷键 (先按 Ctrl+B，再按以下键)${NC}"
                echo ""
                echo -e "  ${CYAN}d${NC}     - 挂起会话（后台运行）"
                echo -e "  ${CYAN}c${NC}     - 新建窗口"
                echo -e "  ${CYAN}n/p${NC}   - 下一个/上一个窗口"
                echo -e "  ${CYAN}%${NC}     - 左右分屏"
                echo -e "  ${CYAN}\"${NC}     - 上下分屏"
                echo -e "  ${CYAN}方向键${NC} - 切换分屏"
                echo -e "  ${CYAN}x${NC}     - 关闭当前面板"
                echo ""
                echo -e "  ${WHITE}${BOLD}常用命令${NC}"
                echo ""
                echo -e "  ${CYAN}tmux new -s 名称${NC}     创建会话"
                echo -e "  ${CYAN}tmux ls${NC}              列出会话"
                echo -e "  ${CYAN}tmux attach -t 名称${NC}  连接会话"
                echo -e "  ${CYAN}tmux kill-session -t 名称${NC}  删除会话"
                press_any_key
                ;;
            6)
                clear
                if ! command -v tmux &>/dev/null; then
                    log_warning "tmux 未安装，无需卸载。"
                    press_any_key
                    continue
                fi
                read -p "确认卸载 tmux? (y/n): " confirm </dev/tty
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    pkg_remove tmux
                    log_success "tmux 已卸载！"
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

# ================== ufw 防火墙管理 ==================
install_ufw_menu() {
    while true; do
        clear
        draw_title_line "ufw 防火墙" 50
        echo ""

        # 显示当前状态
        if command -v ufw &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} ufw 已安装"
            local status=$(sudo ufw status 2>/dev/null | head -1)
            if echo "$status" | grep -q "active"; then
                echo -e "  ${GREEN}●${NC} 防火墙状态: ${GREEN}已启用${NC}"
            else
                echo -e "  ${RED}●${NC} 防火墙状态: ${RED}未启用${NC}"
            fi
        else
            echo -e "  ${GRAY}○${NC} ufw 未安装"
        fi
        echo ""

        draw_menu_item "1" "📦" "安装 ufw"
        draw_menu_item "2" "✅" "启用防火墙"
        draw_menu_item "3" "❌" "禁用防火墙"
        draw_menu_item "4" "➕" "开放端口"
        draw_menu_item "5" "➖" "关闭端口"
        draw_menu_item "6" "📋" "查看规则"
        draw_menu_item "7" "🔄" "重置规则"
        draw_menu_item "8" "🗑️" "卸载 ufw"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回上级菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-8]: )" ufw_choice </dev/tty

        case $ufw_choice in
            1)
                clear
                log_info "正在安装 ufw..."
                pkg_update && pkg_install ufw
                log_success "ufw 安装完成！"
                echo ""
                echo -e "  ${YELLOW}提示: 启用前请先开放 SSH 端口 (22)${NC}"
                press_any_key
                ;;
            2)
                clear
                draw_title_line "启用 ufw" 50
                echo ""
                if ! command -v ufw &>/dev/null; then
                    log_error "ufw 未安装！"
                    press_any_key
                    continue
                fi
                echo -e "  ${YELLOW}⚠ 警告：启用防火墙前请确保已开放 SSH 端口！${NC}"
                echo ""
                read -p "是否先开放 SSH 端口 22? (y/n): " open_ssh </dev/tty
                if [[ "$open_ssh" == "y" || "$open_ssh" == "Y" ]]; then
                    sudo ufw allow 22/tcp
                    log_success "已开放 SSH 端口 22"
                fi
                echo ""
                read -p "确认启用防火墙? (y/n): " confirm </dev/tty
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    sudo ufw --force enable
                    log_success "防火墙已启用！"
                fi
                press_any_key
                ;;
            3)
                sudo ufw disable
                log_success "防火墙已禁用"
                press_any_key
                ;;
            4)
                clear
                draw_title_line "开放端口" 50
                echo ""
                if ! command -v ufw &>/dev/null; then
                    log_error "ufw 未安装！"
                    press_any_key
                    continue
                fi
                read -p "请输入要开放的端口 (如 80 或 80/tcp): " port </dev/tty
                if [[ -n "$port" && "$port" =~ ^[0-9]+(/[a-z]+)?$ ]]; then
                    sudo ufw allow "$port"
                    log_success "已开放端口: $port"
                elif [[ -n "$port" ]]; then
                    log_error "无效端口格式！示例: 80 或 443/tcp"
                fi
                press_any_key
                ;;
            5)
                clear
                draw_title_line "关闭端口" 50
                echo ""
                if ! command -v ufw &>/dev/null; then
                    log_error "ufw 未安装！"
                    press_any_key
                    continue
                fi
                read -p "请输入要关闭的端口 (如 80 或 80/tcp): " port </dev/tty
                if [[ -n "$port" && "$port" =~ ^[0-9]+(/[a-z]+)?$ ]]; then
                    sudo ufw deny "$port"
                    log_success "已关闭端口: $port"
                elif [[ -n "$port" ]]; then
                    log_error "无效端口格式！示例: 80 或 443/tcp"
                fi
                press_any_key
                ;;
            6)
                clear
                draw_title_line "ufw 规则列表" 50
                echo ""
                if ! command -v ufw &>/dev/null; then
                    log_error "ufw 未安装！"
                else
                    sudo ufw status numbered
                fi
                press_any_key
                ;;
            7)
                clear
                draw_title_line "重置 ufw 规则" 50
                echo ""
                echo -e "  ${RED}${BOLD}⚠ 警告：将删除所有防火墙规则！${NC}"
                echo ""
                read -p "请输入 'yes' 确认重置: " confirm </dev/tty
                if [[ "$confirm" == "yes" ]]; then
                    sudo ufw --force reset
                    log_success "ufw 规则已重置！"
                else
                    log_info "操作已取消。"
                fi
                press_any_key
                ;;
            8)
                clear
                if ! command -v ufw &>/dev/null; then
                    log_warning "ufw 未安装，无需卸载。"
                    press_any_key
                    continue
                fi
                read -p "确认卸载 ufw? (y/n): " confirm </dev/tty
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    sudo ufw --force disable 2>/dev/null || true
                    pkg_remove ufw
                    log_success "ufw 已卸载！"
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

# ================== 安全工具子菜单 ==================
# ================== SSH 安全配置 ==================
ssh_security_menu() {
    while true; do
        clear
        draw_title_line "SSH 安全配置" 50
        echo ""

        # 显示当前状态
        local pass_auth=$(grep -E "^PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
        local pubkey_auth=$(grep -E "^PubkeyAuthentication" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')

        echo -e "  ${WHITE}${BOLD}当前 SSH 配置状态${NC}"
        if [[ "$pass_auth" == "no" ]]; then
            echo -e "  ${RED}●${NC} 密码登录: ${RED}已禁用${NC}"
        else
            echo -e "  ${GREEN}●${NC} 密码登录: ${GREEN}已启用${NC}"
        fi
        if [[ "$pubkey_auth" == "no" ]]; then
            echo -e "  ${RED}●${NC} 密钥登录: ${RED}已禁用${NC}"
        else
            echo -e "  ${GREEN}●${NC} 密钥登录: ${GREEN}已启用${NC}"
        fi

        if [[ -f ~/.ssh/authorized_keys ]]; then
            local key_count=$(wc -l < ~/.ssh/authorized_keys 2>/dev/null || echo 0)
            echo -e "  ${CYAN}已授权密钥:${NC} ${key_count} 个"
        else
            echo -e "  ${CYAN}已授权密钥:${NC} 0 个"
        fi
        echo ""

        draw_menu_item "1" "🔑" "生成 SSH 密钥对"
        draw_menu_item "2" "📥" "添加公钥到授权列表"
        draw_menu_item "3" "🔒" "禁用密码登录 (仅密钥)"
        draw_menu_item "4" "🔓" "恢复密码登录"
        draw_menu_item "5" "📋" "查看当前公钥"
        draw_menu_item "6" "📋" "查看当前私钥"
        draw_menu_item "7" "🗑️" "删除密钥文件"
        draw_menu_item "8" "❓" "使用帮助"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回上级菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-8]: )" ssh_choice </dev/tty

        case $ssh_choice in
            1)
                clear
                draw_title_line "生成 SSH 密钥对" 50
                echo ""
                if [[ -f ~/.ssh/id_rsa || -f ~/.ssh/id_ed25519 ]]; then
                    log_warning "检测到已存在密钥文件！"
                    read -p "是否覆盖生成新密钥? (y/n): " confirm </dev/tty
                    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && { press_any_key; continue; }
                fi

                echo ""
                echo -e "  ${CYAN}选择密钥类型:${NC}"
                echo -e "  1. ED25519 (推荐，更安全更快)"
                echo -e "  2. RSA 4096 (兼容性好)"
                echo ""
                read -p "请选择 [1/2]: " key_type </dev/tty

                echo ""
                echo -e "  ${CYAN}是否为私钥设置密码保护？${NC}"
                echo -e "  ${GRAY}(设置密码后，每次使用私钥都需要输入密码)${NC}"
                echo ""
                read -p "设置密码保护? (y/n): " use_pass </dev/tty

                local passphrase=""
                if [[ "$use_pass" == "y" || "$use_pass" == "Y" ]]; then
                    echo ""
                    read -s -p "请输入密钥密码: " passphrase </dev/tty
                    echo ""
                    read -s -p "请再次确认密码: " passphrase2 </dev/tty
                    echo ""
                    if [[ "$passphrase" != "$passphrase2" ]]; then
                        log_error "两次密码不一致！"
                        press_any_key
                        continue
                    fi
                fi

                mkdir -p ~/.ssh
                chmod 700 ~/.ssh

                local pubkey_file=""
                if [[ "$key_type" == "2" ]]; then
                    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "$passphrase" -C "fishtools-$(date +%Y%m%d)"
                    pubkey_file=~/.ssh/id_rsa.pub
                    log_success "RSA 密钥对已生成！"
                    echo ""
                    echo -e "  ${CYAN}私钥位置:${NC} ~/.ssh/id_rsa"
                    echo -e "  ${CYAN}公钥位置:${NC} ~/.ssh/id_rsa.pub"
                else
                    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "$passphrase" -C "fishtools-$(date +%Y%m%d)"
                    pubkey_file=~/.ssh/id_ed25519.pub
                    log_success "ED25519 密钥对已生成！"
                    echo ""
                    echo -e "  ${CYAN}私钥位置:${NC} ~/.ssh/id_ed25519"
                    echo -e "  ${CYAN}公钥位置:${NC} ~/.ssh/id_ed25519.pub"
                fi

                # 自动将公钥添加到 authorized_keys
                cat "$pubkey_file" >> ~/.ssh/authorized_keys
                chmod 600 ~/.ssh/authorized_keys
                echo ""
                echo -e "  ${GREEN}✓ 公钥已自动添加到 authorized_keys${NC}"

                # 自动启用 sshd 公钥认证配置
                log_info "正在配置 sshd 以启用公钥认证..."

                # 备份 sshd_config
                sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d%H%M%S) 2>/dev/null || true

                # 启用 PubkeyAuthentication
                sudo sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
                grep -q "^PubkeyAuthentication" /etc/ssh/sshd_config || echo "PubkeyAuthentication yes" | sudo tee -a /etc/ssh/sshd_config > /dev/null

                # 确保 AuthorizedKeysFile 配置正确
                sudo sed -i 's/^#*AuthorizedKeysFile.*/AuthorizedKeysFile .ssh\/authorized_keys/' /etc/ssh/sshd_config
                grep -q "^AuthorizedKeysFile" /etc/ssh/sshd_config || echo "AuthorizedKeysFile .ssh/authorized_keys" | sudo tee -a /etc/ssh/sshd_config > /dev/null

                # 重启 sshd 服务使配置生效
                sudo systemctl restart sshd 2>/dev/null || sudo service ssh restart 2>/dev/null || true

                echo -e "  ${GREEN}✓ sshd 公钥认证已启用并重启服务${NC}"
                echo ""
                if [[ -n "$passphrase" ]]; then
                    echo -e "  ${GREEN}✓ 私钥已设置密码保护${NC}"
                else
                    echo -e "  ${YELLOW}○ 私钥无密码保护${NC}"
                fi

                # 获取服务器 IP 和当前用户
                local server_ip
                server_ip=$(get_primary_access_host)
                [[ -z "$server_ip" ]] && server_ip="<服务器IP>"
                local current_user=$(whoami)
                local key_name="id_ed25519"
                [[ "$key_type" == "2" ]] && key_name="id_rsa"

                echo ""
                echo -e "  ${WHITE}${BOLD}═══════════════════════════════════════════${NC}"
                echo -e "  ${WHITE}${BOLD}下一步操作 (必读)：${NC}"
                echo -e "  ${WHITE}${BOLD}═══════════════════════════════════════════${NC}"
                echo ""
                echo -e "  ${CYAN}步骤 1:${NC} 复制下方私钥内容到本地文件"
                echo -e "         保存为: ${YELLOW}~/.ssh/${key_name}_server${NC}"
                echo ""
                echo -e "  ${CYAN}步骤 2:${NC} 在本地终端设置私钥权限"
                echo -e "         ${WHITE}chmod 600 ~/.ssh/${key_name}_server${NC}"
                echo ""
                echo -e "  ${CYAN}步骤 3:${NC} 测试密钥登录 (在本地执行)"
                echo -e "         ${WHITE}ssh -i ~/.ssh/${key_name}_server ${current_user}@${server_ip}${NC}"
                echo ""
                echo -e "  ${CYAN}步骤 4:${NC} 确认登录成功后，可禁用密码登录"
                echo -e "         使用菜单选项 3「禁用密码登录」"
                echo ""
                echo -e "  ${RED}${BOLD}⚠ 重要提示：${NC}"
                echo -e "  ${YELLOW}• 私钥必须下载到本地才能使用！${NC}"
                echo -e "  ${YELLOW}• 请妥善保管私钥，丢失后无法恢复！${NC}"
                echo -e "  ${YELLOW}• 禁用密码登录前请务必测试密钥登录！${NC}"
                echo ""
                read -p "是否立即显示私钥内容? (y/n): " show_key </dev/tty
                if [[ "$show_key" == "y" || "$show_key" == "Y" ]]; then
                    echo ""
                    echo -e "  ${WHITE}${BOLD}私钥内容 (请完整复制保存):${NC}"
                    echo -e "  ${GRAY}─────────────── 开始 ───────────────${NC}"
                    if [[ "$key_type" == "2" ]]; then
                        cat ~/.ssh/id_rsa
                    else
                        cat ~/.ssh/id_ed25519
                    fi
                    echo -e "  ${GRAY}─────────────── 结束 ───────────────${NC}"
                fi
                press_any_key
                ;;
            2)
                clear
                draw_title_line "添加公钥" 50
                echo ""
                echo -e "  ${WHITE}请粘贴您的公钥内容 (ssh-rsa 或 ssh-ed25519 开头):${NC}"
                echo ""
                read -p "公钥: " pubkey </dev/tty

                if [[ -z "$pubkey" ]]; then
                    log_error "公钥不能为空！"
                    press_any_key
                    continue
                fi

                if ! echo "$pubkey" | grep -qE "^ssh-(rsa|ed25519|ecdsa)"; then
                    log_error "公钥格式不正确！"
                    press_any_key
                    continue
                fi

                mkdir -p ~/.ssh
                chmod 700 ~/.ssh
                echo "$pubkey" >> ~/.ssh/authorized_keys
                chmod 600 ~/.ssh/authorized_keys
                log_success "公钥已添加到授权列表！"
                press_any_key
                ;;
            3)
                clear
                draw_title_line "禁用密码登录" 50
                echo ""
                echo -e "  ${RED}${BOLD}⚠ 警告：禁用密码登录后只能用密钥登录！${NC}"
                echo ""
                echo -e "  ${YELLOW}请确保：${NC}"
                echo -e "    1. 已配置密钥登录并测试成功"
                echo -e "    2. 已保存私钥到本地"
                echo ""

                if [[ ! -f ~/.ssh/authorized_keys ]] || [[ ! -s ~/.ssh/authorized_keys ]]; then
                    log_error "未检测到已授权的公钥！请先添加公钥。"
                    press_any_key
                    continue
                fi

                read -p "请输入 'yes' 确认禁用密码登录: " confirm </dev/tty
                if [[ "$confirm" != "yes" ]]; then
                    log_info "操作已取消。"
                    press_any_key
                    continue
                fi

                # 备份配置
                sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d%H%M%S)

                # 修改配置
                sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
                sudo sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
                sudo sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config

                # 如果配置项不存在则添加
                grep -q "^PasswordAuthentication" /etc/ssh/sshd_config || echo "PasswordAuthentication no" | sudo tee -a /etc/ssh/sshd_config
                grep -q "^PubkeyAuthentication" /etc/ssh/sshd_config || echo "PubkeyAuthentication yes" | sudo tee -a /etc/ssh/sshd_config

                sudo systemctl restart sshd
                log_success "密码登录已禁用，仅允许密钥登录！"
                echo ""
                echo -e "  ${GREEN}配置已备份到 /etc/ssh/sshd_config.bak.*${NC}"
                press_any_key
                ;;
            4)
                clear
                draw_title_line "恢复密码登录" 50
                echo ""
                read -p "确认恢复密码登录? (y/n): " confirm </dev/tty
                if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                    log_info "操作已取消。"
                    press_any_key
                    continue
                fi

                sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
                sudo systemctl restart sshd
                log_success "密码登录已恢复！"
                press_any_key
                ;;
            5)
                clear
                draw_title_line "当前公钥" 50
                echo ""
                if [[ -f ~/.ssh/id_ed25519.pub ]]; then
                    echo -e "  ${CYAN}ED25519 公钥:${NC}"
                    echo ""
                    cat ~/.ssh/id_ed25519.pub
                    echo ""
                elif [[ -f ~/.ssh/id_rsa.pub ]]; then
                    echo -e "  ${CYAN}RSA 公钥:${NC}"
                    echo ""
                    cat ~/.ssh/id_rsa.pub
                    echo ""
                else
                    log_warning "未找到公钥文件，请先生成密钥对。"
                fi
                echo ""
                echo -e "  ${GRAY}提示: 将此公钥添加到其他服务器即可免密登录${NC}"
                press_any_key
                ;;
            6)
                clear
                draw_title_line "当前私钥" 50
                echo ""
                echo -e "  ${RED}${BOLD}⚠ 警告：私钥是敏感信息，请勿泄露！${NC}"
                echo ""
                if [[ -f ~/.ssh/id_ed25519 ]]; then
                    echo -e "  ${CYAN}ED25519 私钥:${NC}"
                    echo -e "  ${GRAY}--- 开始 ---${NC}"
                    cat ~/.ssh/id_ed25519
                    echo -e "  ${GRAY}--- 结束 ---${NC}"
                elif [[ -f ~/.ssh/id_rsa ]]; then
                    echo -e "  ${CYAN}RSA 私钥:${NC}"
                    echo -e "  ${GRAY}--- 开始 ---${NC}"
                    cat ~/.ssh/id_rsa
                    echo -e "  ${GRAY}--- 结束 ---${NC}"
                else
                    log_warning "未找到私钥文件，请先生成密钥对。"
                fi
                press_any_key
                ;;
            7)
                clear
                draw_title_line "删除密钥文件" 50
                echo ""
                echo -e "  ${WHITE}${BOLD}检测到的密钥文件：${NC}"
                echo ""
                local has_keys=0
                [[ -f ~/.ssh/id_ed25519 ]] && { echo -e "  • ~/.ssh/id_ed25519 (私钥)"; has_keys=1; }
                [[ -f ~/.ssh/id_ed25519.pub ]] && { echo -e "  • ~/.ssh/id_ed25519.pub (公钥)"; has_keys=1; }
                [[ -f ~/.ssh/id_rsa ]] && { echo -e "  • ~/.ssh/id_rsa (私钥)"; has_keys=1; }
                [[ -f ~/.ssh/id_rsa.pub ]] && { echo -e "  • ~/.ssh/id_rsa.pub (公钥)"; has_keys=1; }
                [[ -f ~/.ssh/authorized_keys ]] && echo -e "  • ~/.ssh/authorized_keys (授权公钥列表)"

                if [[ $has_keys -eq 0 ]]; then
                    echo -e "  ${GRAY}未找到密钥文件${NC}"
                    press_any_key
                    continue
                fi

                echo ""
                echo -e "  ${CYAN}选择要删除的内容:${NC}"
                echo -e "  1. 仅删除私钥 (保留公钥)"
                echo -e "  2. 删除密钥对 (私钥+公钥)"
                echo -e "  3. 清空授权公钥列表"
                echo -e "  4. 全部删除"
                echo ""
                read -p "请选择 [1-4]: " del_choice </dev/tty

                case $del_choice in
                    1)
                        rm -f ~/.ssh/id_ed25519 ~/.ssh/id_rsa 2>/dev/null
                        log_success "私钥已删除"
                        ;;
                    2)
                        rm -f ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub ~/.ssh/id_rsa ~/.ssh/id_rsa.pub 2>/dev/null
                        log_success "密钥对已删除"
                        ;;
                    3)
                        rm -f ~/.ssh/authorized_keys 2>/dev/null
                        log_success "授权公钥列表已清空"
                        ;;
                    4)
                        echo ""
                        read -p "请输入 'yes' 确认删除所有密钥文件: " confirm </dev/tty
                        if [[ "$confirm" == "yes" ]]; then
                            rm -f ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub ~/.ssh/id_rsa ~/.ssh/id_rsa.pub ~/.ssh/authorized_keys 2>/dev/null
                            log_success "所有密钥文件已删除"
                        else
                            log_info "操作已取消"
                        fi
                        ;;
                esac
                press_any_key
                ;;
            8)
                clear
                draw_title_line "SSH 密钥登录帮助" 50
                echo ""
                echo -e "  ${WHITE}${BOLD}什么是密钥登录？${NC}"
                echo -e "  使用密钥对（公钥+私钥）代替密码进行 SSH 认证"
                echo -e "  更安全，不怕暴力破解"
                echo ""
                echo -e "  ${WHITE}${BOLD}配置步骤：${NC}"
                echo -e "  1. 生成密钥对（本菜单选项 1）"
                echo -e "  2. 复制私钥到本地电脑保存"
                echo -e "  3. 测试密钥登录是否成功"
                echo -e "  4. 确认无误后禁用密码登录（选项 3）"
                echo ""
                echo -e "  ${WHITE}${BOLD}本地使用私钥登录：${NC}"
                echo -e "  ${CYAN}ssh -i ~/.ssh/id_ed25519 user@server${NC}"
                echo ""
                echo -e "  ${WHITE}${BOLD}Windows 用户：${NC}"
                echo -e "  使用 PuTTY 或 Xshell 导入私钥文件"
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

# ================== 安全工具子菜单 ==================
show_security_menu() {
    while true; do
        clear
        draw_title_line "安全工具" 50
        echo ""
        echo -e "  ${WHITE}${BOLD}VPS 安全防护工具${NC}"
        echo ""
        echo -e "  ${CYAN}fail2ban${NC} - 自动封禁暴力破解 IP"
        echo -e "  ${CYAN}ufw${NC}      - 简化版防火墙管理"
        echo -e "  ${CYAN}SSH 安全${NC} - 密钥登录配置"
        echo ""
        draw_menu_item "1" "🛡️" "fail2ban (防暴力破解)"
        draw_menu_item "2" "🔥" "ufw (防火墙)"
        draw_menu_item "3" "🔑" "SSH 安全 (密钥登录)"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回上级菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-3]: )" sec_choice </dev/tty

        case $sec_choice in
            1) install_fail2ban_menu ;;
            2) install_ufw_menu ;;
            3) ssh_security_menu ;;
            0) break ;;
            *) log_error "无效输入。"; press_any_key ;;
        esac
    done
}

# ================== 常用软件安装主菜单 ==================
show_install_menu() {
    while true; do
        clear
        draw_title_line "常用软件安装" 50
        echo ""
        draw_menu_item "1" "🐳" "Docker 安装"
        draw_menu_item "2" "🔀" "反代工具 (Nginx / Caddy)"
        draw_menu_item "3" "🛡️" "安全工具 (fail2ban / ufw / SSH密钥)"
        draw_menu_item "4" "📊" "系统监控 (htop / btop)"
        draw_menu_item "5" "🖥️" "tmux (终端复用)"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回主菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-5]: )" install_choice </dev/tty

        case $install_choice in
            1) install_docker_menu ;;
            2) show_proxy_menu ;;
            3) show_security_menu ;;
            4) install_monitor_menu ;;
            5) install_tmux_menu ;;
            0) break ;;
            *) log_error "无效输入。"; press_any_key ;;
        esac
    done
}

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
                if curl -fsL https://raw.githubusercontent.com/zhanghanyun/backtrace/main/install.sh -o backtrace.sh 2>/dev/null; then
                    log_success "下载成功，开始执行..."
                    echo ""
                    chmod +x backtrace.sh && bash backtrace.sh || true
                    rm -f backtrace.sh
                else
                    log_error "脚本下载失败！"
                fi
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
                if curl -fsL https://raw.githubusercontent.com/nxtrace/NTrace-core/main/nt_install.sh -o nt_install.sh 2>/dev/null; then
                    bash nt_install.sh || true
                    rm -f nt_install.sh
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
                if curl -fL https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh -o ecs.sh; then
                    log_success "主链接下载成功。"
                    chmod +x ecs.sh && bash ecs.sh
                else
                    log_warning "主链接下载失败，尝试从备用链接 (github) 下载..."
                    if curl -fL https://github.com/spiritLHLS/ecs/raw/main/ecs.sh -o ecs.sh; then
                        log_success "备用链接下载成功。"
                        chmod +x ecs.sh && bash ecs.sh
                    else
                        log_error "主链接和备用链接均下载失败！"
                    fi
                fi
                rm -f ecs.sh
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
                    if curl -fsL "https://raw.githubusercontent.com/${AUTHOR_GITHUB_USER}/${MAIN_REPO_NAME}/main/scripts/fish_ipcheck.sh" -o fish_ipcheck.sh 2>/dev/null; then
                        log_success "下载成功，开始执行..."
                        echo ""
                        bash fish_ipcheck.sh || true
                        rm -f fish_ipcheck.sh
                    else
                        log_error "脚本下载失败！"
                    fi
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
                if curl -fsL https://raw.githubusercontent.com/uxh/superspeed/master/superspeed.sh -o superspeed.sh 2>/dev/null; then
                    log_success "下载成功，开始执行..."
                    echo ""
                    bash superspeed.sh || true
                    rm -f superspeed.sh
                else
                    # 备用方案
                    log_warning "主脚本下载失败，尝试备用方案..."
                    bash <(curl -Lso- https://bench.im/hyperspeed) || \
                    log_error "三网测速脚本下载失败！"
                fi
                press_any_key
                ;;
            6)
                clear
                draw_title_line "磁盘 IO 测试" 50
                echo ""
                log_info "开始磁盘 IO 测试..."
                echo ""

                echo -e "  ${WHITE}${BOLD}顺序写入测试 (1GB)${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                sync
                local write_result=$(dd if=/dev/zero of=./test_io_file bs=1M count=1024 conv=fdatasync 2>&1)
                local write_speed=$(echo "$write_result" | grep -oP '\d+\.?\d*\s*(MB|GB)/s' | tail -1)
                echo -e "  ${GREEN}写入速度:${NC} ${write_speed:-解析失败}"

                echo ""
                echo -e "  ${WHITE}${BOLD}顺序读取测试${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                # 清除缓存
                sync && echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || true
                local read_result=$(dd if=./test_io_file of=/dev/null bs=1M 2>&1)
                local read_speed=$(echo "$read_result" | grep -oP '\d+\.?\d*\s*(MB|GB)/s' | tail -1)
                echo -e "  ${GREEN}读取速度:${NC} ${read_speed:-解析失败}"

                # 清理测试文件
                rm -f ./test_io_file

                echo ""
                echo -e "  ${WHITE}${BOLD}4K 随机读写测试${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                if command -v fio &>/dev/null; then
                    local fio_result=$(fio --name=random-rw --ioengine=sync --rw=randrw --bs=4k --size=64m --numjobs=1 --time_based --runtime=10 --group_reporting --filename=./fio_test 2>&1)
                    local read_iops=$(echo "$fio_result" | grep "read:" | grep -oP 'IOPS=\K[\d.]+[kKmM]?' | head -1)
                    local write_iops=$(echo "$fio_result" | grep "write:" | grep -oP 'IOPS=\K[\d.]+[kKmM]?' | head -1)
                    echo -e "  ${GREEN}4K 随机读 IOPS:${NC} ${read_iops:-N/A}"
                    echo -e "  ${GREEN}4K 随机写 IOPS:${NC} ${write_iops:-N/A}"
                    rm -f ./fio_test
                else
                    echo -e "  ${YELLOW}fio 未安装，跳过 4K 随机读写测试${NC}"
                    echo -e "  ${DIM}可通过 apt install fio 安装${NC}"
                fi

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

                log_info "尝试从主链接 (github) 下载 reinstall.sh..."
                if curl -fL -o reinstall.sh https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh; then
                    log_success "主链接下载成功。"
                else
                    log_warning "主链接下载失败，尝试从备用链接 (cnb.cool) 下载..."
                    if ! curl -fL -o reinstall.sh https://cnb.cool/bin456789/reinstall/-/git/raw/main/reinstall.sh; then
                         log_error "主链接和备用链接均下载失败！"
                         rm -f reinstall.sh
                         press_any_key
                         continue
                    fi
                    log_success "备用链接下载成功。"
                fi

                # 验证下载的文件是否为有效的 shell 脚本
                if [[ ! -f reinstall.sh ]] || ! head -1 reinstall.sh | grep -qE '^#!.*bash'; then
                    log_error "下载的文件不是有效的 shell 脚本！"
                    rm -f reinstall.sh
                    press_any_key
                    continue
                fi

                log_info "脚本已下载，即将执行。请根据后续脚本提示操作！"
                echo ""
                bash reinstall.sh
                local reinstall_exit=$?
                rm -f reinstall.sh
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

                log_info "尝试从主链接 (github) 下载 OsMutation.sh..."
                if curl -fL -o OsMutation.sh https://raw.githubusercontent.com/LloydAsp/OsMutation/main/OsMutation.sh; then
                    log_success "主链接下载成功。"
                else
                    log_warning "主链接下载失败，尝试从备用链接 (cnb.cool) 下载..."
                    if ! curl -fL -o OsMutation.sh https://cnb.cool/LloydAsp/OsMutation/-/raw/main/OsMutation.sh; then
                        log_error "主链接和备用链接均下载失败！"
                        rm -f OsMutation.sh
                        press_any_key
                        continue
                    fi
                    log_success "备用链接下载成功。"
                fi

                # 验证下载的文件是否为有效的 shell 脚本
                if [[ ! -f OsMutation.sh ]] || ! head -1 OsMutation.sh | grep -qE '^#!.*bash'; then
                    log_error "下载的文件不是有效的 shell 脚本！"
                    rm -f OsMutation.sh
                    press_any_key
                    continue
                fi

                log_info "脚本已下载，即将执行。请根据后续脚本提示操作！"
                echo ""
                bash OsMutation.sh
                local osmu_exit=$?
                rm -f OsMutation.sh
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
        print_service_access_url "$custom_port" "http"
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

# ================== 系统工具菜单 ==================
print_diag_item() {
    local status="$1"
    local name="$2"
    local detail="$3"

    case "$status" in
        ok) echo -e "  ${GREEN}✓${NC} ${name}: ${detail}" ;;
        warn) echo -e "  ${YELLOW}⚠${NC} ${name}: ${detail}" ;;
        fail) echo -e "  ${RED}✗${NC} ${name}: ${detail}" ;;
        *) echo -e "  ${GRAY}-${NC} ${name}: ${detail}" ;;
    esac
}

show_system_diagnostics() {
    clear
    draw_title_line "系统自检诊断" 50
    echo ""

    echo -e "  ${WHITE}${BOLD}基础信息${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    print_diag_item ok "主机名" "$(hostname 2>/dev/null || echo unknown)"
    print_diag_item ok "内核" "$(uname -srmo 2>/dev/null || uname -a)"
    if [[ -f /etc/os-release ]]; then
        local os_name
        os_name=$(grep -E '^PRETTY_NAME=' /etc/os-release | cut -d= -f2- | tr -d '"' 2>/dev/null)
        print_diag_item ok "系统" "${os_name:-unknown}"
    fi
    print_diag_item ok "包管理器" "$(detect_pkg_manager)"
    echo ""

    echo -e "  ${WHITE}${BOLD}关键依赖${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    local cmd
    for cmd in curl sudo awk sed grep systemctl; do
        if command -v "$cmd" &>/dev/null; then
            print_diag_item ok "$cmd" "$(command -v "$cmd")"
        else
            print_diag_item fail "$cmd" "未安装"
        fi
    done
    for cmd in jq bc dig ss; do
        if command -v "$cmd" &>/dev/null; then
            print_diag_item ok "$cmd" "$(command -v "$cmd")"
        else
            print_diag_item warn "$cmd" "未安装，部分功能可能受限"
        fi
    done
    echo ""

    echo -e "  ${WHITE}${BOLD}Docker 状态${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    if command -v docker &>/dev/null; then
        print_diag_item ok "docker" "$(docker --version 2>/dev/null | head -1)"
        if docker compose version &>/dev/null; then
            print_diag_item ok "compose" "$(docker compose version 2>/dev/null | head -1)"
        else
            print_diag_item warn "compose" "Docker Compose 插件不可用"
        fi
        if systemctl is-active --quiet docker 2>/dev/null; then
            print_diag_item ok "docker 服务" "运行中"
        else
            print_diag_item warn "docker 服务" "未运行或非 systemd 环境"
        fi
    else
        print_diag_item warn "docker" "未安装"
    fi
    echo ""

    echo -e "  ${WHITE}${BOLD}网络连通性${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    local public_ipv4
    public_ipv4=$(get_public_ipv4)
    if [[ -n "$public_ipv4" ]]; then
        print_diag_item ok "公网 IPv4" "$public_ipv4"
    else
        print_diag_item warn "公网 IPv4" "获取失败"
    fi
    if curl -fsSL --max-time 5 "https://raw.githubusercontent.com/${AUTHOR_GITHUB_USER}/${MAIN_REPO_NAME}/main/fishtools.sh" -o /dev/null 2>/dev/null; then
        print_diag_item ok "GitHub Raw" "可访问"
    else
        print_diag_item warn "GitHub Raw" "访问失败，更新/预设/Gost 自动补齐可能受影响"
    fi
    echo ""

    echo -e "  ${WHITE}${BOLD}磁盘与 inode${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    df -h / 2>/dev/null | awk 'NR==1{print "  "$0} NR==2{print "  "$0}'
    df -ih / 2>/dev/null | awk 'NR==1{print "  "$0} NR==2{print "  "$0}'
    echo ""

    echo -e "  ${WHITE}${BOLD}常用端口占用${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    local port
    for port in 22 53 80 443 3000 3001 8080 8081 8443; do
        if is_port_in_use "$port"; then
            print_diag_item warn "端口 ${port}" "已占用"
        else
            print_diag_item ok "端口 ${port}" "空闲"
        fi
    done
    echo ""
    press_any_key
}

show_config_backup_menu() {
    local backup_dir="/var/backups/fishtools"

    clear
    draw_title_line "配置备份恢复" 50
    echo ""

    if [[ ! -d "$backup_dir" ]]; then
        log_warning "暂无备份目录: $backup_dir"
        press_any_key
        return
    fi

    local backups=()
    local backup_file
    while IFS= read -r backup_file; do
        backups+=("$backup_file")
    done < <(ls -1t "$backup_dir"/*.bak 2>/dev/null)

    if [[ ${#backups[@]} -eq 0 ]]; then
        log_warning "暂无可恢复的配置备份"
        press_any_key
        return
    fi

    echo -e "  ${WHITE}${BOLD}最近备份${NC}"
    echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
    local i original_path display_count
    display_count=${#backups[@]}
    [[ $display_count -gt 20 ]] && display_count=20

    for ((i=0; i<display_count; i++)); do
        original_path="未知原路径"
        [[ -f "${backups[$i]}.path" ]] && original_path=$(cat "${backups[$i]}.path" 2>/dev/null)
        echo -e "  ${CYAN}$((i + 1)).${NC} ${original_path}"
        echo -e "      ${DIM}$(basename "${backups[$i]}")${NC}"
    done

    echo ""
    read -p "请选择要恢复的备份 [1-${display_count}]，或回车取消: " backup_choice </dev/tty
    [[ -z "$backup_choice" ]] && return 0

    if [[ ! "$backup_choice" =~ ^[0-9]+$ ]] || [[ "$backup_choice" -lt 1 ]] || [[ "$backup_choice" -gt "$display_count" ]]; then
        log_error "无效选择"
        press_any_key
        return 1
    fi

    local selected_backup="${backups[$((backup_choice - 1))]}"
    local restore_path=""
    [[ -f "${selected_backup}.path" ]] && restore_path=$(cat "${selected_backup}.path" 2>/dev/null)
    if [[ -z "$restore_path" || "$restore_path" == "未知原路径" ]]; then
        read -p "无法识别原路径，请输入恢复目标路径: " restore_path </dev/tty
    fi

    if [[ -z "$restore_path" || "$restore_path" != /* ]]; then
        log_error "恢复目标路径无效"
        press_any_key
        return 1
    fi

    echo ""
    echo -e "  备份文件: ${CYAN}${selected_backup}${NC}"
    echo -e "  恢复到:   ${CYAN}${restore_path}${NC}"
    echo ""
    read -p "确认恢复? (y/n): " confirm_restore </dev/tty
    if [[ "$confirm_restore" != "y" && "$confirm_restore" != "Y" ]]; then
        log_info "操作已取消"
        press_any_key
        return 0
    fi

    if [[ -e "$restore_path" ]]; then
        backup_config_file "$restore_path" >/dev/null || {
            log_error "恢复前备份当前配置失败，已取消恢复"
            press_any_key
            return 1
        }
    fi

    if sudo cp -a "$selected_backup" "$restore_path"; then
        log_success "配置已恢复: $restore_path"
    else
        log_error "恢复失败，请检查权限和路径"
    fi
    press_any_key
}

show_system_tools_menu() {
    while true; do
        clear
        draw_title_line "系统工具" 50
        echo ""
        draw_menu_item "1" "🧹" "磁盘清理"
        draw_menu_item "2" "🌐" "修改时区"
        draw_menu_item "3" "🏷️" "修改主机名"
        draw_menu_item "4" "🔌" "修改 SSH 端口"
        draw_menu_item "5" "📅" "定时任务管理"
        draw_menu_item "6" "🔄" "系统重启/关机"
        draw_menu_item "7" "📦" "系统包一键更新"
        draw_menu_item "8" "📋" "系统日志查看"
        draw_menu_item "9" "📊" "流量统计 (vnstat)"
        draw_menu_item "10" "🩺" "系统自检诊断"
        draw_menu_item "11" "♻️" "配置备份恢复"
        echo ""
        draw_separator 50
        draw_menu_item "0" "🔙" "返回主菜单"
        draw_footer 50
        echo ""
        read -p "$(echo -e ${CYAN}请输入选择${NC} [0-11]: )" tools_choice </dev/tty

        case $tools_choice in
            1)
                clear
                draw_title_line "磁盘清理" 50
                echo ""

                # 显示当前磁盘使用情况
                echo -e "  ${WHITE}${BOLD}当前磁盘使用情况${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                df -h / | awk 'NR==1{print "  "$0} NR==2{print "  "$0}'
                echo ""

                # 计算可清理空间
                local apt_cache=$(du -sh /var/cache/apt/archives 2>/dev/null | awk '{print $1}' || echo "0")
                local journal=$(du -sh /var/log/journal 2>/dev/null | awk '{print $1}' || echo "0")
                local tmp_size=$(du -sh /tmp 2>/dev/null | awk '{print $1}' || echo "0")
                local old_kernels=$(dpkg -l 'linux-*' 2>/dev/null | grep -E '^ii' | wc -l)

                echo -e "  ${WHITE}${BOLD}可清理项目${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                echo -e "  ${CYAN}1.${NC} APT 缓存            约 ${apt_cache}"
                echo -e "  ${CYAN}2.${NC} 系统日志 (Journal)  约 ${journal}"
                echo -e "  ${CYAN}3.${NC} 临时文件 (/tmp)     约 ${tmp_size}"
                echo -e "  ${CYAN}4.${NC} 旧内核 (保留当前)   ${old_kernels} 个包"
                echo -e "  ${CYAN}5.${NC} 一键清理全部"
                echo ""

                read -p "请选择要清理的项目 [1-5]: " clean_opt </dev/tty
                echo ""

                case $clean_opt in
                    1)
                        log_info "清理包管理器缓存..."
                        local pm=$(detect_pkg_manager)
                        case "$pm" in
                            apt) sudo apt-get clean ;;
                            dnf) sudo dnf clean all ;;
                            yum) sudo yum clean all ;;
                        esac
                        log_success "包缓存已清理"
                        ;;
                    2)
                        log_info "清理系统日志..."
                        sudo journalctl --vacuum-time=7d 2>/dev/null || true
                        log_success "日志已清理（保留7天）"
                        ;;
                    3)
                        log_info "清理临时文件..."
                        safe_clean_tmp_files
                        log_success "临时文件已清理（保留近 60 分钟和系统 socket）"
                        ;;
                    4)
                        log_info "清理旧内核..."
                        local pm=$(detect_pkg_manager)
                        case "$pm" in
                            apt) sudo apt-get autoremove --purge -y 2>/dev/null || true ;;
                            dnf) sudo dnf autoremove -y 2>/dev/null || true ;;
                            yum) sudo package-cleanup --oldkernels --count=1 2>/dev/null || true ;;
                        esac
                        log_success "旧内核已清理"
                        ;;
                    5)
                        log_info "执行一键清理..."
                        local pm=$(detect_pkg_manager)
                        case "$pm" in
                            apt) sudo apt-get clean; sudo apt-get autoremove --purge -y 2>/dev/null || true ;;
                            dnf) sudo dnf clean all; sudo dnf autoremove -y 2>/dev/null || true ;;
                            yum) sudo yum clean all; sudo yum autoremove -y 2>/dev/null || true ;;
                        esac
                        sudo journalctl --vacuum-time=7d 2>/dev/null || true
                        safe_clean_tmp_files
                        safe_clean_user_cache
                        log_success "全部清理完成！"
                        ;;
                esac

                echo ""
                echo -e "  ${WHITE}${BOLD}清理后磁盘使用${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                df -h / | awk 'NR==2{print "  "$0}'
                press_any_key
                ;;
            2)
                clear
                draw_title_line "修改时区" 50
                echo ""
                echo -e "  ${WHITE}${BOLD}当前时区${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                echo -e "  $(timedatectl 2>/dev/null | grep 'Time zone' | awk -F': ' '{print $2}' || date +%Z)"
                echo ""
                echo -e "  ${WHITE}${BOLD}常用时区${NC}"
                echo -e "  ${CYAN}1.${NC} Asia/Shanghai     (中国-上海)"
                echo -e "  ${CYAN}2.${NC} Asia/Hong_Kong    (中国-香港)"
                echo -e "  ${CYAN}3.${NC} Asia/Tokyo        (日本-东京)"
                echo -e "  ${CYAN}4.${NC} Asia/Singapore    (新加坡)"
                echo -e "  ${CYAN}5.${NC} America/New_York  (美国-纽约)"
                echo -e "  ${CYAN}6.${NC} America/Los_Angeles (美国-洛杉矶)"
                echo -e "  ${CYAN}7.${NC} Europe/London     (英国-伦敦)"
                echo -e "  ${CYAN}8.${NC} 自定义输入"
                echo ""
                read -p "请选择时区 [1-8]: " tz_choice </dev/tty

                local new_tz=""
                case $tz_choice in
                    1) new_tz="Asia/Shanghai" ;;
                    2) new_tz="Asia/Hong_Kong" ;;
                    3) new_tz="Asia/Tokyo" ;;
                    4) new_tz="Asia/Singapore" ;;
                    5) new_tz="America/New_York" ;;
                    6) new_tz="America/Los_Angeles" ;;
                    7) new_tz="Europe/London" ;;
                    8)
                        read -p "请输入时区 (如 Asia/Shanghai): " new_tz </dev/tty
                        ;;
                esac

                if [[ -n "$new_tz" ]]; then
                    sudo timedatectl set-timezone "$new_tz" 2>/dev/null || \
                    sudo ln -sf "/usr/share/zoneinfo/$new_tz" /etc/localtime
                    log_success "时区已设置为: $new_tz"
                    echo -e "  当前时间: $(date)"
                fi
                press_any_key
                ;;
            3)
                clear
                draw_title_line "修改主机名" 50
                echo ""
                echo -e "  ${WHITE}${BOLD}当前主机名${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                echo -e "  $(hostname)"
                echo ""
                read -p "请输入新主机名: " new_hostname </dev/tty

                if [[ -n "$new_hostname" ]]; then
                    # 校验主机名格式 (RFC 1123)
                    if [[ ! "$new_hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$ ]]; then
                        log_error "无效主机名！仅允许字母、数字和连字符，不能以连字符开头或结尾"
                        press_any_key
                        continue
                    fi
                    sudo hostnamectl set-hostname "$new_hostname" 2>/dev/null || \
                    echo "$new_hostname" | sudo tee /etc/hostname >/dev/null
                    # 更新 /etc/hosts
                    sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$new_hostname/" /etc/hosts 2>/dev/null || true
                    log_success "主机名已设置为: $new_hostname"
                    echo -e "  ${YELLOW}提示: 重新登录后生效${NC}"
                fi
                press_any_key
                ;;
            4)
                clear
                draw_title_line "修改 SSH 端口" 50
                echo ""
                local current_port=$(grep -E "^Port" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")
                [[ -z "$current_port" ]] && current_port="22"

                echo -e "  ${WHITE}${BOLD}当前 SSH 端口${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                echo -e "  ${current_port}"
                echo ""
                echo -e "  ${YELLOW}⚠ 警告：修改端口前请确保新端口已在防火墙中开放！${NC}"
                echo ""
                read -p "请输入新 SSH 端口 (1024-65535): " new_port </dev/tty

                if [[ "$new_port" =~ ^[0-9]+$ ]] && [[ "$new_port" -ge 1024 ]] && [[ "$new_port" -le 65535 ]]; then
                    if [[ "$new_port" != "$current_port" ]] && is_port_in_use "$new_port"; then
                        log_error "端口 $new_port 已被占用，请选择其他端口。"
                        press_any_key
                        continue
                    fi

                    # 备份配置
                    local backup_file
                    if ! backup_file=$(backup_config_file /etc/ssh/sshd_config); then
                        log_error "备份 SSH 配置失败，已取消操作。"
                        press_any_key
                        continue
                    fi

                    # 修改端口
                    if grep -q "^Port" /etc/ssh/sshd_config; then
                        sudo sed -i "s/^Port.*/Port $new_port/" /etc/ssh/sshd_config
                    elif grep -q "^#Port" /etc/ssh/sshd_config; then
                        sudo sed -i "s/^#Port.*/Port $new_port/" /etc/ssh/sshd_config
                    else
                        echo "Port $new_port" | sudo tee -a /etc/ssh/sshd_config >/dev/null
                    fi

                    if ! test_sshd_config; then
                        sudo cp "$backup_file" /etc/ssh/sshd_config
                        log_error "SSH 配置语法检查失败，已恢复原配置。"
                        press_any_key
                        continue
                    fi

                    # 尝试在防火墙中开放新端口
                    if command -v ufw &>/dev/null; then
                        sudo ufw allow "$new_port"/tcp 2>/dev/null || true
                    fi

                    # 同步更新 fail2ban 配置
                    if command -v fail2ban-client &>/dev/null && [[ -f /etc/fail2ban/jail.local ]]; then
                        sudo sed -i "s/^port = .*/port = $new_port/" /etc/fail2ban/jail.local 2>/dev/null || true
                        # 如果没有 port 行，则在 [sshd] 段后添加
                        if ! grep -q "^port = " /etc/fail2ban/jail.local 2>/dev/null; then
                            sudo sed -i "/^\[sshd\]/a port = $new_port" /etc/fail2ban/jail.local 2>/dev/null || true
                        fi
                        sudo systemctl restart fail2ban 2>/dev/null || true
                        log_info "fail2ban 已同步更新到端口 $new_port"
                    fi

                    log_success "SSH 端口已修改为: $new_port"
                    echo ""
                    echo -e "  ${RED}${BOLD}重要提示：${NC}"
                    echo -e "  1. 请确保防火墙已开放端口 $new_port"
                    echo -e "  2. 新开一个终端测试: ${CYAN}ssh -p $new_port user@ip${NC}"
                    echo -e "  3. 确认能连接后再关闭当前终端"
                    echo ""
                    read -p "是否立即重启 SSH 服务? (y/n): " restart_ssh </dev/tty
                    if [[ "$restart_ssh" == "y" || "$restart_ssh" == "Y" ]]; then
                        if sudo systemctl restart sshd 2>/dev/null || sudo service ssh restart; then
                            log_success "SSH 服务已重启"
                        else
                            log_error "SSH 服务重启失败，请检查服务名称和配置。"
                        fi
                    fi
                else
                    log_error "无效端口号！请输入 1024-65535 之间的数字"
                fi
                press_any_key
                ;;
            5)
                clear
                draw_title_line "定时任务管理" 50
                echo ""
                echo -e "  ${WHITE}${BOLD}当前用户的 Cron 任务${NC}"
                echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                crontab -l 2>/dev/null || echo "  暂无定时任务"
                echo ""
                draw_menu_item "1" "➕" "添加定时任务"
                draw_menu_item "2" "📝" "编辑定时任务"
                draw_menu_item "3" "🗑️" "清空所有任务"
                echo ""
                read -p "请选择操作 [1-3]: " cron_opt </dev/tty

                case $cron_opt in
                    1)
                        echo ""
                        echo -e "  ${WHITE}${BOLD}Cron 时间格式说明${NC}"
                        echo -e "  ${GRAY}分 时 日 月 周 命令${NC}"
                        echo -e "  ${DIM}示例: 0 2 * * * /path/to/script.sh (每天凌晨2点执行)${NC}"
                        echo ""
                        read -p "请输入 Cron 表达式 (如 0 2 * * *): " cron_expr </dev/tty
                        read -p "请输入要执行的命令: " cron_cmd </dev/tty
                        if [[ -n "$cron_expr" && -n "$cron_cmd" ]]; then
                            (crontab -l 2>/dev/null; echo "$cron_expr $cron_cmd") | crontab -
                            log_success "定时任务已添加"
                        fi
                        ;;
                    2)
                        crontab -e
                        ;;
                    3)
                        read -p "确认清空所有定时任务? (y/n): " confirm </dev/tty
                        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                            crontab -r 2>/dev/null || true
                            log_success "定时任务已清空"
                        fi
                        ;;
                esac
                press_any_key
                ;;
            6)
                clear
                draw_title_line "系统重启/关机" 50
                echo ""
                echo -e "  ${RED}${BOLD}⚠ 警告：此操作将中断所有服务！${NC}"
                echo ""
                echo -e "  ${CYAN}1.${NC} 立即重启"
                echo -e "  ${CYAN}2.${NC} 立即关机"
                echo -e "  ${CYAN}3.${NC} 定时重启 (分钟后)"
                echo ""
                read -p "请选择操作 [1-3]: " power_opt </dev/tty

                case $power_opt in
                    1)
                        read -p "确认立即重启? (y/n): " confirm </dev/tty
                        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                            log_warning "系统将在 5 秒后重启..."
                            sleep 5
                            sudo reboot
                        fi
                        ;;
                    2)
                        read -p "确认立即关机? (y/n): " confirm </dev/tty
                        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                            log_warning "系统将在 5 秒后关机..."
                            sleep 5
                            sudo poweroff
                        fi
                        ;;
                    3)
                        read -p "请输入分钟数: " minutes </dev/tty
                        if [[ "$minutes" =~ ^[0-9]+$ ]]; then
                            sudo shutdown -r +"$minutes" "System will reboot in $minutes minutes"
                            log_success "已设置 $minutes 分钟后重启"
                            echo -e "  ${DIM}取消命令: sudo shutdown -c${NC}"
                        fi
                        ;;
                esac
                press_any_key
                ;;
            7)
                clear
                draw_title_line "系统包一键更新" 50
                echo ""
                local pm=$(detect_pkg_manager)
                echo -e "  ${WHITE}${BOLD}包管理器: ${CYAN}${pm}${NC}"
                echo ""
                log_info "正在更新软件包索引..."
                pkg_update
                echo ""
                log_info "正在升级所有已安装的软件包..."
                case "$pm" in
                    apt) sudo apt-get upgrade -y ;;
                    dnf) sudo dnf upgrade -y ;;
                    yum) sudo yum update -y ;;
                    *) log_error "不支持的包管理器" ;;
                esac
                echo ""
                log_success "系统包更新完成！"
                press_any_key
                ;;
            8)
                clear
                draw_title_line "系统日志查看" 50
                echo ""
                echo -e "  ${WHITE}${BOLD}选择要查看的日志:${NC}"
                echo -e "  ${CYAN}1.${NC} 系统日志 (最近 50 条)"
                echo -e "  ${CYAN}2.${NC} 认证日志 (SSH 登录记录)"
                echo -e "  ${CYAN}3.${NC} 内核日志 (dmesg)"
                echo -e "  ${CYAN}4.${NC} 实时跟踪系统日志"
                echo -e "  ${CYAN}5.${NC} 按关键词搜索日志"
                echo ""
                read -p "请选择 [1-5]: " log_choice </dev/tty
                echo ""
                case $log_choice in
                    1)
                        echo -e "  ${WHITE}${BOLD}系统日志 (最近 50 条)${NC}"
                        echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                        sudo journalctl -n 50 --no-pager 2>/dev/null || \
                            sudo tail -50 /var/log/syslog 2>/dev/null || \
                            sudo tail -50 /var/log/messages 2>/dev/null || \
                            log_error "无法读取系统日志"
                        ;;
                    2)
                        echo -e "  ${WHITE}${BOLD}认证日志 (最近 30 条)${NC}"
                        echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                        sudo journalctl -u sshd -n 30 --no-pager 2>/dev/null || \
                            sudo tail -30 /var/log/auth.log 2>/dev/null || \
                            sudo tail -30 /var/log/secure 2>/dev/null || \
                            log_error "无法读取认证日志"
                        ;;
                    3)
                        echo -e "  ${WHITE}${BOLD}内核日志${NC}"
                        echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                        sudo dmesg --time-format iso 2>/dev/null | tail -30 || \
                            sudo dmesg | tail -30
                        ;;
                    4)
                        log_info "实时跟踪系统日志中... 按 Ctrl+C 退出"
                        echo ""
                        sudo journalctl -f --no-pager 2>/dev/null || \
                            sudo tail -f /var/log/syslog 2>/dev/null || \
                            sudo tail -f /var/log/messages 2>/dev/null || \
                            log_error "无法跟踪系统日志"
                        ;;
                    5)
                        read -p "请输入搜索关键词: " log_keyword </dev/tty
                        if [[ -n "$log_keyword" ]]; then
                            echo ""
                            echo -e "  ${WHITE}${BOLD}搜索结果: '${log_keyword}'${NC}"
                            echo -e "  ${GRAY}──────────────────────────────────────────${NC}"
                            sudo journalctl --no-pager -n 50 2>/dev/null | grep -i "$log_keyword" || \
                                echo "  未找到匹配的日志"
                        fi
                        ;;
                esac
                press_any_key
                ;;
            9)
                clear
                draw_title_line "流量统计 (vnstat)" 50
                echo ""

                if ! command -v vnstat &>/dev/null; then
                    echo -e "  ${GRAY}○${NC} vnstat 未安装"
                    echo ""
                    echo -e "  ${WHITE}${BOLD}vnstat 是一个轻量级流量监控工具${NC}"
                    echo -e "  ${DIM}安装后自动在后台统计网络流量，支持月度/日/小时报表${NC}"
                    echo ""
                    read -p "是否安装 vnstat? (y/n): " install_vnstat </dev/tty
                    if [[ "$install_vnstat" == "y" || "$install_vnstat" == "Y" ]]; then
                        pkg_update && pkg_install vnstat
                        sudo systemctl enable vnstat 2>/dev/null || true
                        sudo systemctl start vnstat 2>/dev/null || true
                        log_success "vnstat 已安装并启动！"
                        echo -e "  ${YELLOW}提示: 需要运行一段时间才会有统计数据${NC}"
                    fi
                    press_any_key
                    continue
                fi

                echo -e "  ${GREEN}✓${NC} vnstat 已安装"
                echo ""
                echo -e "  ${WHITE}${BOLD}选择查看方式:${NC}"
                echo -e "  ${CYAN}1.${NC} 总览 (默认)"
                echo -e "  ${CYAN}2.${NC} 按月统计"
                echo -e "  ${CYAN}3.${NC} 按天统计"
                echo -e "  ${CYAN}4.${NC} 按小时统计"
                echo -e "  ${CYAN}5.${NC} 实时流量"
                echo ""
                read -p "请选择 [1-5]: " vnstat_choice </dev/tty
                echo ""
                case $vnstat_choice in
                    1) vnstat ;;
                    2) vnstat -m ;;
                    3) vnstat -d ;;
                    4) vnstat -h ;;
                    5)
                        log_info "实时流量监控中... 按 Ctrl+C 退出"
                        echo ""
                        vnstat -l
                        ;;
                    *) vnstat ;;
                esac
                press_any_key
                ;;
            10)
                show_system_diagnostics
                ;;
            11)
                show_config_backup_menu
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
                    print_service_access_url "$oc_port" "http" "  地址:  "
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
        draw_menu_item "9" "🤖" "虾和马"
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
            9) show_ai_agent_menu ;;
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
main
