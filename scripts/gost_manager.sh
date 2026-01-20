#!/bin/bash
# =================================================================
# Gost 隧道节点管理脚本
# 用于管理线路鸡（中转节点）和落地鸡（目标节点）的配置
# =================================================================

# 配置文件路径
GOST_CONFIG_FILE="/opt/fishtools/gost_config.json"
GOST_DEPLOY_DIR="/opt/gost_deploy"

# 确保配置目录存在
ensure_config_dir() {
    mkdir -p "$(dirname "$GOST_CONFIG_FILE")"
    mkdir -p "$GOST_DEPLOY_DIR"
}

# 初始化配置文件
init_config_file() {
    if [[ ! -f "$GOST_CONFIG_FILE" ]]; then
        cat > "$GOST_CONFIG_FILE" <<'EOF'
{
  "version": "1.0",
  "relay_nodes": [],
  "target_nodes": []
}
EOF
        echo "配置文件已初始化: $GOST_CONFIG_FILE"
    fi
}

# 加载配置文件
load_gost_config() {
    ensure_config_dir
    init_config_file
    cat "$GOST_CONFIG_FILE"
}

# 保存配置文件
save_gost_config() {
    local config_json="$1"
    echo "$config_json" | jq '.' > "$GOST_CONFIG_FILE" 2>/dev/null || {
        echo "$config_json" > "$GOST_CONFIG_FILE"
    }
}

# 生成唯一ID
generate_id() {
    local prefix="$1"
    echo "${prefix}-$(date +%s)-$$"
}

# 获取所有线路鸡节点
get_relay_nodes() {
    load_gost_config | jq -r '.relay_nodes[]' 2>/dev/null || echo "[]"
}

# 获取所有落地鸡节点
get_target_nodes() {
    load_gost_config | jq -r '.target_nodes[]' 2>/dev/null || echo "[]"
}

# 添加线路鸡节点
add_relay_node() {
    local name="$1"
    local ip="$2"
    
    local id=$(generate_id "relay")
    local config=$(load_gost_config)
    
    local new_node=$(cat <<EOF
{
  "id": "$id",
  "name": "$name",
  "ip": "$ip",
  "targets": []
}
EOF
)
    
    config=$(echo "$config" | jq ".relay_nodes += [$new_node]")
    save_gost_config "$config"
    echo "$id"
}

# 添加落地鸡节点
add_target_node() {
    local name="$1"
    local ip="$2"
    local tls_port="$3"
    local forward_target="$4"
    
    local id=$(generate_id "target")
    local config=$(load_gost_config)
    
    local new_node=$(cat <<EOF
{
  "id": "$id",
  "name": "$name",
  "ip": "$ip",
  "tls_port": $tls_port,
  "forward_target": "$forward_target"
}
EOF
)
    
    config=$(echo "$config" | jq ".target_nodes += [$new_node]")
    save_gost_config "$config"
    echo "$id"
}

# 删除线路鸡节点
delete_relay_node() {
    local id="$1"
    local config=$(load_gost_config)
    config=$(echo "$config" | jq "del(.relay_nodes[] | select(.id == \"$id\"))")
    save_gost_config "$config"
}

# 删除落地鸡节点
delete_target_node() {
    local id="$1"
    local config=$(load_gost_config)
    
    # 删除节点
    config=$(echo "$config" | jq "del(.target_nodes[] | select(.id == \"$id\"))")
    
    # 从所有线路鸡的 targets 数组中移除该 ID
    config=$(echo "$config" | jq ".relay_nodes[].targets |= map(select(. != \"$id\"))")
    
    save_gost_config "$config"
}

# 添加节点关联
link_relay_to_target() {
    local relay_id="$1"
    local target_id="$2"
    local config=$(load_gost_config)
    
    # 检查是否已存在关联
    local already_linked=$(echo "$config" | jq -r ".relay_nodes[] | select(.id == \"$relay_id\") | .targets[] | select(. == \"$target_id\")" 2>/dev/null)
    
    if [[ -n "$already_linked" ]]; then
        echo "关联已存在"
        return 1
    fi
    
    # 添加关联
    config=$(echo "$config" | jq "(.relay_nodes[] | select(.id == \"$relay_id\") | .targets) += [\"$target_id\"]")
    save_gost_config "$config"
    return 0
}

