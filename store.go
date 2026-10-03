package main

import (
	"log"
	"os"
	"sync"
	"time"
)

type Task struct {
	ID        string
	GifPath   string
	CreatedAt time.Time
}

var (
	tasks     = make(map[string]*Task)
	tasksMux  sync.RWMutex
	semaphore chan struct{}
)

func initStore() {
	// 初始化并发控制 semaphore
	semaphore = make(chan struct{}, config.MaxConcurrent)
}

func saveTask(taskID, gifPath string) {
	tasksMux.Lock()
	defer tasksMux.Unlock()

	tasks[taskID] = &Task{
		ID:        taskID,
		GifPath:   gifPath,
		CreatedAt: time.Now(),
	}
}

func getTaskPath(taskID string) string {
	tasksMux.RLock()
	defer tasksMux.RUnlock()

	if task, exists := tasks[taskID]; exists {
		return task.GifPath
	}
	return ""
}

func cleanupRoutine() {
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()

	for range ticker.C {
		cleanupOldFiles()
	}
}

func cleanupOldFiles() {
	tasksMux.Lock()
	defer tasksMux.Unlock()

	ttl := time.Duration(config.FileTTLMinutes) * time.Minute
	now := time.Now()

	var toDelete []string

	for taskID, task := range tasks {
		if now.Sub(task.CreatedAt) > ttl {
			// 删除文件
			if err := os.Remove(task.GifPath); err != nil {
				if !os.IsNotExist(err) {
					log.Printf("删除过期文件失败 %s: %v", task.GifPath, err)
				}
			} else {
				log.Printf("已删除过期文件: %s", task.GifPath)
			}

			toDelete = append(toDelete, taskID)
		}
	}

	// 从 map 中删除任务
	for _, taskID := range toDelete {
		delete(tasks, taskID)
	}

	if len(toDelete) > 0 {
		log.Printf("清理了 %d 个过期任务", len(toDelete))
	}
}
