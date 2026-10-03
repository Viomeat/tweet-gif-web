# Tweet GIF 转换器

一个将 Twitter/X 推文中的视频转换为 GIF 的 Web 服务，采用 Go 后端 + Compose Multiplatform (material3) 前端。

## 功能特性

- 🎬 支持将推文中的视频/GIF 转换为高质量 GIF
- 🎨 Compose Multiplatform (material3) 构建的现代化前端界面
- 🚀 单一二进制部署（前端已嵌入），无需额外依赖（除了 ffmpeg）
- 📦 GitHub Actions 自动构建发布：每次推送自动递增版本号，产出 linux amd64/arm64 安装包
- 🔒 安全的 URL 验证和文件大小限制
- ⚡ 并发控制和自动清理过期文件
- 🌐 支持代理配置

## 支持的网站

- x.com
- twitter.com
- mobile.twitter.com
- vxtwitter.com
- fxtwitter.com

## 快速开始（Linux 服务器一键安装）

```bash
curl -fsSL https://github.com/Viomeat/tweet-gif-web/releases/latest/download/install.sh -o install.sh && sudo bash install.sh
```

脚本会自动：检测 CPU 架构（amd64/arm64）、安装 ffmpeg 等依赖、下载对应架构的安装包并校验 sha256、创建 `tweetgif` 系统用户与目录、写入配置、注册并启动 systemd 服务、开放防火墙端口、通过 `/healthz` 健康检查。

指定版本 / 端口：

```bash
curl -fsSL https://github.com/Viomeat/tweet-gif-web/releases/latest/download/install.sh \
  -o install.sh && sudo bash install.sh --version v1.0.1 --port 8080
```

重复执行安装命令即为**升级**（保留已有配置）。

## 🎛️ 面板管理命令

安装完成后，输入 `tweetgif`（或 `tweetgif-manager`）打开交互式管理菜单：

```
基础功能:  1.安装  2.更新  3.卸载
服务管理:  4.查看状态  5.启动  6.停止  7.重启  8.查看日志
配置管理:  9.修改配置  10.健康检查
高级选项:  11.系统信息  12.关于
```

也支持子命令直接执行，方便写进自动化脚本：

| 子命令 | 说明 | 子命令 | 说明 |
|--------|------|--------|------|
| `tweetgif status` | 查看服务状态 | `tweetgif start` | 启动服务 |
| `tweetgif stop` | 停止服务 | `tweetgif restart` | 重启服务 |
| `tweetgif log` | 查看日志 | `tweetgif health` | 健康检查 |
| `tweetgif config` | 修改配置（端口等） | `tweetgif info` | 系统信息 |
| `tweetgif update` | 更新到最新版 | `tweetgif version` | 显示当前版本 |
| `tweetgif uninstall` | 卸载 | `tweetgif help` | 帮助 |

## 服务管理

```bash
sudo systemctl status tweet-gif-web     # 查看状态
sudo systemctl restart tweet-gif-web    # 重启
sudo journalctl -u tweet-gif-web -f     # 查看日志
curl http://127.0.0.1:8080/healthz      # 健康检查
```

## 配置

配置文件：`/etc/tweet-gif-web/tweet-gif-web.env`（安装脚本生成，升级时保留）。
修改后 `sudo systemctl restart tweet-gif-web` 生效，或使用 `tweetgif config`。

通过环境变量配置服务：

| 环境变量 | 默认值 | 说明 |
|---------|--------|------|
| PORT | 8080 | HTTP 监听端口 |
| FFMPEG_PATH | ffmpeg | ffmpeg 可执行文件路径 |
| TEMP_DIR | /tmp/tweet-gif-web | 临时文件目录 |
| GIF_FPS | 12 | GIF 帧率 |
| GIF_WIDTH | 480 | GIF 宽度（高度自适应） |
| MAX_CONCURRENT | 2 | 最大并发转换数 |
| FILE_TTL_MINUTES | 30 | 临时文件保留时长（分钟） |
| MAX_MP4_SIZE_MB | 50 | 最大 MP4 下载大小（MB） |
| HTTP_PROXY | 空 | HTTP 代理地址 |

### 安装脚本下载源

安装包默认从 GitHub Releases 下载。也可以设置环境变量走自建 OpenList 镜像加速（脚本会依次尝试 WebDAV / 直链 / API 三种模式）：

```bash
OPENLIST_BASE=https://your-openlist.example.com \
OPENLIST_DIR=your-mount-dir \
OPENLIST_USER=your-user OPENLIST_PASS=your-pass \
sudo -E bash install.sh
```

| 环境变量 | 说明 |
|---------|------|
| `OPENLIST_BASE` | 自建 OpenList 镜像地址（不设置则只用 GitHub） |
| `OPENLIST_DIR` | 镜像内文件所在目录 |
| `OPENLIST_USER` / `OPENLIST_PASS` | 镜像账号密码 |
| `DL_SOURCE=github` | 强制仅使用 GitHub 下载源 |
| `GITHUB_TOKEN` | 私有仓库或触发 API 限流时使用 |

## API 文档

### POST /api/convert

请求体：
```json
{"url": "https://x.com/user/status/123456789"}
```

成功响应：
```json
{"success": true, "gif_url": "/download/uuid.gif", "message": "转换成功"}
```

### GET /download/{id}.gif

下载生成的 GIF 文件。

### GET /healthz

健康检查接口，返回当前版本：

```json
{"status": "ok", "version": "1.0.1"}
```

## 故障排查

```bash
journalctl -u tweet-gif-web -n 50 --no-pager   # 最近日志
systemctl cat tweet-gif-web                    # 查看 unit 文件
cat /etc/tweet-gif-web/tweet-gif-web.env       # 查看运行配置
```

## 构建与开发

### 从源码构建

```bash
# 前端（需要 JDK 17+）
cd frontend
./gradlew wasmJsBrowserDistribution
cd ..

# 后端（需要 Go 1.22+）
go mod download
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o tweet-gif-web .
```

### 前端开发模式

```bash
cd frontend
./gradlew wasmJsBrowserRun
```

### 后端开发模式

```bash
cd frontend && ./gradlew wasmJsBrowserDistribution && cd ..
go run .
```

## 许可证

MIT License
