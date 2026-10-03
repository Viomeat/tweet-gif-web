package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"
)

type TweetInfo struct {
	ID         string
	ScreenName string
}

type VXTwitterResponse struct {
	MediaURLs []string `json:"mediaURLs"`
	Media     *struct {
		Videos []struct {
			URL string `json:"url"`
		} `json:"videos"`
	} `json:"media"`
	Tweet *struct {
		Media *struct {
			Videos []struct {
				URL string `json:"url"`
			} `json:"videos"`
		} `json:"media"`
	} `json:"tweet"`
}

func parseTweetURL(tweetURL string) (*TweetInfo, error) {
	// 正则匹配推文 ID 和用户名
	// 支持格式: https://x.com/user/status/123456789
	//          https://twitter.com/user/status/123456789
	//          https://vxtwitter.com/user/status/123456789

	re := regexp.MustCompile(`(?:x\.com|twitter\.com|mobile\.twitter\.com|vxtwitter\.com|fxtwitter\.com)/([^/]+)/status/(\d+)`)
	matches := re.FindStringSubmatch(tweetURL)

	if len(matches) < 3 {
		return nil, errors.New("无法解析推文 URL")
	}

	return &TweetInfo{
		ID:         matches[2],
		ScreenName: matches[1],
	}, nil
}

func getMediaURL(info *TweetInfo) (string, error) {
	// 尝试多个 API 获取媒体 URL
	apis := []string{
		fmt.Sprintf("https://api.vxtwitter.com/%s/status/%s", info.ScreenName, info.ID),
		fmt.Sprintf("https://api.vxtwitter.com/status/%s", info.ID),
		fmt.Sprintf("https://api.fxtwitter.com/status/%s", info.ID),
	}

	client := &http.Client{
		Timeout: 15 * time.Second,
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

	var lastError error
	for _, apiURL := range apis {
		mediaURL, err := fetchMediaFromAPI(client, apiURL)
		if err == nil && mediaURL != "" {
			return mediaURL, nil
		}
		lastError = err
	}

	if lastError != nil {
		return "", fmt.Errorf("无法获取媒体 URL: %v", lastError)
	}
	return "", errors.New("该推文不包含视频或 GIF")
}

func fetchMediaFromAPI(client *http.Client, apiURL string) (string, error) {
	resp, err := client.Get(apiURL)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("API 返回状态码 %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	var result VXTwitterResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return "", err
	}

	// 尝试从不同字段提取视频 URL
	// 1. mediaURLs 数组
	if len(result.MediaURLs) > 0 {
		for _, mediaURL := range result.MediaURLs {
			if strings.Contains(strings.ToLower(mediaURL), ".mp4") {
				if isValidMediaURL(mediaURL) {
					return mediaURL, nil
				}
			}
		}
	}

	// 2. media.videos
	if result.Media != nil && len(result.Media.Videos) > 0 {
		for _, video := range result.Media.Videos {
			if video.URL != "" && isValidMediaURL(video.URL) {
				return video.URL, nil
			}
		}
	}

	// 3. tweet.media.videos
	if result.Tweet != nil && result.Tweet.Media != nil && len(result.Tweet.Media.Videos) > 0 {
		for _, video := range result.Tweet.Media.Videos {
			if video.URL != "" && isValidMediaURL(video.URL) {
				return video.URL, nil
			}
		}
	}

	return "", errors.New("未找到视频 URL")
}

func isValidMediaURL(mediaURL string) bool {
	// 检查是否来自可信域名
	trustedDomains := []string{
		"video.twimg.com",
		"pbs.twimg.com",
		"ton.twimg.com",
	}

	lowerURL := strings.ToLower(mediaURL)
	for _, domain := range trustedDomains {
		if strings.Contains(lowerURL, domain) {
			return true
		}
	}

	return false
}
