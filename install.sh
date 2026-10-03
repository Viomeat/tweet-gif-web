#!/usr/bin/env bash
#
# tweet-gif-web 一键安装 / 升级脚本 (Linux)
#
# 用法:
#   curl -fsSL https://github.com/Viomeat/tweet-gif-web/releases/latest/download/install.sh -o install.sh && sudo bash install.sh
#
# 常用参数:
#   --version v1.2.3   安装指定版本（默认 latest）
#   --port 8080        服务监听端口（默认 8080）
#   --arch arm64       强制指定 CPU 架构（默认自动检测）
#   --no-start         只安装不启动服务
#   --uninstall        卸载服务与文件
#   --help             显示帮助
#
# 安装完成后，在服务器上输入 `tweetgif` 即可打开交互式管理面板，
# 管理面板提供安装/更新/卸载/服务管理/配置管理等全部操作。
#
# 环境变量:
#   REPO=owner/name        指定仓库（默认 Viomeat/tweet-gif-web）
#   GITHUB_TOKEN=xxx       私有仓库或触发 API 限流时使用
#   INSTALL_DIR=...        安装目录（默认 /opt/tweet-gif-web）
#

set -Eeuo pipefail

REPO="${REPO:-Viomeat/tweet-gif-web}"
# 可选：自建 OpenList 镜像加速（不设置 OPENLIST_BASE 则只用 GitHub）
OPENLIST_BASE="${OPENLIST_BASE:-}"
OPENLIST_DIR="${OPENLIST_DIR-}"
OPENLIST_USER="${OPENLIST_USER:-}"
OPENLIST_PASS="${OPENLIST_PASS:-}"
DL_UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
SERVICE_NAME="tweet-gif-web"
SERVICE_USER="tweetgif"
INSTALL_DIR="${INSTALL_DIR:-/opt/tweet-gif-web}"
DATA_DIR="/var/lib/${SERVICE_NAME}"
LOG_DIR="/var/log/${SERVICE_NAME}"
CONFIG_DIR="/etc/${SERVICE_NAME}"
ENV_FILE="${CONFIG_DIR}/tweet-gif-web.env"
MANAGER_BIN="/usr/local/bin/tweetgif"
MANAGER_LINK="/usr/local/bin/tweetgif-manager"
PORT="${PORT:-8080}"
TMP_DIR=""
ARCH_OVERRIDE=""
VERSION="${VERSION:-latest}"
DO_START=1
DO_UNINSTALL=0

# ---------------------------------------------------------------- 输出工具
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\033[0m'; C_RED=$'\033[0;31m'; C_GREEN=$'\033[0;32m'
  C_YELLOW=$'\033[1;33m'; C_BLUE=$'\033[0;34m'
else
  C_RESET=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""
fi

log()   { printf '%s[信息]%s %s\n' "$C_BLUE"   "$C_RESET" "$*"; }
ok()    { printf '%s[完成]%s %s\n' "$C_GREEN"  "$C_RESET" "$*"; }
warn()  { printf '%s[注意]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die()   { printf '%s[错误]%s %s\n' "$C_RED"    "$C_RESET" "$*" >&2; exit 1; }

trap 'die "脚本在第 ${LINENO} 行执行失败"' ERR

usage() {
  cat <<'USAGE'
tweet-gif-web 一键安装 / 升级脚本 (Linux)

用法:
  curl -fsSL https://github.com/Viomeat/tweet-gif-web/releases/latest/download/install.sh -o install.sh && sudo bash install.sh
  curl -fsSL .../install.sh -o install.sh && sudo bash install.sh --version v1.0.1 --port 8080

安装完成后，输入 tweetgif 即可打开管理面板（安装 / 更新 / 卸载 /
服务管理 / 配置管理等），等价于 OpenList 的面板管理命令。

参数:
  --version v1.2.3   安装指定版本（默认 latest）
  --port 8080        服务监听端口（默认 8080）
  --arch arm64       强制指定 CPU 架构（默认自动检测 amd64/arm64）
  --repo owner/name  指定 GitHub 仓库（默认 Viomeat/tweet-gif-web）
  --no-start         只安装不启动服务
  --uninstall        卸载服务与文件
  --help, -h         显示帮助

环境变量:
  REPO=owner/name        同 --repo
  GITHUB_TOKEN=xxx       私有仓库或触发 API 限流时使用
  PORT=8080              服务端口
  INSTALL_DIR=...        安装目录（默认 /opt/tweet-gif-web）
  OPENLIST_BASE=...      自建 OpenList 镜像地址（可选，不设置则只用 GitHub）
  OPENLIST_DIR=...       镜像内文件所在目录（配合 OPENLIST_BASE 使用）
  OPENLIST_USER=...      镜像账号（配合 OPENLIST_BASE 使用）
  OPENLIST_PASS=...      OpenList 密码（默认为空）
  DL_SOURCE=github       强制仅使用 GitHub 下载源
USAGE
  exit 0
}

need_root() {
  if [ "$(id -u)" -ne 0 ]; then
    die "请使用 root 运行，例如: sudo bash install.sh"
  fi
}

# ---------------------------------------------------------------- 参数解析
parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --version)    VERSION="${2:?--version 需要参数}"; shift 2 ;;
      --port)       PORT="${2:?--port 需要参数}"; shift 2 ;;
      --arch)       ARCH_OVERRIDE="${2:?--arch 需要参数}"; shift 2 ;;
      --repo)       REPO="${2:?--repo 需要参数}"; shift 2 ;;
      --no-start)   DO_START=0; shift ;;
      --uninstall)  DO_UNINSTALL=1; shift ;;
      --help|-h)    usage ;;
      *) die "未知参数: $1（使用 --help 查看用法）" ;;
    esac
  done
  case "$PORT" in
    ''|*[!0-9]*) die "端口必须是数字: $PORT" ;;
  esac
  [ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ] || die "端口超出范围: $PORT"
  case "$VERSION" in
    latest|v[0-9]*) ;;
    *) die "无效版本: $VERSION（应为 latest 或 vX.Y.Z）" ;;
  esac
}

