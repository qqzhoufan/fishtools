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
    echo -e "  ${CYAN}${BOLD}${num}.${NC} ${icon}  ${WHITE}${text}${NC}"
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
