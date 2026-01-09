#!/bin/bash
# =================================================================
# fish_ipcheck.sh - 咸鱼 IP 质量检测工具
# 作者: 咸鱼银河 (Xianyu Yinhe)
# 项目: https://github.com/qqzhoufan/fishtools
#
# 功能: IP信息检测、安全检测、流媒体解锁检测
# =================================================================

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

# --- 全局变量 ---
IPV4=""
IPV6=""
IP_INFO=""
UA_BROWSER="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# --- 工具函数 ---
print_logo() {
    echo -e "${CYAN}"
    echo "  ╔═══════════════════════════════════════════════════════╗"
    echo "  ║     🐟 Fish IP Check - 咸鱼 IP 质量检测工具          ║"
    echo "  ║          by 咸鱼银河 | fishtools v1.0                 ║"
    echo "  ╚═══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_section() {
    local title="$1"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}${BOLD}  $title${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

result_yes() {
    echo -e "${GREEN}✓ 解锁${NC} $1"
}

result_no() {
    echo -e "${RED}✗ 未解锁${NC} $1"
}

result_unknown() {
    echo -e "${YELLOW}? 未知${NC} $1"
}

result_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

# --- IP 信息检测 ---
get_ip_info() {
    print_section "📡 IP 信息检测"
    
    # 获取 IPv4
    echo -e "  ${GRAY}正在获取 IPv4 地址...${NC}"
    IPV4=$(curl -4 -s --max-time 5 ip.sb 2>/dev/null || curl -4 -s --max-time 5 ifconfig.me 2>/dev/null || echo "获取失败")
    
    # 获取 IPv6
    echo -e "  ${GRAY}正在获取 IPv6 地址...${NC}"
    IPV6=$(curl -6 -s --max-time 5 ip.sb 2>/dev/null || echo "无IPv6")
    
    # 获取详细 IP 信息
    echo -e "  ${GRAY}正在获取地理位置信息...${NC}"
    IP_INFO=$(curl -s --max-time 10 "http://ip-api.com/json/${IPV4}?fields=status,message,country,countryCode,region,regionName,city,zip,lat,lon,timezone,isp,org,as,asname,query" 2>/dev/null)
    
    echo ""
    
    # 显示 IP 地址
    echo -e "  ${CYAN}IPv4 地址${NC}     │ ${WHITE}${IPV4}${NC}"
    if [[ "$IPV6" != "无IPv6" && -n "$IPV6" ]]; then
        echo -e "  ${CYAN}IPv6 地址${NC}     │ ${WHITE}${IPV6}${NC}"
    else
        echo -e "  ${CYAN}IPv6 地址${NC}     │ ${GRAY}不支持${NC}"
    fi
    
    # 解析并显示详细信息
    if [[ -n "$IP_INFO" ]] && echo "$IP_INFO" | grep -q '"status":"success"'; then
        local country=$(echo "$IP_INFO" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
        local country_code=$(echo "$IP_INFO" | grep -o '"countryCode":"[^"]*"' | cut -d'"' -f4)
        local city=$(echo "$IP_INFO" | grep -o '"city":"[^"]*"' | cut -d'"' -f4)
        local region=$(echo "$IP_INFO" | grep -o '"regionName":"[^"]*"' | cut -d'"' -f4)
        local isp=$(echo "$IP_INFO" | grep -o '"isp":"[^"]*"' | cut -d'"' -f4)
        local org=$(echo "$IP_INFO" | grep -o '"org":"[^"]*"' | cut -d'"' -f4)
        local as_info=$(echo "$IP_INFO" | grep -o '"as":"[^"]*"' | cut -d'"' -f4)
        local timezone=$(echo "$IP_INFO" | grep -o '"timezone":"[^"]*"' | cut -d'"' -f4)
        
        echo -e "  ${CYAN}国家/地区${NC}     │ ${WHITE}${country} (${country_code})${NC}"
        echo -e "  ${CYAN}城市${NC}          │ ${WHITE}${city}, ${region}${NC}"
        echo -e "  ${CYAN}ISP 运营商${NC}    │ ${WHITE}${isp}${NC}"
        echo -e "  ${CYAN}组织${NC}          │ ${WHITE}${org}${NC}"
        echo -e "  ${CYAN}ASN${NC}           │ ${WHITE}${as_info}${NC}"
        echo -e "  ${CYAN}时区${NC}          │ ${WHITE}${timezone}${NC}"
    else
        echo -e "  ${RED}无法获取详细 IP 信息${NC}"
    fi
}

# --- 安全检测 ---
security_check() {
    print_section "🛡️ 安全检测"
    
    # DNS 服务器检测
    echo -e "  ${GRAY}正在检测 DNS 服务器...${NC}"
    local dns_ip=$(dig +short whoami.akamai.net @ns1-1.akamaitech.net 2>/dev/null | head -1)
    if [[ -n "$dns_ip" ]]; then
        echo -e "  ${CYAN}DNS 出口 IP${NC}   │ ${WHITE}${dns_ip}${NC}"
    else
        # 备用方法
        dns_ip=$(cat /etc/resolv.conf 2>/dev/null | grep nameserver | head -1 | awk '{print $2}')
        echo -e "  ${CYAN}DNS 服务器${NC}    │ ${WHITE}${dns_ip:-未知}${NC}"
    fi
    
    # IPv6 支持检测
    if [[ "$IPV6" != "无IPv6" && -n "$IPV6" ]]; then
        echo -e "  ${CYAN}IPv6 支持${NC}     │ ${GREEN}✓ 支持${NC}"
    else
        echo -e "  ${CYAN}IPv6 支持${NC}     │ ${RED}✗ 不支持${NC}"
    fi
    
    # 常用端口检测提示
    echo -e "  ${CYAN}端口状态${NC}      │ ${GRAY}(可通过外部工具检测)${NC}"
}

# --- 流媒体解锁检测函数 ---

check_netflix() {
    local result=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" \
        -H "User-Agent: ${UA_BROWSER}" \
        "https://www.netflix.com/title/80018499" 2>/dev/null)
    
    if [[ "$result" == "200" ]]; then
        # 进一步检测区域
        local region=$(curl -s --max-time 10 -H "User-Agent: ${UA_BROWSER}" \
            "https://www.netflix.com/title/80018499" 2>/dev/null | grep -o '"requestCountry":"[^"]*"' | cut -d'"' -f4)
        result_yes "Netflix ${region:+(${region})}"
    elif [[ "$result" == "403" ]]; then
        result_no "Netflix (仅自制剧)"
    else
        result_no "Netflix"
    fi
}

check_youtube_premium() {
    local result=$(curl -s --max-time 10 -H "User-Agent: ${UA_BROWSER}" \
        "https://www.youtube.com/premium" 2>/dev/null)
    
    if echo "$result" | grep -q "Premium is not available"; then
        result_no "YouTube Premium"
    elif echo "$result" | grep -qi "youtube premium"; then
        local region=$(echo "$result" | grep -o 'gl=[A-Z]*' | head -1 | cut -d'=' -f2)
        result_yes "YouTube Premium ${region:+(${region})}"
    else
        result_unknown "YouTube Premium"
    fi
}

check_disney_plus() {
    # 使用更可靠的检测方式
    local result=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" \
        -H "User-Agent: ${UA_BROWSER}" \
        "https://www.disneyplus.com" 2>/dev/null)
    
    if [[ "$result" == "200" || "$result" == "301" || "$result" == "302" ]]; then
        # 进一步检测是否被重定向到不可用页面
        local body=$(curl -s --max-time 10 -L -H "User-Agent: ${UA_BROWSER}" \
            "https://www.disneyplus.com" 2>/dev/null | head -500)
        if echo "$body" | grep -qi "not available\|unavailable\|geo-blocked"; then
            result_no "Disney+"
        else
            result_yes "Disney+"
        fi
    elif [[ "$result" == "403" || "$result" == "451" ]]; then
        result_no "Disney+"
    else
        result_no "Disney+ (无法访问)"
    fi
}

check_spotify() {
    local result=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" \
        -H "User-Agent: ${UA_BROWSER}" \
        "https://www.spotify.com/signup" 2>/dev/null)
    
    if [[ "$result" == "200" ]]; then
        result_yes "Spotify"
    else
        result_no "Spotify"
    fi
}

check_hbo_max() {
    # Max (前 HBO Max) 检测
    local result=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" \
        -H "User-Agent: ${UA_BROWSER}" \
        -L "https://www.max.com/" 2>/dev/null)
    
    if [[ "$result" == "200" ]]; then
        result_yes "HBO Max (Max)"
    elif [[ "$result" == "403" || "$result" == "451" ]]; then
        result_no "HBO Max (Max)"
    else
        # 备用检测
        local body=$(curl -s --max-time 10 -L -H "User-Agent: ${UA_BROWSER}" \
            "https://www.max.com/" 2>/dev/null | head -200)
        if echo "$body" | grep -qi "max\|hbo"; then
            result_yes "HBO Max (Max)"
        else
            result_no "HBO Max (Max)"
        fi
    fi
}

check_amazon_prime() {
    local result=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" \
        -H "User-Agent: ${UA_BROWSER}" \
        -L "https://www.primevideo.com" 2>/dev/null)
    
    if [[ "$result" == "200" ]]; then
        # 检测页面内容确认可用
        local body=$(curl -s --max-time 10 -L -H "User-Agent: ${UA_BROWSER}" \
            "https://www.primevideo.com" 2>/dev/null | head -500)
        if echo "$body" | grep -qi "unavailable\|not available in your\|geo-blocked"; then
            result_no "Amazon Prime Video"
        else
            result_yes "Amazon Prime Video"
        fi
    elif [[ "$result" == "403" || "$result" == "451" ]]; then
        result_no "Amazon Prime Video"
    else
        result_no "Amazon Prime Video (无法访问)"
    fi
}

check_bbc_iplayer() {
    local result=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" \
        -H "User-Agent: ${UA_BROWSER}" \
        "https://open.live.bbc.co.uk/mediaselector/6/select/version/2.0/mediaset/pc/vpid/bbc_one_london/format/json" 2>/dev/null)
    
    if [[ "$result" == "200" ]]; then
        result_yes "BBC iPlayer"
    else
        result_no "BBC iPlayer (仅限英国)"
    fi
}

check_tiktok() {
    local result=$(curl -s --max-time 10 -H "User-Agent: ${UA_BROWSER}" \
        "https://www.tiktok.com" 2>/dev/null)
    
    if echo "$result" | grep -qi "tiktok"; then
        # 尝试获取区域
        local region=$(echo "$result" | grep -o '"region":"[^"]*"' | head -1 | cut -d'"' -f4)
        result_yes "TikTok ${region:+(${region})}"
    else
        result_no "TikTok"
    fi
}

check_chatgpt() {
    local result=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" \
        -H "User-Agent: ${UA_BROWSER}" \
        "https://chat.openai.com/cdn-cgi/trace" 2>/dev/null)
    
    if [[ "$result" == "200" ]]; then
        local trace=$(curl -s --max-time 10 "https://chat.openai.com/cdn-cgi/trace" 2>/dev/null)
        local loc=$(echo "$trace" | grep "loc=" | cut -d'=' -f2)
        result_yes "ChatGPT ${loc:+(${loc})}"
    else
        result_no "ChatGPT"
    fi
}

check_bilibili() {
    # 检测港澳台番剧
    local result=$(curl -s --max-time 10 \
        -H "User-Agent: ${UA_BROWSER}" \
        "https://api.bilibili.com/pgc/player/web/playurl?avid=18281381&cid=29892777&qn=0&fnval=16" 2>/dev/null)
    
    if echo "$result" | grep -q '"code":0'; then
        result_yes "Bilibili 港澳台"
    else
        result_no "Bilibili 港澳台"
    fi
    
    # 检测大陆
    local result_cn=$(curl -s --max-time 10 \
        -H "User-Agent: ${UA_BROWSER}" \
        "https://api.bilibili.com/pgc/player/web/playurl?avid=82846771&cid=141736925&qn=0&fnval=16" 2>/dev/null)
    
    if echo "$result_cn" | grep -q '"code":0'; then
        result_yes "Bilibili 大陆"
    else
        result_no "Bilibili 大陆"
    fi
}

check_steam() {
    # 检测 Steam 商店可用性
    local http_code=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" \
        -H "User-Agent: ${UA_BROWSER}" \
        "https://store.steampowered.com/" 2>/dev/null)
    
    if [[ "$http_code" == "200" ]]; then
        # 获取货币信息（过滤null字节）
        local page=$(curl -s --max-time 10 -H "User-Agent: ${UA_BROWSER}" \
            "https://store.steampowered.com/" 2>/dev/null | tr -d '\0' | head -200)
        local currency=$(echo "$page" | grep -o '"wallet_currency":[0-9]*' | head -1 | cut -d':' -f2)
        
        # 货币代码映射
        local currency_name=""
        case "$currency" in
            1) currency_name="USD" ;;
            2) currency_name="GBP" ;;
            3) currency_name="EUR" ;;
            5) currency_name="RUB" ;;
            7) currency_name="BRL" ;;
            8) currency_name="JPY" ;;
            9) currency_name="NOK" ;;
            20) currency_name="CAD" ;;
            21) currency_name="AUD" ;;
            23) currency_name="CNY" ;;
            28) currency_name="TWD" ;;
            29) currency_name="KRW" ;;
            30) currency_name="UAH" ;;
            31) currency_name="MXN" ;;
            34) currency_name="TRY" ;;
            37) currency_name="HKD" ;;
            *) currency_name="" ;;
        esac
        
        result_yes "Steam 商店 ${currency_name:+(${currency_name})}"
    elif [[ "$http_code" == "403" ]]; then
        result_no "Steam 商店 (被屏蔽)"
    else
        result_no "Steam 商店 (无法访问)"
    fi
}

