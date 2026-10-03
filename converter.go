package main

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"github.com/google/uuid"
)

func downloadVideo(mediaURL string) (string, error) {
	client := &http.Client{
		Timeout: 60 * time.Second,
	}

	// 如果配置了代理
	if config.HTTPProxy != "" {
		proxyURL, err := url.Parse(config.HTTPProxy)
		if err == nil {
			client.Transport = &http.Transport{
				Proxy: http.ProxyURL(proxyURL),
			}
		}
	}

	resp, err := client.Get(mediaURL)
	if err != nil {
		return "", fmt.Errorf("下载失败: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("下载失败，状态码: %d", resp.StatusCode)
	}

	// 检查文件大小
	if resp.ContentLength > config.MaxMP4SizeMB*1024*1024 {
		return "", fmt.Errorf("文件过大，超过 %d MB 限制", config.MaxMP4SizeMB)
	}

	// 创建临时文件
	tmpFile, err := os.CreateTemp(config.TempDir, "video-*.mp4")
	if err != nil {
		return "", fmt.Errorf("创建临时文件失败: %v", err)
	}
	defer tmpFile.Close()

	// 限制读取大小
	limitReader := io.LimitReader(resp.Body, config.MaxMP4SizeMB*1024*1024)

	written, err := io.Copy(tmpFile, limitReader)
	if err != nil {
		os.Remove(tmpFile.Name())
		return "", fmt.Errorf("保存文件失败: %v", err)
	}

	if written == 0 {
		os.Remove(tmpFile.Name())
		return "", fmt.Errorf("下载的文件为空")
	}

	return tmpFile.Name(), nil
}

func convertToGif(mp4Path string) (string, string, error) {
	// 生成任务 ID
	taskID := uuid.New().String()

	// 生成 GIF 输出路径
	gifPath := filepath.Join(config.TempDir, taskID+".gif")

	// 构建 ffmpeg 命令
	// 使用高质量的调色板生成方法
	filter := fmt.Sprintf(
		"fps=%d,scale=%d:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse",
		config.GifFPS,
		config.GifWidth,
	)

	args := []string{
		"-y",          // 覆盖输出文件
		"-i", mp4Path, // 输入文件
		"-vf", filter, // 视频滤镜
		"-loop", "0", // 循环播放
		gifPath, // 输出文件
	}

	// 创建带超时的 context
	ctx, cancel := context.WithTimeout(context.Background(), config.ConversionTimeout)
	defer cancel()

	// 执行 ffmpeg
	cmd := exec.CommandContext(ctx, config.FfmpegPath, args...)

	// 捕获错误输出
	output, err := cmd.CombinedOutput()
	if err != nil {
		// 清理可能生成的部分文件
		os.Remove(gifPath)

		if ctx.Err() == context.DeadlineExceeded {
			return "", "", fmt.Errorf("转换超时")
		}

		return "", "", fmt.Errorf("ffmpeg 执行失败: %v, 输出: %s", err, string(output))
	}

	// 检查输出文件是否存在
	if _, err := os.Stat(gifPath); os.IsNotExist(err) {
		return "", "", fmt.Errorf("GIF 文件未生成")
	}

	return gifPath, taskID, nil
}
