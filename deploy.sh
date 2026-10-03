#!/bin/bash

# Tweet GIF Web 一键部署脚本
# 类似 Openlist 风格的自动化部署

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示 Logo
show_logo() {
    cat << "EOF"
╔════════════════════════════════════════════╗
║                                            ║
║        Tweet GIF Web 一键部署脚本          ║
║                                            ║
║        将推文视频转换为 GIF 的 Web 服务    ║
║                                            ║
╚════════════════════════════════════════════╝
EOF
    echo
}

# 检查是否为 root 用户
check_root() {
    if [ "$EUID" -eq 0 ]; then
        log_warning "检测到您正在使用 root 用户运行脚本"
        read -p "是否继续？(y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# 检测系统类型
detect_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        log_error "无法检测系统类型"
        exit 1
    fi
    
    log_info "检测到系统: $OS $VER"
}

# 安装依赖
install_dependencies() {
    log_info "正在安装系统依赖..."
    
    case "$OS" in
        ubuntu|debian)
            sudo apt update
            sudo apt install -y curl wget git ffmpeg
            ;;
        centos|rhel|fedora)
            sudo yum install -y epel-release
            sudo yum install -y curl wget git ffmpeg
            ;;
        *)
            log_error "不支持的系统类型: $OS"
            exit 1
            ;;
    esac
    
    log_success "系统依赖安装完成"
}

# 检查 ffmpeg
check_ffmpeg() {
    if command -v ffmpeg &> /dev/null; then
        log_success "ffmpeg 已安装: $(ffmpeg -version | head -n 1)"
    else
        log_error "ffmpeg 未安装，请先安装 ffmpeg"
        exit 1
    fi
}

# 下载或构建二进制文件
get_binary() {
    log_info "获取二进制文件..."
    
    read -p "选择获取方式: (1) 从 GitHub Release 下载 (2) 从 GitHub Actions 下载 (3) 本地构建: " choice
    
    case $choice in
        1)
            download_from_github
            ;;
        2)
            download_from_actions
            ;;
        3)
            build_from_source
            ;;
        *)
            log_error "无效的选择"
            exit 1
            ;;
    esac
}

# 从 GitHub Actions 下载
download_from_actions() {
    log_info "从 GitHub Actions 下载最新构建..."
    
    # 检测架构
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        *)
            log_error "不支持的架构: $ARCH"
            exit 1
            ;;
    esac
    
    BINARY_NAME="tweet-gif-web-linux-${ARCH}"
    
    log_info "请手动从 GitHub Actions 下载 ${BINARY_NAME}"
    log_info "访问: https://github.com/YOUR_USERNAME/tweet-gif-web/actions"
    log_info "找到最新的成功构建，下载对应的 artifact"
    echo
    
    read -p "请输入下载的二进制文件路径: " BINARY_PATH
    
    if [ ! -f "$BINARY_PATH" ]; then
        log_error "文件不存在: $BINARY_PATH"
        exit 1
    fi
    
    cp "$BINARY_PATH" tweet-gif-web
    chmod +x tweet-gif-web
    log_success "文件复制完成"
}

# 从 GitHub 下载
download_from_github() {
    log_info "从 GitHub 下载最新版本..."
    
    # 检测架构
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        *)
            log_error "不支持的架构: $ARCH"
            exit 1
            ;;
    esac
    
    BINARY_NAME="tweet-gif-web-linux-${ARCH}"
    
    # 获取最新版本
    LATEST_VERSION=$(curl -s https://api.github.com/repos/YOUR_USERNAME/tweet-gif-web/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$LATEST_VERSION" ]; then
        log_error "无法获取最新版本，请检查网络或手动构建"
        exit 1
    fi
    
    log_info "最新版本: $LATEST_VERSION"
    
    DOWNLOAD_URL="https://github.com/YOUR_USERNAME/tweet-gif-web/releases/download/${LATEST_VERSION}/${BINARY_NAME}"
    
    log_info "下载地址: $DOWNLOAD_URL"
    
    wget -O tweet-gif-web "$DOWNLOAD_URL" || {
        log_error "下载失败"
        exit 1
    }
    
    chmod +x tweet-gif-web
    log_success "下载完成"
}