# ---------------------------------------------------------------- 系统检测
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"
}

detect_os() {
  # 注意：不要 source /etc/os-release —— 它会覆盖脚本自身的变量（如 VERSION）
  OS_ID="unknown"
  OS_LIKE=""
  if [ -r /etc/os-release ]; then
    OS_ID="$(sed -n 's/^ID=//p' /etc/os-release | head -n1 | tr -d '"')"
    OS_LIKE="$(sed -n 's/^ID_LIKE=//p' /etc/os-release | head -n1 | tr -d '"')"
  fi
}

install_packages() {
  detect_os
  if command -v apt-get >/dev/null 2>&1; then
    log "使用 apt 安装依赖 (ffmpeg curl ca-certificates tar)"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends ffmpeg curl ca-certificates tar >/dev/null
  elif command -v dnf >/dev/null 2>&1; then
    log "使用 dnf 安装依赖"
    dnf install -y -q ffmpeg curl ca-certificates tar
  elif command -v yum >/dev/null 2>&1; then
    log "使用 yum 安装依赖"
    case " $OS_ID $OS_LIKE " in
      *rhel*|*centos*) yum install -y -q epel-release || true ;;
    esac
    yum install -y -q ffmpeg curl ca-certificates tar
  elif command -v apk >/dev/null 2>&1; then
    log "使用 apk 安装依赖"
    apk add --no-cache ffmpeg curl ca-certificates tar
  elif command -v pacman >/dev/null 2>&1; then
    log "使用 pacman 安装依赖"
    pacman -Sy --noconfirm ffmpeg curl ca-certificates tar
  else
    die "无法识别的包管理器，请手动安装 ffmpeg 后重试"
  fi
  require_cmd tar
  require_cmd curl
  command -v ffmpeg >/dev/null 2>&1 || die "ffmpeg 安装失败，请手动安装后重试"
  ok "依赖已就绪: $(ffmpeg -version 2>/dev/null | head -n1)"
}

detect_arch() {
  if [ -n "$ARCH_OVERRIDE" ]; then
    ARCH="$ARCH_OVERRIDE"
  else
    local machine
    machine="$(uname -m)"
    case "$machine" in
      x86_64|amd64)   ARCH="amd64" ;;
      aarch64|arm64)  ARCH="arm64" ;;
      *) die "不支持的 CPU 架构: $machine（可用 --arch 手动指定）" ;;
    esac
  fi
  case "$ARCH" in
    amd64|arm64) ;;
    *) die "不支持的架构: $ARCH（仅支持 amd64 / arm64）" ;;
  esac
  log "CPU 架构: ${ARCH}"
}

# ---------------------------------------------------------------- 下载
# 下载链：OpenList WebDAV → OpenList /d 直链 → OpenList API(raw_url) → GitHub 直连
# 环境变量: OPENLIST_BASE / OPENLIST_DIR / OPENLIST_USER / OPENLIST_PASS /
#           REPO / GITHUB_TOKEN / DL_SOURCE=github(强制仅用 GitHub)

