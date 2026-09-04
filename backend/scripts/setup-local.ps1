<#
.SYNOPSIS
    本地开发环境一键管理脚本（Windows）。

.DESCRIPTION
    管理 PCL-Satellite-Cloud 本地后端环境：清理测试数据、重建数据库、
    导出/还原快照，并负责 PostgreSQL / server 的启停与健康检查。

    基线的定义（scenarios/satellites/router 拓扑）由 server 启动时自动
    重建（DB migration seed + CSV 自动导入），因此任何模式下基线都能恢复。

.PARAMETER Mode
    Reset      （默认）仅清理测试产生的脏数据（remote_sensing_tasks 等），
               保留基线数据，server 无需重建。适合日常测试后还原。
    FullReset  重建数据库（dropdb + createdb）+ 重启 server，
               回到与首次初始化完全一致的全新基线。
    Snapshot   导出当前数据库为快照文件（默认 ./snapshots/satellite_db_<时间戳>.sql）。
    Restore    从快照文件还原数据库 + 重启 server（最完整的还原方式）。

.PARAMETER SnapshotPath
    配合 -Mode Restore / Snapshot 使用：快照文件路径。

.PARAMETER NoServer
    只操作数据库，不启停 server。

.EXAMPLE
    .\setup-local.ps1 -Mode Reset
    .\setup-local.ps1 -Mode FullReset
    .\setup-local.ps1 -Mode Snapshot
    .\setup-local.ps1 -Mode Restore -SnapshotPath .\snapshots\satellite_db_20260821.sql
#>

[CmdletBinding()]
param(
    [ValidateSet("Reset", "FullReset", "Snapshot", "Restore")]
    [string]$Mode = "Reset",
    [string]$SnapshotPath = "",
    [switch]$NoServer,
    [switch]$SkipHealth,

    [string]$PgBin = "$env:USERPROFILE\pg-16\pgsql\bin",
    [string]$ServerBin = "",
    [string]$BackendDir = "",
    [string]$DbHost = "localhost",
    [string]$DbPort = "5432",
    [string]$DbUser = "satellite_user",
    [string]$DbName = "satellite_db",
    [int]$HealthTimeoutSec = 30
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot

# ---------- 路径定位 ----------
if (-not $BackendDir) { $BackendDir = Join-Path $scriptDir ".." }
$BackendDir = (Resolve-Path $BackendDir).Path
if (-not $ServerBin) { $ServerBin = Join-Path $BackendDir "bin\server.exe" }
$ServerBin = [System.IO.Path]::GetFullPath($ServerBin)

$pgTools = @("psql", "pg_dump", "pg_isready", "dropdb", "createdb")
foreach ($t in $pgTools) {
    $p = Join-Path $PgBin "$t.exe"
    if (-not (Test-Path $p)) { throw "缺少 PG 工具: $p (可用 -PgBin 指定)" }
}
if (-not (Test-Path $ServerBin)) { throw "缺少 server 可执行文件: $ServerBin (可用 -ServerBin 指定)" }

$env:PGHOST = $DbHost
$env:PGPORT = $DbPort
$env:PGUSER = $DbUser
$env:PGDATABASE = "postgres"   # maintenance db，后续按需切换

function Invoke-Ps {
    param([string]$Tool, [string[]]$CmdArgs, [string]$Db = $DbName)
    $env:PGDATABASE = $Db
    $full = Join-Path $PgBin "$Tool.exe"
    & $full @CmdArgs
    if ($LASTEXITCODE -ne 0) { throw "$Tool 失败 (exit=$LASTEXITCODE)" }
}

function Test-PgReady {
    & (Join-Path $PgBin "pg_isready.exe") -h $DbHost -p $DbPort -q
    return ($LASTEXITCODE -eq 0)
}

function Stop-Server {
    if ($NoServer) { return }
    Get-Process -Name server -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host "  停止 server (PID $($_.Id))..."
        Stop-Process -Id $_.Id -Force
    }
    Start-Sleep -Seconds 1
}

