// Package migrations 通过 embed 将迁移 SQL 打进二进制，供启动时自动执行。
package migrations

import "embed"

// FS 包含所有 *.up.sql 文件，按文件名顺序执行（000001_xxx.up.sql, 000002_xxx.up.sql）。
//go:embed *.up.sql
var FS embed.FS