openlist_latest_ver() {
  # 列出 OpenList 根目录下的 vX.Y.Z 版本目录，取最高版本（结果进程内缓存）
  if [ -z "${OPENLIST_VER_CACHE}" ]; then
    OPENLIST_VER_CACHE="$(curl -fsS -m 20 -A "$DL_UA" \
        -u "${OPENLIST_USER}:${OPENLIST_PASS}" \
        -X PROPFIND -H "Depth: 1" "${OPENLIST_BASE}/dav/" 2>/dev/null \
      | grep -oE '<[A-Za-z]*:displayname>v[0-9][0-9.]*</[A-Za-z]*:displayname>' \
      | sed -E 's/.*>(v[0-9][0-9.]*)<.*/\1/' \
      | sort -uV | tail -n1 || true)"
  fi
  printf '%s' "${OPENLIST_VER_CACHE}"
}

openlist_paths() {  # $1=文件名 -> 依次输出候选相对路径
  local ver=""
  if [ "$VERSION" != "latest" ]; then
    ver="${VERSION}"
  else
    ver="$(openlist_latest_ver)"
  fi
  if [ -n "$ver" ]; then printf '%s/%s\n' "$ver" "$1"; fi
  if [ -n "${OPENLIST_DIR}" ]; then printf '%s/%s\n' "${OPENLIST_DIR}" "$1"; fi
  printf '%s\n' "$1"
  return 0
}

dl_openlist_webdav() {  # $1=文件名 $2=目标
  local p
  while IFS= read -r p; do
    if curl -fsSL --retry 2 --retry-delay 2 --connect-timeout 20 -A "$DL_UA" \
         -u "${OPENLIST_USER}:${OPENLIST_PASS}" \
         -o "$2" "${OPENLIST_BASE}/dav/${p}" && [ -s "$2" ]; then
      return 0
    fi
    rm -f "$2"
  done < <(openlist_paths "$1")
  return 1
}

openlist_login() {
  curl -fsS -m 20 -A "$DL_UA" -X POST "${OPENLIST_BASE}/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${OPENLIST_USER}\",\"password\":\"${OPENLIST_PASS}\",\"otp_code\":\"\"}" \
    | sed -n 's/.*"token":"\([^"]*\)".*/\1/p'
}

openlist_raw_url() {  # $1=相对路径 $2=token
  curl -fsS -m 20 -A "$DL_UA" -X POST "${OPENLIST_BASE}/api/fs/get" \
    -H "Content-Type: application/json" -H "Authorization: $2" \
    -d "{\"path\":\"/$1\",\"password\":\"\"}" \
    | sed -n 's/.*"raw_url":"\([^"]*\)".*/\1/p'
}

dl_openlist_direct() {  # $1=文件名 $2=目标
  local p
  while IFS= read -r p; do
    if curl -fsSL --retry 2 --retry-delay 2 --connect-timeout 20 -A "$DL_UA" \
         -o "$2" "${OPENLIST_BASE}/d/${p}" && [ -s "$2" ]; then
      return 0
    fi
    rm -f "$2"
  done < <(openlist_paths "$1")
  return 1
}

dl_openlist_api() {  # $1=文件名 $2=目标
  local token raw_url p
  token="$(openlist_login)" || return 1
  [ -n "$token" ] || return 1
  while IFS= read -r p; do
    raw_url="$(openlist_raw_url "$p" "$token")" || continue
    [ -n "$raw_url" ] || continue
    log "通过 OpenList 中转下载..."
    if curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 20 -A "$DL_UA" \
         -o "$2" "$raw_url" && [ -s "$2" ]; then
      return 0
    fi
    rm -f "$2"
  done < <(openlist_paths "$1")
  return 1
}

dl_github() {  # $1=文件名 $2=目标
  local url
  if [ "$VERSION" = "latest" ]; then
    url="https://github.com/${REPO}/releases/latest/download/$1"
  else
    url="https://github.com/${REPO}/releases/download/${VERSION}/$1"
  fi
  local dargs=(-fsSL --retry 3 --retry-delay 2 --connect-timeout 20 -o "$2" "$url")
  [ -n "${GITHUB_TOKEN:-}" ] && dargs+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
  curl "${dargs[@]}"
}