# 删除节点关联
unlink_relay_from_target() {
    local relay_id="$1"
    local target_id="$2"
    local config=$(load_gost_config)
    
    config=$(echo "$config" | jq "(.relay_nodes[] | select(.id == \"$relay_id\") | .targets) |= map(select(. != \"$target_id\"))")
    save_gost_config "$config"
}

# 获取线路鸡的关联目标列表
get_relay_targets() {
    local relay_id="$1"
    load_gost_config | jq -r ".relay_nodes[] | select(.id == \"$relay_id\") | .targets[]" 2>/dev/null
}

# 根据 ID 获取节点信息
get_node_by_id() {
    local node_id="$1"
    local node_type="$2"  # relay 或 target
    
    if [[ "$node_type" == "relay" ]]; then
        load_gost_config | jq -r ".relay_nodes[] | select(.id == \"$node_id\")"
    else
        load_gost_config | jq -r ".target_nodes[] | select(.id == \"$node_id\")"
    fi
}

# 为落地鸡生成 gost 配置脚本
generate_target_gost_script() {
    local target_id="$1"
    local config=$(load_gost_config)
    local target_node=$(echo "$config" | jq -r ".target_nodes[] | select(.id == \"$target_id\")")
    
    if [[ -z "$target_node" || "$target_node" == "null" ]]; then
        echo "错误：找不到落地鸡节点 $target_id"
        return 1
    fi
    
    local target_name=$(echo "$target_node" | jq -r '.name')
    local tls_port=$(echo "$target_node" | jq -r '.tls_port')
    local forward_target=$(echo "$target_node" | jq -r '.forward_target')
    local script_file="${GOST_DEPLOY_DIR}/gost_target_${target_id}.sh"
    
    # 创建落地鸡脚本
    cat > "$script_file" <<EOF
#!/bin/bash
# Gost 落地鸡配置
# 节点: $target_name ($target_id)
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

echo "======================================"
echo "  Gost 落地鸡启动脚本"
echo "  节点: $target_name"
echo "  TLS 监听端口: $tls_port"
echo "  转发目标: $forward_target"
echo "======================================"
echo ""

# 检查 gost 是否安装
if ! command -v gost &> /dev/null; then
    echo "错误: gost 未安装"
    echo "请先安装 gost:"
    echo "  wget https://github.com/ginuerzh/gost/releases/download/v2.11.5/gost-linux-amd64-2.11.5.gz"
    echo "  gunzip gost-linux-amd64-2.11.5.gz"
    echo "  mv gost-linux-amd64-2.11.5 /usr/local/bin/gost"
    echo "  chmod +x /usr/local/bin/gost"
    exit 1
fi

echo "启动 gost 服务..."
echo "监听端口: $tls_port (TLS 加密)"
echo "转发到: $forward_target"
echo ""

# 启动 gost（TLS 监听模式）
gost -L=relay+tls://:$tls_port/:$forward_target

EOF
    
    chmod +x "$script_file"
    echo "$script_file"
}