check_google() {
    local result=$(curl -s --max-time 10 -H "User-Agent: ${UA_BROWSER}" \
        "https://www.google.com/search?q=test" 2>/dev/null | head -100)
    
    if echo "$result" | grep -qi "google"; then
        result_yes "Google 搜索"
    else
        result_no "Google 搜索"
    fi
}

check_gemini() {
    local http_code=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" \
        -H "User-Agent: ${UA_BROWSER}" \
        "https://gemini.google.com/" 2>/dev/null)
    
    if [[ "$http_code" == "200" ]]; then
        result_yes "Google Gemini"
    elif [[ "$http_code" == "403" || "$http_code" == "451" ]]; then
        result_no "Google Gemini (地区限制)"
    elif [[ "$http_code" == "302" || "$http_code" == "301" ]]; then
        # 检测重定向后的页面
        local final_code=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" \
            -L -H "User-Agent: ${UA_BROWSER}" \
            "https://gemini.google.com/" 2>/dev/null)
        if [[ "$final_code" == "200" ]]; then
            result_yes "Google Gemini"
        else
            result_no "Google Gemini"
        fi
    else
        result_no "Google Gemini (无法访问)"
    fi
}

check_wikipedia() {
    local result=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" \
        -H "User-Agent: ${UA_BROWSER}" \
        "https://www.wikipedia.org" 2>/dev/null)
    
    if [[ "$result" == "200" ]]; then
        result_yes "Wikipedia"
    else
        result_no "Wikipedia"
    fi
}

