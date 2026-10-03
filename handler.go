package main

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

type ConvertRequest struct {
	URL string `json:"url"`
}

type ConvertResponse struct {
	Success bool   `json:"success"`
	GifURL  string `json:"gif_url,omitempty"`
	Message string `json:"message,omitempty"`
	Error   string `json:"error,omitempty"`
}

func handleConvert(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	if r.Method != http.MethodPost {
		respondError(w, "仅支持 POST 方法", http.StatusMethodNotAllowed)
		return
	}

	var req ConvertRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, "请求格式错误", http.StatusBadRequest)
		return
	}

	if req.URL == "" {
		respondError(w, "URL 不能为空", http.StatusBadRequest)
		return
	}

	// 验证 URL 域名
	if !isValidTweetURL(req.URL) {
		respondError(w, "不支持的 URL 格式，请使用 x.com, twitter.com 或相关服务的链接", http.StatusBadRequest)
		return
	}

	// 获取并发限制 semaphore
	select {
	case semaphore <- struct{}{}:
		defer func() { <-semaphore }()
	default:
		respondError(w, "服务器繁忙，请稍后重试", http.StatusTooManyRequests)
		return
	}

	// 解析推文
	tweetInfo, err := parseTweetURL(req.URL)
	if err != nil {
		log.Printf("解析推文失败: %v", err)
		respondError(w, "无法解析推文链接", http.StatusBadRequest)
		return
	}

	// 获取媒体 URL
	mediaURL, err := getMediaURL(tweetInfo)
	if err != nil {
		log.Printf("获取媒体 URL 失败: %v", err)
		respondError(w, err.Error(), http.StatusBadRequest)
		return
	}

	// 下载视频
	mp4Path, err := downloadVideo(mediaURL)
	if err != nil {
		log.Printf("下载视频失败: %v", err)
		respondError(w, "下载视频失败", http.StatusInternalServerError)
		return
	}
	defer os.Remove(mp4Path) // 转换后删除临时 MP4

	// 转换为 GIF
	gifPath, taskID, err := convertToGif(mp4Path)
	if err != nil {
		log.Printf("转换 GIF 失败: %v", err)
		respondError(w, "转换失败，请重试", http.StatusInternalServerError)
		return
	}

	// 保存任务
	saveTask(taskID, gifPath)

	_ = json.NewEncoder(w).Encode(ConvertResponse{
		Success: true,
		GifURL:  "/download/" + taskID + ".gif",
		Message: "转换成功",
	})
}

func handleDownload(w http.ResponseWriter, r *http.Request) {
	// 提取任务 ID
	path := strings.TrimPrefix(r.URL.Path, "/download/")
	taskID := strings.TrimSuffix(path, ".gif")

	if taskID == "" {
		http.NotFound(w, r)
		return
	}

	// 获取文件路径
	gifPath := getTaskPath(taskID)
	if gifPath == "" {
		http.NotFound(w, r)
		return
	}

	// 检查文件是否存在
	if _, err := os.Stat(gifPath); os.IsNotExist(err) {
		http.NotFound(w, r)
		return
	}

	// 设置响应头
	w.Header().Set("Content-Type", "image/gif")
	w.Header().Set("Content-Disposition", "inline; filename=\"tweet.gif\"")
	w.Header().Set("Cache-Control", "public, max-age=3600")

	// 发送文件
	http.ServeFile(w, r, gifPath)
}

func serveFrontend() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		path := r.URL.Path
		if path == "/" {
			path = "/index.html"
		}

		// 去掉前导斜杠，构建嵌入路径
		embedPath := "frontend/build/dist/wasmJs/productionExecutable" + path

		// 读取文件
		data, err := frontendFS.ReadFile(embedPath)
		if err != nil {
			// 带扩展名的路径是静态资源（如升级后旧缓存引用的旧哈希 wasm），
			// 不做 SPA 回退，直接 404，避免浏览器把 HTML 当 wasm 解析后白屏
			if filepath.Ext(path) != "" {
				http.NotFound(w, r)
				return
			}
			// SPA 路由回退到 index.html
			data, err = frontendFS.ReadFile("frontend/build/dist/wasmJs/productionExecutable/index.html")
			if err != nil {
				http.NotFound(w, r)
				return
			}
			w.Header().Set("Content-Type", "text/html; charset=utf-8")
			serveWithETag(w, r, data)
			return
		}

		// 设置正确的 Content-Type
		ext := filepath.Ext(path)
		switch ext {
		case ".wasm":
			w.Header().Set("Content-Type", "application/wasm")
		case ".js":
			w.Header().Set("Content-Type", "application/javascript")
		case ".html":
			w.Header().Set("Content-Type", "text/html; charset=utf-8")
		case ".css":
			w.Header().Set("Content-Type", "text/css")
		case ".json":
			w.Header().Set("Content-Type", "application/json")
		case ".png":
			w.Header().Set("Content-Type", "image/png")
		case ".svg":
			w.Header().Set("Content-Type", "image/svg+xml")
		}

		serveWithETag(w, r, data)
	})
}

// serveWithETag 输出静态内容：no-cache + ETag 使浏览器每次都校验，
// 内容未变化返回 304，版本升级后旧缓存立即失效（无需用户强刷）
func serveWithETag(w http.ResponseWriter, r *http.Request, data []byte) {
	sum := sha256.Sum256(data)
	etag := fmt.Sprintf(`"%x"`, sum[:16])
	w.Header().Set("ETag", etag)
	w.Header().Set("Cache-Control", "no-cache")
	if r.Header.Get("If-None-Match") == etag {
		w.WriteHeader(http.StatusNotModified)
		return
	}
	_, _ = w.Write(data)
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"status":  "ok",
		"version": version,
	})
}

func respondError(w http.ResponseWriter, message string, statusCode int) {
	w.WriteHeader(statusCode)
	_ = json.NewEncoder(w).Encode(ConvertResponse{
		Success: false,
		Error:   message,
	})
}

func isValidTweetURL(url string) bool {
	validDomains := []string{
		"x.com",
		"twitter.com",
		"mobile.twitter.com",
		"vxtwitter.com",
		"fxtwitter.com",
	}

	lowerURL := strings.ToLower(url)
	for _, domain := range validDomains {
		if strings.Contains(lowerURL, domain) {
			return true
		}
	}
	return false
}
