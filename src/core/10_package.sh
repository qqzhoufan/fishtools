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