download_file() {  # $1=文件名 $2=目标
  rm -f "$2"
  if [ -z "${OPENLIST_BASE}" ] || [ "${DL_SOURCE:-}" = "github" ]; then
    if [ "${DL_SOURCE:-}" = "github" ]; then
      log "使用 GitHub 下载源（DL_SOURCE=github）"
    fi
    if dl_github "$1" "$2" && [ -s "$2" ]; then
      ok "GitHub 下载成功"
      return 0
    fi
    return 1
  fi
  log "下载源 1/4: OpenList WebDAV"
  if dl_openlist_webdav "$1" "$2" && [ -s "$2" ]; then
    ok "OpenList WebDAV 下载成功"
    return 0
  fi
  log "下载源 2/4: OpenList 直链 (${OPENLIST_BASE})"
  if dl_openlist_direct "$1" "$2" && [ -s "$2" ]; then
    ok "OpenList 直链下载成功"
    return 0
  fi
  warn "OpenList 直链不可用，尝试 OpenList API 模式..."
  if dl_openlist_api "$1" "$2" && [ -s "$2" ]; then
    ok "OpenList API 下载成功"
    return 0
  fi
  warn "OpenList 不可用，回退到 GitHub 直连..."
  if dl_github "$1" "$2" && [ -s "$2" ]; then
    ok "GitHub 下载成功"
    return 0
  fi
  warn "全部下载源失败。私有仓库请设置 GITHUB_TOKEN，或在 OpenList 的 GitHub 存储器中开启 Web 代理并刷新缓存"
  return 1
}

download_and_install() {
  local asset="tweet-gif-web-linux-${ARCH}.tar.gz"
  if [ "$VERSION" != "latest" ]; then
    # OpenList 镜像始终提供最新版资产，指定历史版本时直接走 GitHub
    log "指定版本 ${VERSION}，直接使用 GitHub 下载源"
    TMP_DIR="$(mktemp -d)"
    dl_github "${asset}" "${TMP_DIR}/${asset}" || die "下载失败: ${asset}"
  else
    TMP_DIR="$(mktemp -d)"
    download_file "$asset" "${TMP_DIR}/${asset}" || die "下载失败: ${asset}"
  fi

  log "校验文件完整性"
  if download_file "${asset}.sha256" "${TMP_DIR}/${asset}.sha256" 2>/dev/null; then
    ( cd "$TMP_DIR" && sha256sum -c "${asset}.sha256" >/dev/null 2>&1 ) \
      || die "sha256 校验失败，文件可能被篡改或损坏"
    ok "sha256 校验通过"
  else
    warn "无法获取 sha256 校验文件，跳过校验"
  fi

  tar -xzf "${TMP_DIR}/${asset}" -C "$TMP_DIR"
  [ -f "${TMP_DIR}/tweet-gif-web" ] || die "压缩包内缺少 tweet-gif-web 可执行文件"
  chmod 0755 "${TMP_DIR}/tweet-gif-web"

  install -d -m 0755 "$INSTALL_DIR"
  if [ -x "${INSTALL_DIR}/tweet-gif-web" ]; then
    cp -f "${INSTALL_DIR}/tweet-gif-web" "${INSTALL_DIR}/tweet-gif-web.bak" || true
  fi
  install -m 0755 "${TMP_DIR}/tweet-gif-web" "${INSTALL_DIR}/tweet-gif-web"
  ok "二进制已安装到 ${INSTALL_DIR}/tweet-gif-web"
}

# ---------------------------------------------------------------- 服务配置
setup_user_and_dirs() {
  if ! id -u "$SERVICE_USER" >/dev/null 2>&1; then
    if command -v useradd >/dev/null 2>&1; then
      useradd --system --no-create-home --shell /usr/sbin/nologin "$SERVICE_USER" 2>/dev/null \
        || useradd --system --no-create-home --shell /sbin/nologin "$SERVICE_USER"
    elif command -v adduser >/dev/null 2>&1; then
      adduser -S -D -H -s /sbin/nologin "$SERVICE_USER"
    else
      warn "无法创建系统用户，将使用 root 运行服务"
      SERVICE_USER="root"
    fi
  fi

  install -d -m 0755 "$DATA_DIR/tmp" "$LOG_DIR" "$CONFIG_DIR"
  if [ "$SERVICE_USER" != "root" ]; then
    chown -R "${SERVICE_USER}:${SERVICE_USER}" "$DATA_DIR" "$LOG_DIR" "$INSTALL_DIR" 2>/dev/null || true
  fi
  printf '%s\n' "$SERVICE_USER" > "${CONFIG_DIR}/install-user"
  chmod 0644 "${CONFIG_DIR}/install-user"
}

