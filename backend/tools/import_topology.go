// 拓扑数据导入 CLI：从 CSV 导入 delay / T0 星历 / 路由拓扑到 DB。
//
// 用法（在 backend 目录下执行）：
//
//	# 数据库连接：-dsn 或环境变量 SATELLITE_DATABASE_URL
//	export SATELLITE_DATABASE_URL="postgres://user:pass@localhost:5432/postgres?sslmode=disable"
//
//	# 导入 delay 矩阵
//	go run ./tools/import_topology.go -mode=delay -scenario "Scenario5_full_36x22" -file ../frontend/public/data/delay_15x15.csv
//
//	# 导入 T0 星历（15 个 Sat_*_ephem_ext.csv 所在目录）
//	go run ./tools/import_topology.go -mode=t0 -scenario "Scenario5_full_36x22" -dir ../frontend/public/data/ephem_15
//
//	# 导入路由拓扑（r??????_net_qos.csv 所在目录）
//	go run ./tools/import_topology.go -mode=router -scenario "Scenario5_full_36x22" -dir ../frontend/public/data/router
package main

import (
	"flag"
	"log"
	"net/url"
	"os"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"

	"satellite-cloud/backend/internal/topology"
)

// dsnFromEnv 从 SATELLITE_DATABASE_* 环境变量组装 DSN，便于 K8s 使用与 backend 相同的 Secret。
func dsnFromEnv() string {
	host := os.Getenv("SATELLITE_DATABASE_HOST")
	port := os.Getenv("SATELLITE_DATABASE_PORT")
	user := os.Getenv("SATELLITE_DATABASE_USER")
	pass := os.Getenv("SATELLITE_DATABASE_PASSWORD")
	dbname := os.Getenv("SATELLITE_DATABASE_DBNAME")
	sslmode := os.Getenv("SATELLITE_DATABASE_SSLMODE")
	if host == "" || user == "" || dbname == "" {
		return ""
	}
	if port == "" {
		port = "5432"
	}
	if sslmode == "" {
		sslmode = "disable"
	}
	u := url.URL{
		Scheme: "postgres",
		User:   url.UserPassword(user, pass),
		Host:   host + ":" + port,
		Path:   "/" + dbname,
		RawQuery: "sslmode=" + url.QueryEscape(sslmode),
	}
	return u.String()
}

func main() {
	var (
		dsn          string
		mode         string
		scenarioName string
		filePath     string
		dirPath      string
	)

	flag.StringVar(&dsn, "dsn", "", "PostgreSQL DSN（未填时用 SATELLITE_DATABASE_URL 或 SATELLITE_DATABASE_* 组装）")
	flag.StringVar(&mode, "mode", "delay", "导入模式: delay | t0 | router")
	flag.StringVar(&scenarioName, "scenario", "Scenario5_full_36x22", "场景名称（scenarios.name）")
	flag.StringVar(&filePath, "file", "", "CSV 文件路径（mode=delay 时必填）")
	flag.StringVar(&dirPath, "dir", "", "CSV 所在目录（mode=t0 或 mode=router 时必填）")
	flag.Parse()

	if dsn == "" {
		dsn = os.Getenv("SATELLITE_DATABASE_URL")
	}
	if dsn == "" {
		dsn = dsnFromEnv()
	}
	if dsn == "" {
		log.Fatalf("必须通过 -dsn、SATELLITE_DATABASE_URL 或 SATELLITE_DATABASE_HOST/USER/PASSWORD/DBNAME 提供数据库连接")
	}

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatalf("连接数据库失败: %v", err)
	}

	log.Printf("场景: %s", scenarioName)

	switch mode {
	case "delay":
		if filePath == "" {
			filePath = "../frontend/public/data/delay_15x15.csv"
			log.Printf("未指定 -file，使用默认: %s", filePath)
		}
		log.Printf("导入 delay: %s", filePath)
		if err := topology.ImportDelayFromCSV(db, scenarioName, filePath); err != nil {
			log.Fatalf("导入 delay 失败: %v", err)
		}
		log.Printf("delay 导入完成")
	case "t0":
		if dirPath == "" {
			log.Fatalf("mode=t0 时必须指定 -dir（Sat_*_ephem_ext.csv 所在目录）")
		}
		log.Printf("导入 T0 星历: %s", dirPath)
		if err := topology.ImportSatStatesFromCSV(db, scenarioName, dirPath); err != nil {
			log.Fatalf("导入 T0 失败: %v", err)
		}
		log.Printf("T0 导入完成")
	case "router":
		if dirPath == "" {
			log.Fatalf("mode=router 时必须指定 -dir（r??????_net_qos.csv 所在目录）")
		}
		log.Printf("导入路由拓扑: %s", dirPath)
		if err := topology.ImportRouterFromCSV(db, scenarioName, dirPath); err != nil {
			log.Fatalf("导入 router 失败: %v", err)
		}
		log.Printf("router 导入完成")
	default:
		log.Fatalf("未知 mode=%q，支持: delay | t0 | router", mode)
	}
}
