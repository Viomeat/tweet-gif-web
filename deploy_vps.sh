#!/bin/bash

# Tweet GIF Web VPS 部署脚本
# 用于从本地或 CI 产物部署到远程 VPS

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

show_logo() {
    cat << "EOF"
╔════════════════════════════════════════════╗
║                                            ║
║     Tweet GIF Web VPS 部署脚本             ║
║                                            ║
╚════════════════════════════════════════════╝
EOF
    echo
}

# 配置变量
VPS_HOST=""
VPS_USER=""
VPS_PORT="22"
BINARY_PATH=""
SERVICE_PORT="8080"

# 读取配置
read_config() {
    log_info "配置部署参数..."
    echo
    
    read -p "VPS IP 地址或域名: " VPS_HOST
    read -p "SSH 用户名 [root]: " VPS_USER
    VPS_USER=${VPS_USER:-root}
    
    read -p "SSH 端口 [22]: " VPS_PORT
    VPS_PORT=${VPS_PORT:-22}
    
    read -p "服务运行端口 [8080]: " SERVICE_PORT
    SERVICE_PORT=${SERVICE_PORT:-8080}
    
    echo
    log_info "配置完成"
    log_info "VPS: ${VPS_USER}@${VPS_HOST}:${VPS_PORT}"
}

# 检查本地二进制文件
check_binary() {
    log_info "检查二进制文件..."
    
    # 优先级：指定路径 > 当前目录 > GitHub Actions 下载
    if [ -n "$1" ]; then
        BINARY_PATH="$1"
    elif [ -f "tweet-gif-web" ]; then
        BINARY_PATH="tweet-gif-web"
    elif [ -f "tweet-gif-web-linux-amd64" ]; then
        BINARY_PATH="tweet-gif-web-linux-amd64"
    else
        log_error "未找到二进制文件"
        log_info "请执行以下操作之一："
        log_info "  1. 从 GitHub Actions 下载构建产物"
        log_info "  2. 本地构建: ./build.sh"
        log_info "  3. 指定文件路径: $0 /path/to/binary"
        exit 1
    fi
    
    if [ ! -f "$BINARY_PATH" ]; then
        log_error "文件不存在: $BINARY_PATH"
        exit 1
    fi
    
    log_success "找到二进制文件: $BINARY_PATH"
}

# 测试 SSH 连接
test_ssh() {
    log_info "测试 SSH 连接..."
    
    if ssh -p "$VPS_PORT" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$VPS_USER@$VPS_HOST" "echo SSH连接成功" > /dev/null 2>&1; then
        log_success "SSH 连接测试通过"
    else
        log_error "SSH 连接失败，请检查："
        log_error "  1. VPS 地址和端口是否正确"
        log_error "  2. SSH 密钥是否配置正确"
        log_error "  3. 防火墙是否开放 SSH 端口"
        exit 1
    fi
}

# 安装依赖
install_dependencies() {
    log_info "在 VPS 上安装依赖..."
    
    ssh -p "$VPS_PORT" "$VPS_USER@$VPS_HOST" bash << 'ENDSSH'
        # 检测系统类型
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$ID
        else
            echo "无法检测系统类型"
            exit 1
        fi
        
        # 安装 ffmpeg
        if ! command -v ffmpeg &> /dev/null; then
            echo "正在安装 ffmpeg..."
            case "$OS" in
                ubuntu|debian)
                    sudo apt update
                    sudo apt install -y ffmpeg
                    ;;
                centos|rhel|fedora)
                    sudo yum install -y epel-release
                    sudo yum install -y ffmpeg
                    ;;
                *)
                    echo "不支持的系统: $OS"
                    exit 1
                    ;;
            esac
        else
            echo "ffmpeg 已安装"
        fi
        
        # 验证 ffmpeg
        ffmpeg -version | head -n 1
ENDSSH
    
    log_success "依赖安装完成"
}

# 创建服务用户和目录
setup_directories() {
    log_info "创建服务用户和目录..."
    
    ssh -p "$VPS_PORT" "$VPS_USER@$VPS_HOST" bash << 'ENDSSH'
        # 创建服务用户
        if ! id "tweetgif" &>/dev/null; then
            sudo useradd -r -s /bin/false tweetgif
            echo "创建服务用户: tweetgif"
        fi
        
        # 创建目录
        sudo mkdir -p /opt/tweet-gif-web
        sudo mkdir -p /var/lib/tweet-gif-web/tmp
        sudo mkdir -p /var/log/tweet-gif-web
        
        # 设置权限
        sudo chown -R tweetgif:tweetgif /opt/tweet-gif-web
        sudo chown -R tweetgif:tweetgif /var/lib/tweet-gif-web
        sudo chown -R tweetgif:tweetgif /var/log/tweet-gif-web
        
        echo "目录创建完成"
ENDSSH
    
    log_success "目录设置完成"
}