write_env_file() {
  if [ -f "${CONFIG_DIR}/tweet-gif-web.env" ] && [ "$DO_UNINSTALL" -eq 0 ] && [ "${KEEP_CONFIG:-1}" = "1" ]; then
    log "保留已有配置: ${CONFIG_DIR}/tweet-gif-web.env"
    return
  fi
  cat > "${CONFIG_DIR}/tweet-gif-web.env" <<EOF
# tweet-gif-web 运行配置（由安装脚本生成）
PORT=${PORT}
FFMPEG_PATH=$(command -v ffmpeg || echo /usr/bin/ffmpeg)
TEMP_DIR=${DATA_DIR}/tmp
GIF_FPS=12
GIF_WIDTH=480
MAX_CONCURRENT=2
FILE_TTL_MINUTES=30
MAX_MP4_SIZE_MB=50
EOF
  chmod 0644 "${CONFIG_DIR}/tweet-gif-web.env"
  ok "配置已写入 ${CONFIG_DIR}/tweet-gif-web.env"
}

write_systemd_unit() {
  [ -d /run/systemd/system ] || die "当前系统未使用 systemd，请手动运行 ${INSTALL_DIR}/tweet-gif-web"
  cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<UNIT
[Unit]
Description=tweet-gif-web (Twitter/X video -> GIF web service)
Documentation=https://github.com/${REPO}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_USER}
WorkingDirectory=${INSTALL_DIR}
EnvironmentFile=${CONFIG_DIR}/tweet-gif-web.env
ExecStart=${INSTALL_DIR}/tweet-gif-web
Restart=always
RestartSec=5

NoNewPrivileges=true
ProtectSystem=full
ProtectHome=true
ReadWritePaths=${DATA_DIR} ${INSTALL_DIR}

StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}

LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
UNIT
  ok "systemd 服务已写入 /etc/systemd/system/${SERVICE_NAME}.service"
}

start_service() {
  systemctl daemon-reload
  systemctl enable "${SERVICE_NAME}" >/dev/null 2>&1 || true
  systemctl restart "${SERVICE_NAME}"
  sleep 2
  if systemctl is-active --quiet "${SERVICE_NAME}"; then
    ok "服务已启动 (端口 ${PORT})"
  else
    warn "服务启动失败，最近日志："
    journalctl -u "${SERVICE_NAME}" -n 30 --no-pager || true
    die "请根据日志排查后重试"
  fi
}

configure_firewall() {
  if command -v ufw >/dev/null 2>&1; then
    ufw allow "${PORT}/tcp" >/dev/null 2>&1 || true
  elif command -v firewall-cmd >/dev/null 2>&1; then
    firewall-cmd --permanent --add-port="${PORT}/tcp" >/dev/null 2>&1 || true
    firewall-cmd --reload >/dev/null 2>&1 || true
  fi
}

health_check() {
  local url="http://127.0.0.1:${PORT}/healthz"
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if curl -fsS -m 5 -o /dev/null "$url"; then
      ok "健康检查通过: ${url}"
      return 0
    fi
    sleep 1
  done
  warn "健康检查未通过，请查看: journalctl -u ${SERVICE_NAME} -f"
  return 1
}

print_summary() {
  local public_ip
  public_ip="$(curl -fsS -m 5 https://api.ipify.org 2>/dev/null || true)"
  echo
  echo "=============================================================="
  echo "  tweet-gif-web 安装完成"
  echo "=============================================================="
  echo "  版本       : ${VERSION}"
  echo "  安装目录   : ${INSTALL_DIR}"
  echo "  配置文件   : ${CONFIG_DIR}/tweet-gif-web.env"
  echo "  运行用户   : ${SERVICE_USER}"
  echo "  管理面板   : 输入 tweetgif（安装/更新/卸载/服务管理/配置）"
  if [ -n "$public_ip" ]; then
    echo "  访问地址   : http://${public_ip}:${PORT}"
  fi
  echo "  本机地址   : http://127.0.0.1:${PORT}"
  echo
  echo "  查看状态   : systemctl status ${SERVICE_NAME}"
  echo "  查看日志   : journalctl -u ${SERVICE_NAME} -f"
  echo "  重启服务   : systemctl restart ${SERVICE_NAME}"
  echo "  修改配置   : nano ${CONFIG_DIR}/tweet-gif-web.env && systemctl restart ${SERVICE_NAME}"
  echo "  卸载       : curl -fsSL https://github.com/${REPO}/releases/latest/download/install.sh | sudo bash -s -- --uninstall"
  echo "=============================================================="
}

