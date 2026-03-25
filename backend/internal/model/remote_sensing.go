package model

import (
	"time"

	"gorm.io/datatypes"
)

// RemoteSensingTask 代表一次遥感流水线任务
type RemoteSensingTask struct {
	ID             uint       `gorm:"primaryKey" json:"id"`
	Name           string     `gorm:"type:varchar(255);not null" json:"name"`
	Status         string     `gorm:"type:varchar(32);not null" json:"status"`
	InputDirectory string     `gorm:"type:text;not null" json:"input_directory"`
	FilePrefix     string     `gorm:"type:varchar(255);not null" json:"file_prefix"`
	Sensor         string     `gorm:"type:varchar(64)" json:"sensor,omitempty"`
	CurrentStage   string     `gorm:"type:varchar(64)" json:"current_stage,omitempty"`
	ErrorMessage   string     `gorm:"type:text" json:"error_message,omitempty"`
	CreatedAt      time.Time  `json:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at"`
	StartedAt      *time.Time `json:"started_at,omitempty"`
	FinishedAt     *time.Time `json:"finished_at,omitempty"`

	Stages    []RemoteSensingTaskStage    `gorm:"foreignKey:TaskID" json:"stages,omitempty"`
	Artifacts []RemoteSensingTaskArtifact `gorm:"foreignKey:TaskID" json:"artifacts,omitempty"`
}

// RemoteSensingTaskStage 代表流水线中的一个阶段
type RemoteSensingTaskStage struct {
	ID         uint              `gorm:"primaryKey" json:"id"`
	TaskID     uint              `gorm:"index;not null" json:"task_id"`
	Name       string            `gorm:"type:varchar(128);not null" json:"name"`
	Title      string            `gorm:"type:varchar(128)" json:"title,omitempty"`
	Order      int               `gorm:"column:stage_order;not null" json:"stage_order"`
	Status     string            `gorm:"type:varchar(32);not null" json:"status"`
	OutputPath string            `gorm:"type:text" json:"output_path,omitempty"`
	Details    datatypes.JSONMap `gorm:"type:jsonb" json:"details,omitempty"`
	Message    string            `gorm:"type:text" json:"message,omitempty"`
	CreatedAt  time.Time         `json:"created_at"`
	UpdatedAt  time.Time         `json:"updated_at"`
	StartedAt  *time.Time        `json:"started_at,omitempty"`
	FinishedAt *time.Time        `json:"finished_at,omitempty"`
}

// RemoteSensingTaskArtifact 记录任务产物（ENVI、预览图等）
type RemoteSensingTaskArtifact struct {
	ID        uint              `gorm:"primaryKey" json:"id"`
	TaskID    uint              `gorm:"index;not null" json:"task_id"`
	Type      string            `gorm:"type:varchar(64);not null" json:"type"`
	Label     string            `gorm:"type:varchar(128)" json:"label,omitempty"`
	Path      string            `gorm:"type:text;not null" json:"path"`
	Metadata  datatypes.JSONMap `gorm:"type:jsonb" json:"metadata,omitempty"`
	CreatedAt time.Time         `json:"created_at"`
}

// RemoteSensingTaskLog 存储阶段执行日志
type RemoteSensingTaskLog struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	TaskID    uint      `gorm:"index;not null" json:"task_id"`
	StageName string    `gorm:"type:varchar(128)" json:"stage_name,omitempty"`
	Level     string    `gorm:"type:varchar(32);not null" json:"level"`
	Content   string    `gorm:"type:text;not null" json:"content"`
	CreatedAt time.Time `json:"created_at"`
}
