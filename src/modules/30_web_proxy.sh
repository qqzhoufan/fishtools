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