check_twitch() {
    local result=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" \
        -H "User-Agent: ${UA_BROWSER}" \
        "https://www.twitch.tv" 2>/dev/null)
    
    if [[ "$result" == "200" ]]; then
        result_yes "Twitch"
    else
        result_no "Twitch"
    fi
}

check_dazn() {
    local result=$(curl -s --max-time 10 \
        -H "User-Agent: ${UA_BROWSER}" \
        "https://startup.core.indazn.com/misl/v5/Startup" 2>/dev/null)
    
    if echo "$result" | grep -qi "region"; then
        result_yes "DAZN"
    else
        result_no "DAZN"
    fi
}

# --- 流媒体检测主函数 ---
streaming_check() {
    print_section "📺 流媒体解锁检测"
    echo ""
    
    echo -e "  ${WHITE}${BOLD}【视频平台】${NC}"
    echo -n "  " && check_netflix
    echo -n "  " && check_youtube_premium
    echo -n "  " && check_disney_plus
    echo -n "  " && check_hbo_max
    echo -n "  " && check_amazon_prime
    echo -n "  " && check_bbc_iplayer
    echo -n "  " && check_twitch
    echo -n "  " && check_dazn
    
    echo ""
    echo -e "  ${WHITE}${BOLD}【音乐平台】${NC}"
    echo -n "  " && check_spotify
    
    echo ""
    echo -e "  ${WHITE}${BOLD}【社交/AI 平台】${NC}"
    echo -n "  " && check_tiktok
    echo -n "  " && check_chatgpt
    echo -n "  " && check_google
    echo -n "  " && check_gemini
    echo -n "  " && check_wikipedia
    
    echo ""
    echo -e "  ${WHITE}${BOLD}【中国区服务】${NC}"
    check_bilibili
    
    echo ""
    echo -e "  ${WHITE}${BOLD}【游戏平台】${NC}"
    echo -n "  " && check_steam
}

# --- 主函数 ---
main() {
    clear
    print_logo
    
    echo -e "${GRAY}  检测开始时间: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${GRAY}  系统信息: $(uname -sr)${NC}"
    
    get_ip_info
    security_check
    streaming_check
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}${BOLD}  检测完成！${NC}"
    echo -e "${GRAY}  完成时间: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# 运行
main