function Start-Server {
    if ($NoServer) { return }
    $logFile = Join-Path $BackendDir "server.log"
    $logFile = [System.IO.Path]::GetFullPath($logFile)
    $p = Start-Process -FilePath $ServerBin -WorkingDirectory $BackendDir `
        -WindowStyle Hidden -RedirectStandardOutput $logFile -RedirectStandardError "$logFile.err" -PassThru
    Write-Host "  启动 server (PID $($p.Id))，日志: $logFile"
    if ($SkipHealth) { return }

    $deadline = (Get-Date).AddSeconds($HealthTimeoutSec)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 800
        if ($p.HasExited) {
            Write-Host "  [FAIL] server 进程退出 (exit=$($p.ExitCode))，日志尾部："
            Get-Content $logFile -Tail 20 -ErrorAction SilentlyContinue
            throw "server 启动失败"
        }
        try {
            $r = Invoke-WebRequest -Uri "http://localhost:8080/ready" -UseBasicParsing -TimeoutSec 2
            if ($r.StatusCode -eq 200) { Write-Host "  server 就绪: /ready 200"; return }
        } catch { }
    }
    throw "等待 server 就绪超时 (${HealthTimeoutSec}s)"
}

function Get-RowCounts {
    param([string[]]$Tables)
    $queries = @()
    foreach ($t in $Tables) { $queries += "SELECT '$t' AS tbl, count(*) FROM $t" }
    $env:PGDATABASE = $DbName
    $full = Join-Path $PgBin "psql.exe"
    $rows = & $full -h $DbHost -p $DbPort -U $DbUser -d $DbName -t -A -F "=" -c ($queries -join " UNION ALL ")
    foreach ($row in $rows) {
        $parts = $row.Split("=", 2)
        Write-Host ("    {0,-32} {1}" -f $parts[0], $parts[1])
    }
}

# ---------- 主流程 ----------
Write-Host "=== PCL-Satellite-Cloud 本地环境: $Mode ==="
Write-Host "  DB: $DbUser@$DbHost`:$DbPort/$DbName"
Write-Host "  PG bin: $PgBin"
Write-Host "  Server: $ServerBin"

if (-not (Test-PgReady)) {
    Write-Host "[FAIL] PostgreSQL 未在运行。请先启动："
    Write-Host "        & '$PgBin\pg_ctl.exe' -D '$env:USERPROFILE\pg-16\pgsql\data' -l pg.log start"
    exit 1
}
Write-Host "  PostgreSQL: 运行中"

switch ($Mode) {
    "Reset" {
        Write-Host ">> 清理测试脏数据（保留基线）..."
        Stop-Server
        $env:PGDATABASE = $DbName
        Invoke-Ps "psql" @("-c", "DELETE FROM remote_sensing_tasks;") | Out-Null
        Invoke-Ps "psql" @("-c", "DELETE FROM object_detection_tasks;") | Out-Null
        Write-Host "  已删除测试任务（remote_sensing_task_stages/logs/artifacts 由外键级联清理）"
        Start-Server
    }
    "FullReset" {
        Write-Host ">> 重建数据库（dropdb + createdb）..."
        Stop-Server
        Invoke-Ps "dropdb" @("--if-exists", $DbName) -Db "postgres"
        Invoke-Ps "createdb" @($DbName) -Db "postgres"
        Write-Host "  数据库已重建，启动 server 自动迁移 + seed + 拓扑导入..."
        Start-Server
        Write-Host ">> 基线数据（应自动重生）："
        Get-RowCounts @("scenarios", "satellites", "router_nodes", "router_links", "remote_sensing_tasks")
    }
    "Snapshot" {
        if (-not $SnapshotPath) {
            $dir = Join-Path $scriptDir "snapshots"
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
            $SnapshotPath = Join-Path $dir ("satellite_db_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".sql")
        }
        $snapDir = Split-Path $SnapshotPath -Parent
        if ($snapDir -and -not (Test-Path $snapDir)) { New-Item -ItemType Directory -Path $snapDir | Out-Null }
        Write-Host ">> 导出快照 -> $SnapshotPath"
        Invoke-Ps "pg_dump" @("-h", $DbHost, "-p", $DbPort, "-U", $DbUser, "-d", $DbName, "-f", $SnapshotPath)
        Write-Host "  快照完成"
    }
    "Restore" {
        if (-not $SnapshotPath -or -not (Test-Path $SnapshotPath)) {
            throw "请提供有效的 -SnapshotPath"
        }
        Write-Host ">> 从快照还原: $SnapshotPath"
        Stop-Server
        Invoke-Ps "dropdb" @("--if-exists", $DbName) -Db "postgres"
        Invoke-Ps "createdb" @($DbName) -Db "postgres"
        Invoke-Ps "psql" @("-f", $SnapshotPath)
        Write-Host "  快照已导入，重启 server..."
        Start-Server
    }
}

Write-Host "=== 完成 ==="
