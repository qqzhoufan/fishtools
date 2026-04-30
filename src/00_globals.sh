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