do_uninstall() {
  log "开始卸载 ${SERVICE_NAME}"
  local uninstall_user="${SERVICE_USER}"
  if [ -f "${CONFIG_DIR}/install-user" ]; then
    uninstall_user="$(cat "${CONFIG_DIR}/install-user" 2>/dev/null || echo "$uninstall_user")"
  elif id -u "$SERVICE_USER" >/dev/null 2>&1; then
    uninstall_user="$SERVICE_USER"
  fi

  systemctl stop "${SERVICE_NAME}" 2>/dev/null || true
  systemctl disable "${SERVICE_NAME}" 2>/dev/null || true
  rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
  systemctl daemon-reload 2>/dev/null || true
  rm -rf "$INSTALL_DIR" "$DATA_DIR" "$LOG_DIR" "$CONFIG_DIR"
  rm -f "${MANAGER_BIN}" "${MANAGER_LINK}"

  if [ "$uninstall_user" != "root" ] && id -u "$uninstall_user" >/dev/null 2>&1; then
    userdel "$uninstall_user" 2>/dev/null || true
  fi
  ok "卸载完成（ffmpeg 已保留）"
}

cleanup() {
  if [ -n "${TMP_DIR:-}" ] && [ -d "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

# ---------------------------------------------------------------- 管理面板
# 安装/更新/卸载之后，安装脚本会把自身复制为 /usr/local/bin/tweetgif，
# 输入 `tweetgif`（或 `tweetgif-manager`）即可打开交互式管理菜单。

svc_running() {
  systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null
}

get_service_port() {
  if [ -r "${ENV_FILE}" ]; then
    grep -E '^PORT=' "${ENV_FILE}" 2>/dev/null | tail -n1 | cut -d= -f2 || true
  fi
}

get_service_version() {
  local port resp
  port="$(get_service_port)"
  [ -n "$port" ] || port="8080"
  resp="$(curl -fsS -m 5 "http://127.0.0.1:${port}/healthz" 2>/dev/null || true)"
  printf '%s' "$resp" | grep -o '"version":"[^"]*"' 2>/dev/null \
    | head -n1 | cut -d'"' -f4 || true
}

manager_pause() {
  printf '\n'
  read -rp "按回车键返回菜单..." _ || exit 0
}

install_manager() {
  local target="${MANAGER_BIN}"
  # 已经以 tweetgif 命令运行时（管理面板里执行"安装"），自身即管理脚本
  if [ "$(readlink -f "$0" 2>/dev/null)" = "$(readlink -f "$target" 2>/dev/null)" ]; then
    ok "管理命令已就绪: 输入 tweetgif 打开管理面板"
    return 0
  fi
  if [ -f "$0" ] && [ "$(basename "$0")" != "bash" ] && [ -s "$0" ]; then
    cp -f "$0" "$target" || { warn "无法写入 ${target}，跳过管理命令安装"; return 0; }
  else
    # 通过管道执行时（curl | bash）没有脚本文件，按下载链获取
    local tmpf
    tmpf="$(mktemp)"
    if ! download_file "install.sh" "$tmpf"; then
      rm -f "$tmpf"
      warn "管理脚本下载失败，跳过管理命令安装"
      return 0
    fi
    cp -f "$tmpf" "$target"
    rm -f "$tmpf"
  fi
  chmod 0755 "$target"
  ln -sf "$target" "$MANAGER_LINK"
  ok "管理命令已安装: 输入 tweetgif 打开管理面板"
}

action_install() {
  main
}

action_update() {
  need_root
  local old new
  old="$(get_service_version)"
  old="${old:-未知}"
  log "当前版本: ${old}，正在检查并更新到最新版..."
  detect_arch
  download_and_install
  setup_user_and_dirs
  write_env_file
  write_systemd_unit
  start_service
  health_check || true
  new="$(get_service_version)"
  new="${new:-未知}"
  ok "更新完成: ${old} -> ${new}"
}

action_uninstall() {
  need_root
  do_uninstall
  rm -f "${MANAGER_BIN}" "${MANAGER_LINK}"
  ok "管理命令已移除，再见 👋"
  exit 0
}

action_status() {
  if command -v systemctl >/dev/null 2>&1 \
     && systemctl cat "${SERVICE_NAME}" >/dev/null 2>&1; then
    systemctl status "${SERVICE_NAME}" --no-pager -l || true
  else
    warn "服务尚未安装，请先在菜单中选择 1 安装"
  fi
}

action_start() {
  need_root
  systemctl start "${SERVICE_NAME}"
  sleep 1
  if svc_running; then
    ok "服务已启动 (端口 $(get_service_port || echo "${PORT}"))"
  else
    warn "服务启动失败，请查看日志（菜单选项 8）"
  fi
}

action_stop() {
  need_root
  systemctl stop "${SERVICE_NAME}"
  ok "服务已停止"
}

action_restart() {
  need_root
  systemctl restart "${SERVICE_NAME}"
  sleep 1
  if svc_running; then
    ok "服务已重启"
  else
    warn "服务重启失败，请查看日志（菜单选项 8）"
  fi
}

action_log() {
  if ! command -v journalctl >/dev/null 2>&1; then
    die "当前系统没有 journalctl"
  fi
  journalctl -u "${SERVICE_NAME}" -n 50 --no-pager || true
  local yn
  read -rp "是否实时跟踪日志（Ctrl+C 退出）? [y/N]: " yn || return 0
  case "$yn" in
    [yY]*) journalctl -u "${SERVICE_NAME}" -f --no-pager || true ;;
  esac
}

action_config() {
  need_root
  [ -r "${ENV_FILE}" ] || die "配置文件不存在: ${ENV_FILE}"
  echo "当前配置 (${ENV_FILE}):"
  echo "------------------------------------------------------------"
  grep -vE '^[[:space:]]*#|^[[:space:]]*$' "${ENV_FILE}" 2>/dev/null || true
  echo "------------------------------------------------------------"
  local cur_port new_port
  cur_port="$(get_service_port)"
  cur_port="${cur_port:-8080}"
  read -rp "Web 端口 [当前 ${cur_port}]（直接回车保持不变）: " new_port || return 0
  if [ -n "$new_port" ]; then
    case "$new_port" in
      ''|*[!0-9]*) die "端口必须是数字: $new_port" ;;
    esac
    [ "$new_port" -ge 1 ] && [ "$new_port" -le 65535 ] || die "端口超出范围: $new_port"
    sed -i.bak "s/^PORT=.*/PORT=${new_port}/" "${ENV_FILE}"
    rm -f "${ENV_FILE}.bak"
    ok "端口已修改为 ${new_port}"
    systemctl restart "${SERVICE_NAME}"
    ok "服务已重启，新地址: http://127.0.0.1:${new_port}"
  fi
  local ed
  for ed in "${EDITOR:-}" nano vim vi; do
    if [ -n "$ed" ] && command -v "$ed" >/dev/null 2>&1; then
      break
    fi
    ed=""
  done
  if [ -n "$ed" ]; then
    local yn
    read -rp "是否用 ${ed} 编辑完整配置? [y/N]: " yn || return 0
    case "$yn" in
      [yY]*)
        "$ed" "${ENV_FILE}"
        systemctl restart "${SERVICE_NAME}"
        ok "配置已保存并重启服务"
        ;;
    esac
  fi
}