# 为线路鸡生成完整的 gost 配置脚本
generate_relay_gost_script() {
    local relay_id="$1"
    local config=$(load_gost_config)
    local relay_node=$(echo "$config" | jq -r ".relay_nodes[] | select(.id == \"$relay_id\")")
    
    if [[ -z "$relay_node" || "$relay_node" == "null" ]]; then
        echo "错误：找不到线路鸡节点 $relay_id"
        return 1
    fi
    
    local relay_name=$(echo "$relay_node" | jq -r '.name')
    local script_file="${GOST_DEPLOY_DIR}/gost_relay_${relay_id}.sh"
    
    # 创建脚本头
    cat > "$script_file" <<EOF
#!/bin/bash
# Gost 线路鸡转发配置
# 节点: $relay_name ($relay_id)
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

echo "======================================"
echo "  Gost 线路鸡启动脚本"
echo "  节点: $relay_name"
echo "======================================"
echo ""

# 检查 gost 是否安装
if ! command -v gost &> /dev/null; then
    echo "错误: gost 未安装"
    echo "请先安装 gost:"
    echo "  wget https://github.com/ginuerzh/gost/releases/download/v2.11.5/gost-linux-amd64-2.11.5.gz"
    echo "  gunzip gost-linux-amd64-2.11.5.gz"
    echo "  mv gost-linux-amd64-2.11.5 /usr/local/bin/gost"
    echo "  chmod +x /usr/local/bin/gost"
    exit 1
fi

echo "配置的转发规则:"
echo ""

EOF
    
    # 获取关联的目标节点
    local targets=$(echo "$relay_node" | jq -r '.targets[]' 2>/dev/null)
    
    if [[ -z "$targets" ]]; then
        echo "# 暂无配置的转发目标" >> "$script_file"
        echo "echo '暂无配置的转发目标'" >> "$script_file"
        chmod +x "$script_file"
        echo "$script_file"
        return 0
    fi
    
    # 为每个目标生成转发命令
    local port_counter=10001
    echo "$targets" | while read -r target_id; do
        local target_node=$(echo "$config" | jq -r ".target_nodes[] | select(.id == \"$target_id\")")
        
        if [[ -n "$target_node" && "$target_node" != "null" ]]; then
            local target_name=$(echo "$target_node" | jq -r '.name')
            local target_ip=$(echo "$target_node" | jq -r '.ip')
            local target_tls_port=$(echo "$target_node" | jq -r '.tls_port')
            
            echo "echo '  [$port_counter] → $target_name ($target_ip:$target_tls_port)'" >> "$script_file"
            
            port_counter=$((port_counter + 1))
        fi
    done
    
    echo "" >> "$script_file"
    echo "echo ''" >> "$script_file"
    echo "echo '启动 gost 转发服务...'" >> "$script_file"
    echo "echo ''" >> "$script_file"
    echo "" >> "$script_file"
    
    # 重新生成转发命令（实际执行）
    port_counter=10001
    echo "$targets" | while read -r target_id; do
        local target_node=$(echo "$config" | jq -r ".target_nodes[] | select(.id == \"$target_id\")")
        
        if [[ -n "$target_node" && "$target_node" != "null" ]]; then
            local target_name=$(echo "$target_node" | jq -r '.name')
            local target_ip=$(echo "$target_node" | jq -r '.ip')
            local target_tls_port=$(echo "$target_node" | jq -r '.tls_port')
            
            echo "# 转发到: $target_name ($target_id)" >> "$script_file"
            echo "gost -L=:$port_counter -F=relay+tls://$target_ip:$target_tls_port &" >> "$script_file"
            echo "" >> "$script_file"
            
            port_counter=$((port_counter + 1))
        fi
    done
    
    # 添加等待命令
    echo "wait" >> "$script_file"
    
    chmod +x "$script_file"
    echo "$script_file"
}

# 生成所有落地鸡的脚本
generate_all_target_scripts() {
    local config=$(load_gost_config)
    local generated=0
    
    echo "$config" | jq -c '.target_nodes[]' | while read -r target; do
        local tid=$(echo "$target" | jq -r '.id')
        local tname=$(echo "$target" | jq -r '.name')
        
        local script_file=$(generate_target_gost_script "$tid")
        
        if [[ $? -eq 0 && -f "$script_file" ]]; then
            echo "  ${GREEN}✓${NC} 已生成落地鸡脚本: ${script_file}"
            generated=$((generated + 1))
        else
            echo "  ${RED}✗${NC} 生成失败: $tname"
        fi
    done
    
    return 0
}

# 统计信息
count_relay_nodes() {
    load_gost_config | jq '.relay_nodes | length'
}

count_target_nodes() {
    load_gost_config | jq '.target_nodes | length'
}

# 检查 jq 是否安装
check_jq() {
    if ! command -v jq &> /dev/null; then
        echo "错误：需要安装 jq 工具"
        echo "请运行: sudo apt-get install -y jq"
        return 1
    fi
    return 0
}

# 主函数：初始化
init_gost_manager() {
    check_jq || return 1
    ensure_config_dir
    init_config_file
}