# 上传二进制文件
upload_binary() {
    log_info "上传二进制文件..."
    
    # 停止服务
    ssh -p "$VPS_PORT" "$VPS_USER@$VPS_HOST" "sudo systemctl stop tweet-gif-web 2>/dev/null || true"
    
    # 备份旧文件
    ssh -p "$VPS_PORT" "$VPS_USER@$VPS_HOST" bash << 'ENDSSH'
        if [ -f /opt/tweet-gif-web/tweet-gif-web ]; then
            sudo cp /opt/tweet-gif-web/tweet-gif-web /opt/tweet-gif-web/tweet-gif-web.backup.$(date +%Y%m%d_%H%M%S)
            echo "已备份旧版本"
        fi
ENDSSH
    
    # 上传新文件
    scp -P "$VPS_PORT" "$BINARY_PATH" "$VPS_USER@$VPS_HOST:/tmp/tweet-gif-web"
    
    # 移动到目标位置
    ssh -p "$VPS_PORT" "$VPS_USER@$VPS_HOST" bash << 'ENDSSH'
        sudo mv /tmp/tweet-gif-web /opt/tweet-gif-web/tweet-gif-web
        sudo chmod +x /opt/tweet-gif-web/tweet-gif-web
        sudo chown tweetgif:tweetgif /opt/tweet-gif-web/tweet-gif-web
        echo "二进制文件安装完成"
ENDSSH
    
    log_success "二进制文件上传完成"
}

# 创建 systemd 服务
create_service() {
    log_info "创建 systemd 服务..."
    
    # 生成服务文件内容
    cat > /tmp/tweet-gif-web.service << EOF
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
Environment="PORT=${SERVICE_PORT}"
Environment="FFMPEG_PATH=/usr/bin/ffmpeg"
Environment="TEMP_DIR=/var/lib/tweet-gif-web/tmp"
Environment="GIF_FPS=12"
Environment="GIF_WIDTH=480"
Environment="MAX_CONCURRENT=2"
Environment="FILE_TTL_MINUTES=30"
Environment="MAX_MP4_SIZE_MB=50"

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
    
    # 上传服务文件
    scp -P "$VPS_PORT" /tmp/tweet-gif-web.service "$VPS_USER@$VPS_HOST:/tmp/tweet-gif-web.service"
    rm /tmp/tweet-gif-web.service
    
    # 安装服务
    ssh -p "$VPS_PORT" "$VPS_USER@$VPS_HOST" bash << 'ENDSSH'
        sudo mv /tmp/tweet-gif-web.service /etc/systemd/system/tweet-gif-web.service
        sudo systemctl daemon-reload
        sudo systemctl enable tweet-gif-web
        echo "systemd 服务已创建"
ENDSSH
    
    log_success "systemd 服务创建完成"
}

# 配置防火墙
setup_firewall() {
    log_info "配置防火墙..."
    
    ssh -p "$VPS_PORT" "$VPS_USER@$VPS_HOST" bash << ENDSSH
        if command -v ufw &> /dev/null; then
            sudo ufw allow ${SERVICE_PORT}/tcp
            echo "UFW 规则已添加: ${SERVICE_PORT}/tcp"
        elif command -v firewall-cmd &> /dev/null; then
            sudo firewall-cmd --permanent --add-port=${SERVICE_PORT}/tcp
            sudo firewall-cmd --reload
            echo "firewalld 规则已添加: ${SERVICE_PORT}/tcp"
        else
            echo "未检测到防火墙"
        fi
ENDSSH
    
    log_success "防火墙配置完成"
}

# 启动服务
start_service() {
    log_info "启动服务..."
    
    ssh -p "$VPS_PORT" "$VPS_USER@$VPS_HOST" bash << 'ENDSSH'
        sudo systemctl start tweet-gif-web
        sleep 2
        
        if sudo systemctl is-active --quiet tweet-gif-web; then
            echo "服务启动成功"
            sudo systemctl status tweet-gif-web --no-pager
        else
            echo "服务启动失败"
            sudo journalctl -u tweet-gif-web -n 20 --no-pager
            exit 1
        fi
ENDSSH
    
    log_success "服务启动成功"
}

# 健康检查
health_check() {
    log_info "执行健康检查..."
    
    sleep 3
    
    if curl -f -m 10 "http://${VPS_HOST}:${SERVICE_PORT}/" > /dev/null 2>&1; then
        log_success "健康检查通过！服务运行正常"
        return 0
    else
        log_warning "健康检查失败，服务可能仍在启动或端口未开放"
        return 1
    fi
}

# 显示部署信息
show_deployment_info() {
    echo
    echo "╔════════════════════════════════════════════╗"
    echo "║                                            ║"
    echo "║           部署完成！                       ║"
    echo "║                                            ║"
    echo "╚════════════════════════════════════════════╝"
    echo
    log_success "访问地址: http://${VPS_HOST}:${SERVICE_PORT}"
    echo
    log_info "常用命令（在 VPS 上执行）:"
    echo "  启动服务: sudo systemctl start tweet-gif-web"
    echo "  停止服务: sudo systemctl stop tweet-gif-web"
    echo "  重启服务: sudo systemctl restart tweet-gif-web"
    echo "  查看状态: sudo systemctl status tweet-gif-web"
    echo "  查看日志: sudo journalctl -u tweet-gif-web -f"
    echo
    log_info "通过 SSH 连接到 VPS:"
    echo "  ssh -p ${VPS_PORT} ${VPS_USER}@${VPS_HOST}"
    echo
}

# 主函数
main() {
    show_logo
    
    # 检查参数
    check_binary "$1"
    
    # 配置
    read_config
    
    # 测试连接
    test_ssh
    
    # 执行部署
    install_dependencies
    setup_directories
    upload_binary
    create_service
    setup_firewall
    start_service
    
    # 健康检查
    if ! health_check; then
        log_warning "请手动检查服务状态"
    fi
    
    # 显示信息
    show_deployment_info
}

# 运行
main "$@"
