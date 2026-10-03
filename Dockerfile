FROM golang:1.22-alpine AS builder

# 安装构建依赖
RUN apk add --no-cache git openjdk17

WORKDIR /build

# 复制前端源码
COPY frontend/ ./frontend/

# 构建前端
WORKDIR /build/frontend
RUN chmod +x ./gradlew && ./gradlew wasmJsBrowserDistribution

# 构建后端
WORKDIR /build
COPY go.mod go.sum ./
RUN go mod download

COPY *.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -o tweet-gif-web .

# 运行时镜像
FROM alpine:latest

# 安装 ffmpeg
RUN apk add --no-cache ffmpeg ca-certificates

# 创建运行用户
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

# 创建工作目录
RUN mkdir -p /app/tmp && chown -R appuser:appuser /app

WORKDIR /app
USER appuser

# 从构建阶段复制二进制文件
COPY --from=builder /build/tweet-gif-web .

# 配置环境变量
ENV PORT=8080 \
    FFMPEG_PATH=/usr/bin/ffmpeg \
    TEMP_DIR=/app/tmp \
    GIF_FPS=12 \
    GIF_WIDTH=480 \
    MAX_CONCURRENT=2 \
    FILE_TTL_MINUTES=30 \
    MAX_MP4_SIZE_MB=50

EXPOSE 8080

CMD ["./tweet-gif-web"]