action_health() {
  local port
  port="$(get_service_port)"
  port="${port:-8080}"
  if svc_running && curl -fsS -m 5 "http://127.0.0.1:${port}/healthz" >/dev/null 2>&1; then
    ok "健康检查通过: http://127.0.0.1:${port}/healthz (版本: $(get_service_version))"
  else
    warn "健康检查未通过，请查看日志: journalctl -u ${SERVICE_NAME} -f"
    return 1
  fi
}

action_info() {
  echo "系统     : $(uname -srm)"
  if [ -r /etc/os-release ]; then
    echo "发行版   : $(sed -n 's/^PRETTY_NAME=//p' /etc/os-release | head -n1 | tr -d '"')"
  fi
  echo "CPU      : $(nproc 2>/dev/null || echo '?') 核 $(uname -m)"
  if command -v free >/dev/null 2>&1; then
    free -h 2>/dev/null | awk 'NR==2{printf "内存     : 已用 %s / 共 %s\n", $3, $2}'
  fi
  df -h "${INSTALL_DIR}" 2>/dev/null | tail -n1 \
    | awk '{printf "磁盘     : 已用 %s / 共 %s (挂载于 %s)\n", $3, $2, $6}' || true
  if svc_running; then
    echo "服务     : 运行中 (启动于 $(systemctl show -p ActiveEnterTimestamp --value "${SERVICE_NAME}" 2>/dev/null || true))"
  else
    echo "服务     : 已停止"
  fi
}