# 从源码构建
build_from_source() {
    log_info "从源码构建..."
    
    # 检查 Go
    if ! command -v go &> /dev/null; then
        log_info "Go 未安装，正在安装 Go..."
        install_go
    fi
    
    # 检查 JDK
    if ! command -v java &> /dev/null; then
        log_info "JDK 未安装，正在安装 JDK..."
        install_jdk
    fi
    
    # 克隆仓库（如果不在项目目录中）
    if [ ! -f "go.mod" ]; then
        log_info "克隆仓库..."
        git clone https://github.com/YOUR_USERNAME/tweet-gif-web.git
        cd tweet-gif-web
    fi
    
    # 构建前端
    log_info "构建前端..."
    cd frontend
    ./gradlew wasmJsBrowserDistribution --no-daemon
    cd ..
    
    # 构建后端
    log_info "构建后端..."
    CGO_ENABLED=0 go build -ldflags="-s -w" -o tweet-gif-web .
    
    log_success "构建完成"
}

# 安装 Go
install_go() {
    GO_VERSION="1.22.0"
    ARCH=$(uname -m)
    
    case "$ARCH" in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
    esac
    
    log_info "下载 Go ${GO_VERSION}..."
    wget -q https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz
    
    log_info "安装 Go..."
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go${GO_VERSION}.linux-${ARCH}.tar.gz
    
    export PATH=$PATH:/usr/local/go/bin
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    
    rm go${GO_VERSION}.linux-${ARCH}.tar.gz
    
    log_success "Go 安装完成: $(go version)"
}

# 安装 JDK
install_jdk() {
    log_info "安装 JDK 17..."
    
    case "$OS" in
        ubuntu|debian)
            sudo apt install -y openjdk-17-jdk
            ;;
        centos|rhel|fedora)
            sudo yum install -y java-17-openjdk-devel
            ;;
    esac
    
    log_success "JDK 安装完成: $(java -version 2>&1 | head -n 1)"
}

# 配置服务
setup_service() {
    log_info "配置 systemd 服务..."
    
    # 创建服务用户
    if ! id "tweetgif" &>/dev/null; then
        sudo useradd -r -s /bin/false tweetgif
        log_success "创建服务用户: tweetgif"
    fi
    
    # 创建目录
    sudo mkdir -p /opt/tweet-gif-web
    sudo mkdir -p /var/lib/tweet-gif-web/tmp
    sudo mkdir -p /var/log/tweet-gif-web
    
    # 复制二进制文件
    sudo cp tweet-gif-web /opt/tweet-gif-web/
    sudo chmod +x /opt/tweet-gif-web/tweet-gif-web
    
    # 设置权限
    sudo chown -R tweetgif:tweetgif /opt/tweet-gif-web
    sudo chown -R tweetgif:tweetgif /var/lib/tweet-gif-web
    sudo chown -R tweetgif:tweetgif /var/log/tweet-gif-web
    
    # 创建 systemd 服务文件
    sudo tee /etc/systemd/system/tweet-gif-web.service > /dev/null <<EOF
[Unit]
Description=Tweet GIF Web Service
After=network.target

[Service]
Type=simple
User=tweetgif
Group=tweetgif
WorkingDirectory=/opt/tweet-gif-web
ExecStart=/opt/tweet-gif-web/tweet-gif-web
Restart=on-failure
RestartSec=5s

# 环境变量
Environment="PORT=${PORT:-8080}"
Environment="FFMPEG_PATH=${FFMPEG_PATH:-/usr/bin/ffmpeg}"
Environment="TEMP_DIR=/var/lib/tweet-gif-web/tmp"
Environment="GIF_FPS=${GIF_FPS:-12}"
Environment="GIF_WIDTH=${GIF_WIDTH:-480}"
Environment="MAX_CONCURRENT=${MAX_CONCURRENT:-2}"
Environment="FILE_TTL_MINUTES=${FILE_TTL_MINUTES:-30}"
Environment="MAX_MP4_SIZE_MB=${MAX_MP4_SIZE_MB:-50}"

# 安全设置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/tweet-gif-web /var/log/tweet-gif-web

# 资源限制
LimitNOFILE=65536
LimitNPROC=512

# 日志
StandardOutput=append:/var/log/tweet-gif-web/access.log
StandardError=append:/var/log/tweet-gif-web/error.log

[Install]
WantedBy=multi-user.target
EOF
    
    log_success "systemd 服务配置完成"
}

