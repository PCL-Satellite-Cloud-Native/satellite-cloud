package model

import (
	"time"

	"gorm.io/gorm"
)

// Satellite 卫星模型
type Satellite struct {
	ID              uint           `gorm:"primaryKey" json:"id"`
	ScenarioID      uint           `gorm:"not null;index" json:"scenario"`
	SatID           string         `gorm:"type:varchar(100);not null" json:"sat_id"`
	StkName         string         `gorm:"type:varchar(255);not null" json:"stk_name"`
	PlaneIndex      int            `gorm:"index" json:"plane_index"`
	SatIndexInPlane int            `gorm:"index" json:"sat_index_in_plane"`
	AltKm           float64        `json:"alt_km"`
	SmaKm           float64        `json:"sma_km"`
	Ecc             float64        `json:"ecc"`
	IncDeg          float64        `json:"inc_deg"`
	RaanDeg         float64        `json:"raan_deg"`
	ArgpDeg         float64        `json:"argp_deg"`
	TaDeg           float64        `json:"ta_deg"`
	CreatedAt       time.Time      `json:"created_at"`
	UpdatedAt       time.Time      `json:"updated_at"`
	DeletedAt       gorm.DeletedAt `gorm:"index" json:"-"`

	// 关联
	Scenario Scenario `gorm:"foreignKey:ScenarioID" json:"-"`
}

// TableName 指定表名
func (Satellite) TableName() string {
	return "satellites"
}
