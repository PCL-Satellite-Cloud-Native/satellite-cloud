package model

import (
    "time"

    "gorm.io/datatypes"
    "gorm.io/gorm"
)

// Scenario 场景模型
type Scenario struct {
	ID            uint           `gorm:"primaryKey" json:"id"`
	Name          string         `gorm:"type:varchar(255);not null" json:"name"`
	Epoch         string         `gorm:"type:varchar(100)" json:"epoch"`
	StartTime     string         `gorm:"type:varchar(100)" json:"start_time"`
	EndTime       string         `gorm:"type:varchar(100)" json:"end_time"`
	AltKm         float64        `json:"alt_km"`
	IncDeg        float64        `json:"inc_deg"`
	NPlanes       int            `json:"n_planes"`
	NSatsPerPlane int            `json:"n_sats_per_plane"`
	SensorConfig  datatypes.JSONMap `gorm:"type:jsonb" json:"sensor_config"`
	CreatedAt     time.Time      `json:"created_at"`
	UpdatedAt     time.Time      `json:"updated_at"`
	DeletedAt     gorm.DeletedAt `gorm:"index" json:"-"`

	// 关联
	Satellites []Satellite `gorm:"foreignKey:ScenarioID" json:"satellites,omitempty"`
}

// TableName 指定表名
func (Scenario) TableName() string {
	return "scenarios"
}

// ScenarioListResponse 场景列表响应（不包含卫星详情）
type ScenarioListResponse struct {
	ID              uint   `gorm:"column:id" json:"id"`
	Name            string `gorm:"column:name" json:"name"`
	Epoch           string `gorm:"column:epoch" json:"epoch"`
	StartTime       string `gorm:"column:start_time" json:"start_time"`
	EndTime         string `gorm:"column:end_time" json:"end_time"`
	AltKm           float64 `gorm:"column:alt_km" json:"alt_km"`
	IncDeg          float64 `gorm:"column:inc_deg" json:"inc_deg"`
	NPlanes         int    `gorm:"column:n_planes" json:"n_planes"`
	NSatsPerPlane   int    `gorm:"column:n_sats_per_plane" json:"n_sats_per_plane"`
	SatellitesCount int64  `gorm:"column:satellites_count" json:"satellites_count"`
}