# 配置参数
configure_service() {
    log_info "配置服务参数..."
    echo
    
    read -p "监听端口 [8080]: " PORT
    PORT=${PORT:-8080}
    
    read -p "GIF 帧率 [12]: " GIF_FPS
    GIF_FPS=${GIF_FPS:-12}
    
    read -p "GIF 宽度 [480]: " GIF_WIDTH
    GIF_WIDTH=${GIF_WIDTH:-480}
    
    read -p "最大并发数 [2]: " MAX_CONCURRENT
    MAX_CONCURRENT=${MAX_CONCURRENT:-2}
    
    read -p "文件保留时长(分钟) [30]: " FILE_TTL_MINUTES
    FILE_TTL_MINUTES=${FILE_TTL_MINUTES:-30}
    
    read -p "最大文件大小(MB) [50]: " MAX_MP4_SIZE_MB
    MAX_MP4_SIZE_MB=${MAX_MP4_SIZE_MB:-50}
    
    read -p "HTTP 代理 (留空不使用): " HTTP_PROXY
    
    export PORT GIF_FPS GIF_WIDTH MAX_CONCURRENT FILE_TTL_MINUTES MAX_MP4_SIZE_MB HTTP_PROXY
    
    log_success "配置完成"
}

# 配置防火墙
setup_firewall() {
    log_info "配置防火墙..."
    
    if command -v ufw &> /dev/null; then
        sudo ufw allow ${PORT}/tcp
        log_success "UFW 规则已添加: ${PORT}/tcp"
    elif command -v firewall-cmd &> /dev/null; then
        sudo firewall-cmd --permanent --add-port=${PORT}/tcp
        sudo firewall-cmd --reload
        log_success "firewalld 规则已添加: ${PORT}/tcp"
    else
        log_warning "未检测到防火墙，请手动配置"
    fi
}

# 启动服务
start_service() {
    log_info "启动服务..."
    
    sudo systemctl daemon-reload
    sudo systemctl enable tweet-gif-web
    sudo systemctl start tweet-gif-web
    
    sleep 2
    
    if sudo systemctl is-active --quiet tweet-gif-web; then
        log_success "服务启动成功！"
        
        # 显示服务状态
        echo
        sudo systemctl status tweet-gif-web --no-pager
    else
        log_error "服务启动失败"
        log_info "查看日志: sudo journalctl -u tweet-gif-web -n 50"
        exit 1
    fi
}

# 健康检查
health_check() {
    log_info "执行健康检查..."
    
    sleep 3
    
    if curl -f http://localhost:${PORT}/ > /dev/null 2>&1; then
        log_success "健康检查通过！服务运行正常"
    else
        log_warning "健康检查失败，但服务可能仍在启动中"
    fi
}

# 显示部署信息
show_info() {
    local IP=$(curl -s ifconfig.me || echo "YOUR_SERVER_IP")
    
    echo
    echo "╔════════════════════════════════════════════╗"
    echo "║                                            ║"
    echo "║           部署完成！                       ║"
    echo "║                                            ║"
    echo "╚════════════════════════════════════════════╝"
    echo
    log_success "访问地址: http://${IP}:${PORT}"
    echo
    log_info "常用命令:"
    echo "  启动服务: sudo systemctl start tweet-gif-web"
    echo "  停止服务: sudo systemctl stop tweet-gif-web"
    echo "  重启服务: sudo systemctl restart tweet-gif-web"
    echo "  查看状态: sudo systemctl status tweet-gif-web"
    echo "  查看日志: sudo journalctl -u tweet-gif-web -f"
    echo "  访问日志: sudo tail -f /var/log/tweet-gif-web/access.log"
    echo "  错误日志: sudo tail -f /var/log/tweet-gif-web/error.log"
    echo
    log_info "配置信息:"
    echo "  端口: ${PORT}"
    echo "  GIF 帧率: ${GIF_FPS}"
    echo "  GIF 宽度: ${GIF_WIDTH}"
    echo "  最大并发: ${MAX_CONCURRENT}"
    echo "  文件保留: ${FILE_TTL_MINUTES} 分钟"
    echo "  最大文件: ${MAX_MP4_SIZE_MB} MB"
    echo
    log_info "下一步建议:"
    echo "  1. 配置 Nginx 反向代理"
    echo "  2. 配置 SSL 证书 (Let's Encrypt)"
    echo "  3. 配置域名解析"
    echo "  4. 设置监控和告警"
    echo
}

# 主函数
main() {
    show_logo
    check_root
    detect_system
    install_dependencies
    check_ffmpeg
    get_binary
    configure_service
    setup_service
    setup_firewall
    start_service
    health_check
    show_info
}

# 运行主函数
main