action_about() {
  local ver
  ver="$(get_service_version)"
  ver="${ver:-未知}"
  echo "tweet-gif-web — Twitter/X 视频转 GIF 的 Web 服务"
  echo "仓库       : https://github.com/${REPO}"
  echo "当前版本   : ${ver}"
  echo "安装目录   : ${INSTALL_DIR}"
  echo "配置文件   : ${ENV_FILE}"
  echo "管理命令   : tweetgif / tweetgif-manager"
  echo "更多文档   : 见仓库 README.md 与 DEPLOYMENT.md"
}

manager_menu() {
  local ver status
  ver="$(get_service_version)"
  ver="${ver:-未知}"
  status="已停止"
  svc_running && status="运行中"
  cat <<EOF

==============================================================
  tweet-gif-web 管理脚本
  版本: ${ver}        服务状态: ${status}
==============================================================
 基础功能:
  1. 安装 tweet-gif-web
  2. 更新 tweet-gif-web
  3. 卸载 tweet-gif-web
 -------------------
 服务管理:
  4. 查看状态
  5. 启动服务
  6. 停止服务
  7. 重启服务
  8. 查看日志
 -------------------
 配置管理:
  9. 修改配置
 10. 健康检查
 -------------------
 高级选项:
 11. 系统信息
 12. 关于
 -------------------
  0. 退出脚本
==============================================================
EOF
}

manager_usage() {
  cat <<'USAGE'
tweet-gif-web 管理命令

用法:
  tweetgif              打开交互式管理菜单
  tweetgif <子命令>     直接执行对应操作

子命令:
  status    查看服务状态        start     启动服务
  stop      停止服务            restart   重启服务
  log       查看日志            health    健康检查
  config    修改配置            info      系统信息
  update    更新到最新版        uninstall 卸载
  version   显示当前版本        help      显示本帮助
USAGE
}

manager_main() {
  if [ $# -gt 0 ]; then
    case "$1" in
      status)    action_status ;;
      start)     action_start ;;
      stop)      action_stop ;;
      restart)   action_restart ;;
      log|logs)  action_log ;;
      config)    action_config ;;
      health)    action_health || true ;;
      info)      action_info ;;
      about)     action_about ;;
      update)    action_update ;;
      uninstall) action_uninstall ;;
      version)
        local v
        v="$(get_service_version)"
        echo "${v:-未知（服务未运行或未安装）}"
        ;;
      help|-h|--help) manager_usage ;;
      *) die "未知子命令: $1（直接运行 tweetgif 打开管理菜单，或 tweetgif help）" ;;
    esac
    exit 0
  fi

  while true; do
    manager_menu
    local choice
    read -rp "请输入选项 [0-12]: " choice || exit 0
    case "$choice" in
      1)  action_install ;;
      2)  action_update ;;
      3)  action_uninstall ;;
      4)  action_status ;;
      5)  action_start ;;
      6)  action_stop ;;
      7)  action_restart ;;
      8)  action_log ;;
      9)  action_config ;;
      10) action_health || true ;;
      11) action_info ;;
      12) action_about ;;
      0)  echo "再见 👋"; exit 0 ;;
      "") continue ;;
      *)  warn "无效选项: ${choice}" ;;
    esac
    manager_pause
  done
}

# ---------------------------------------------------------------- 主流程
main() {
  parse_args "$@"

  if [ "$DO_UNINSTALL" -eq 1 ]; then
    need_root
    do_uninstall
    exit 0
  fi

  echo "=============================================================="
  echo "  tweet-gif-web 一键安装脚本"
  echo "  仓库: ${REPO}    版本: ${VERSION}"
  echo "=============================================================="

  need_root
  require_cmd curl
  detect_arch
  install_packages
  download_and_install
  setup_user_and_dirs
  write_env_file
  write_systemd_unit
  configure_firewall
  install_manager

  if [ "$DO_START" -eq 1 ]; then
    start_service
    health_check || true
  else
    log "已跳过启动（--no-start），可手动执行: systemctl start ${SERVICE_NAME}"
  fi

  print_summary
}

# ---------------------------------------------------------------- 模式分发
# 作为 tweetgif / tweetgif-manager 命令运行时进入管理面板，
# 否则执行安装流程（与 OpenList 面板管理命令一致的使用方式）。
case "$(basename "$0" 2>/dev/null)" in
  tweetgif|tweetgif-manager)
    manager_main "$@"
    ;;
  *)
    if [ "${TWEETGIF_MANAGER:-}" = "1" ]; then
      manager_main "$@"
    else
      main "$@"
    fi
    ;;
esac