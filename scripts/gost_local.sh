#!/bin/bash
# =================================================================
# Gost 本地配置管理脚本
# 用于在本机上直接配置 Gost 服务
# =================================================================

# 本地配置文件路径
LOCAL_GOST_CONFIG="/etc/gost/config.json"
GOST_SERVICE_FILE="/etc/systemd/system/gost.service"

# 确保配置目录存在
ensure_local_config_dir() {
    sudo mkdir -p /etc/gost
    sudo chmod 755 /etc/gost
}

# 初始化本地配置文件
init_local_config() {
    if [[ ! -f "$LOCAL_GOST_CONFIG" ]]; then
        sudo tee "$LOCAL_GOST_CONFIG" > /dev/null <<'EOF'
{
  "mode": "none",
  "target": null,
  "relay": {
    "forwards": []
  }
}
EOF
        sudo chmod 600 "$LOCAL_GOST_CONFIG"
    fi
}

# 加载本地配置
load_local_config() {
    ensure_local_config_dir
    init_local_config
    sudo cat "$LOCAL_GOST_CONFIG"
}

# 保存本地配置
save_local_config() {
    local config_json="$1"
    echo "$config_json" | sudo tee "$LOCAL_GOST_CONFIG" > /dev/null
    sudo chmod 600 "$LOCAL_GOST_CONFIG"
}

# 检查 gost 是否已安装
check_gost_installed() {
    command -v gost &> /dev/null
}

# 安装 gost
install_gost_binary() {
    if check_gost_installed; then
        return 0
    fi
    
    echo "正在安装 gost..."
    local temp_dir=$(mktemp -d)
    cd "$temp_dir" || return 1
    
    wget -q https://github.com/ginuerzh/gost/releases/download/v2.11.5/gost-linux-amd64-2.11.5.gz
    if [[ $? -ne 0 ]]; then
        echo "下载失败"
        rm -rf "$temp_dir"
        return 1
    fi
    
    gunzip gost-linux-amd64-2.11.5.gz
    sudo mv gost-linux-amd64-2.11.5 /usr/local/bin/gost
    sudo chmod +x /usr/local/bin/gost
    
    rm -rf "$temp_dir"
    
    if check_gost_installed; then
        echo "gost 安装成功"
        return 0
    else
        echo "gost 安装失败"
        return 1
    fi
}

# 配置本机为落地鸡
configure_as_target() {
    local tls_port="$1"
    local forward_target="$2"
    
    local config=$(load_local_config)
    
    # 更新配置
    config=$(echo "$config" | jq ".mode = \"target\" | .target = {\"tls_port\": $tls_port, \"forward_target\": \"$forward_target\"}")
    
    save_local_config "$config"
}

# 添加线路鸡转发规则（追加模式）
add_relay_forward() {
    local name="$1"
    local target_ip="$2"
    local target_port="$3"
    local listen_port="$4"
    
    local config=$(load_local_config)
    
    # 设置模式为 relay
    config=$(echo "$config" | jq '.mode = "relay"')
    
    # 检查是否已存在相同的监听端口
    local existing=$(echo "$config" | jq -r ".relay.forwards[] | select(.listen_port == $listen_port) | .listen_port")
    if [[ -n "$existing" ]]; then
        echo "错误：端口 $listen_port 已被使用"
        return 1
    fi
    
    # 追加新的转发规则
    local new_forward=$(cat <<EOF
{
  "name": "$name",
  "target_ip": "$target_ip",
  "target_port": $target_port,
  "listen_port": $listen_port
}
EOF
)
    
    config=$(echo "$config" | jq ".relay.forwards += [$new_forward]")
    
    save_local_config "$config"
    return 0
}

# 删除线路鸡转发规则
remove_relay_forward() {
    local listen_port="$1"
    
    local config=$(load_local_config)
    config=$(echo "$config" | jq "del(.relay.forwards[] | select(.listen_port == $listen_port))")
    
    save_local_config "$config"
}

# 获取下一个可用的监听端口
get_next_listen_port() {
    local config=$(load_local_config)
    local max_port=$(echo "$config" | jq -r '.relay.forwards[].listen_port' | sort -n | tail -1)
    
    if [[ -z "$max_port" || "$max_port" == "null" ]]; then
        echo "10001"
    else
        echo $((max_port + 1))
    fi
}

# 生成 gost 启动命令
generate_gost_command() {
    local config=$(load_local_config)
    local mode=$(echo "$config" | jq -r '.mode')
    
    if [[ "$mode" == "target" ]]; then
        # 落地鸡模式
        local tls_port=$(echo "$config" | jq -r '.target.tls_port')
        local forward_target=$(echo "$config" | jq -r '.target.forward_target')
        echo "/usr/local/bin/gost -L=relay+tls://:${tls_port}/:${forward_target}"
        
    elif [[ "$mode" == "relay" ]]; then
        # 线路鸡模式 - 生成多个 -L 和 -F 参数
        local cmd="/usr/local/bin/gost"
        local forwards=$(echo "$config" | jq -c '.relay.forwards[]')
        
        echo "$forwards" | while read -r forward; do
            local listen_port=$(echo "$forward" | jq -r '.listen_port')
            local target_ip=$(echo "$forward" | jq -r '.target_ip')
            local target_port=$(echo "$forward" | jq -r '.target_port')
            cmd="$cmd -L=:${listen_port} -F=relay+tls://${target_ip}:${target_port}"
        done
        
        echo "$cmd"
    else
        echo ""
        return 1
    fi
}

# 生成 systemd 服务文件
generate_systemd_service() {
    local gost_cmd=$(generate_gost_command)
    
    if [[ -z "$gost_cmd" ]]; then
        echo "错误：无法生成 gost 命令"
        return 1
    fi
    
    sudo tee "$GOST_SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Gost Tunnel Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=$gost_cmd
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    
    sudo chmod 644 "$GOST_SERVICE_FILE"
    return 0
}

# 启动 gost 服务
start_gost_service() {
    # 生成 systemd 服务文件
    if ! generate_systemd_service; then
        return 1
    fi
    
    # 重载 systemd
    sudo systemctl daemon-reload
    
    # 启动服务
    sudo systemctl restart gost
    
    # 设置开机自启
    sudo systemctl enable gost
    
    return 0
}

# 停止 gost 服务
stop_gost_service() {
    sudo systemctl stop gost
    sudo systemctl disable gost
}

# 查看 gost 服务状态
get_gost_service_status() {
    if sudo systemctl is-active --quiet gost; then
        echo "running"
    else
        echo "stopped"
    fi
}

# 获取本机配置摘要
get_local_config_summary() {
    local config=$(load_local_config)
    local mode=$(echo "$config" | jq -r '.mode')
    
    if [[ "$mode" == "target" ]]; then
        local tls_port=$(echo "$config" | jq -r '.target.tls_port')
        local forward_target=$(echo "$config" | jq -r '.target.forward_target')
        echo "模式: 落地鸡"
        echo "TLS 端口: $tls_port"
        echo "转发目标: $forward_target"
        
    elif [[ "$mode" == "relay" ]]; then
        echo "模式: 线路鸡"
        local count=$(echo "$config" | jq '.relay.forwards | length')
        echo "转发规则数: $count"
        
        echo "$config" | jq -r '.relay.forwards[] | "  [\(.listen_port)] → \(.name) (\(.target_ip):\(.target_port))"'
    else
        echo "模式: 未配置"
    fi
}
