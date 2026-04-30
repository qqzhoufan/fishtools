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
