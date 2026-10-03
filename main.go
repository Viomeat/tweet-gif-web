package main

import (
	"embed"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"
)

//go:embed frontend/build/dist/wasmJs/productionExecutable
var frontendFS embed.FS

// version 由构建时注入: go build -ldflags "-X main.version=x.y.z"
var version = "dev"

var config Config

type Config struct {
	Port              string
	FfmpegPath        string
	TempDir           string
	GifFPS            int
	GifWidth          int
	MaxConcurrent     int
	FileTTLMinutes    int
	MaxMP4SizeMB      int64
	HTTPProxy         string
	ConversionTimeout time.Duration
}

func loadConfig() Config {
	getEnv := func(key, defaultVal string) string {
		if val := os.Getenv(key); val != "" {
			return val
		}
		return defaultVal
	}

	getEnvInt := func(key string, defaultVal int) int {
		if val := os.Getenv(key); val != "" {
			if i, err := strconv.Atoi(val); err == nil {
				return i
			}
		}
		return defaultVal
	}

	tempDir := getEnv("TEMP_DIR", "")
	if tempDir == "" {
		tempDir = os.TempDir() + "/tweet-gif-web"
	}

	return Config{
		Port:              getEnv("PORT", "8080"),
		FfmpegPath:        getEnv("FFMPEG_PATH", "ffmpeg"),
		TempDir:           tempDir,
		GifFPS:            getEnvInt("GIF_FPS", 12),
		GifWidth:          getEnvInt("GIF_WIDTH", 480),
		MaxConcurrent:     getEnvInt("MAX_CONCURRENT", 2),
		FileTTLMinutes:    getEnvInt("FILE_TTL_MINUTES", 30),
		MaxMP4SizeMB:      int64(getEnvInt("MAX_MP4_SIZE_MB", 50)),
		HTTPProxy:         getEnv("HTTP_PROXY", ""),
		ConversionTimeout: 30 * time.Second,
	}
}

func main() {
	config = loadConfig()

	// 创建临时目录
	if err := os.MkdirAll(config.TempDir, 0755); err != nil {
		log.Fatalf("无法创建临时目录: %v", err)
	}

	// 初始化任务存储
	initStore()

	// 启动清理 goroutine
	go cleanupRoutine()

	// 设置路由
	mux := http.NewServeMux()

	// API 路由
	mux.HandleFunc("/api/convert", handleConvert)
	mux.HandleFunc("/download/", handleDownload)
	mux.HandleFunc("/healthz", handleHealth)

	// 静态文件服务
	mux.Handle("/", serveFrontend())

	addr := ":" + config.Port
	log.Printf("服务启动在 %s", addr)
	log.Printf("临时目录: %s", config.TempDir)
	log.Printf("ffmpeg 路径: %s", config.FfmpegPath)

	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatalf("服务器启动失败: %v", err)
	}
}
