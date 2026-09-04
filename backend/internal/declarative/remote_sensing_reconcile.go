package declarative

import (
	"errors"
	"fmt"
	"time"

	"gorm.io/gorm"

	"satellite-cloud/backend/internal/model"
	"satellite-cloud/backend/internal/remotesensing"
)

// RemoteSensingTaskReconcileResult 汇报遥感任务声明式同步的结果。
type RemoteSensingTaskReconcileResult struct {
	// CRName 清单 metadata.name。
	CRName string
	// ScenarioName / ScenarioID 解析后的所属场景。
	ScenarioName string
	ScenarioID   uint
	// SatelliteID 解析后的目标卫星 sat_id（未指定时为空）。
	SatelliteID string
	// TaskName 实际写入的任务名（即 CRName）。
	TaskName string
	// Action 取值：created / updated / skipped / deleted / refused / notfound。
	Action string
	// Status 任务的运行时状态（pending / running / completed / failed）。
	Status       string
	CurrentStage string
	ErrorMessage string
	// Referenced 为 true 表示删除被拒绝（任务处于 running）。
	Referenced bool
}

// ReconcileRemoteSensingTask 把一份 RemoteSensingTask CR 同步到 PostgreSQL（幂等）。
//
// 同步语义：
//  1. 带删除注解（cloud.satellite.io/delete=true）→ 级联删除任务
//     （stages / artifacts / logs）；任务处于 running 时拒绝删除（Action=refused）；
//  2. 按 spec.scenarioName 解析场景（不存在则报错，提示先同步 SatelliteConstellation）；
//  3. 可选解析 spec.satelliteId（sat_id 或 stk_name，须属于该场景）；
//  4. 该场景下不存在同名任务 → 创建任务（pending）+ 10 个流水线阶段（pending）。
//     任务创建后由 rs-worker / od-worker 沿用既有 bootstrap 机制接管执行，
//     本同步只负责"声明期望"，不直接入队（与 REST 创建的"创建即执行"互补）；
//  5. 已存在同名任务：
//     - pending（尚未开始）：spec 输入参数与库中不一致时收敛更新（Action=updated），
//       一致则跳过（Action=skipped）；
//     - running / completed / failed：不改动运行时数据，跳过（Action=skipped）。
func ReconcileRemoteSensingTask(db *gorm.DB, cr *RemoteSensingTask, _ ReconcileOptions) (*RemoteSensingTaskReconcileResult, error) {
	if cr == nil {
		return nil, errors.New("nil manifest")
	}
	res := &RemoteSensingTaskReconcileResult{
		CRName:       cr.Metadata.Name,
		ScenarioName: cr.Spec.ScenarioName,
	}

	// 1. 删除注解分支
	if DeleteRequestedRemoteSensingTask(cr) {
		return deleteRemoteSensingTask(db, cr)
	}

	// 2. 解析所属场景（任务必须挂在已存在的场景下）
	var sc model.Scenario
	if err := db.Where("name = ?", cr.Spec.ScenarioName).First(&sc).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, fmt.Errorf("scenario %q not found: apply SatelliteConstellation first", cr.Spec.ScenarioName)
		}
		return nil, fmt.Errorf("query scenario %q: %w", cr.Spec.ScenarioName, err)
	}
	res.ScenarioID = sc.ID

	// 3. 解析目标卫星（可选）
	satID := ""
	if cr.Spec.SatelliteID != "" {
		sat, err := resolveTaskSatellite(db, sc.ID, cr.Spec.SatelliteID)
		if err != nil {
			return nil, err
		}
		satID = sat.SatID
	}
	res.SatelliteID = satID

	// 4. 幂等查找：同场景 + 同名
	var existing model.RemoteSensingTask
	err := db.Where("name = ? AND scenario_id = ?", cr.Metadata.Name, sc.ID).First(&existing).Error
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, fmt.Errorf("query task %q: %w", cr.Metadata.Name, err)
	}

	// 5. 不存在 → 创建
	if errors.Is(err, gorm.ErrRecordNotFound) {
		task, createErr := createRemoteSensingTask(db, sc, cr, satID)
		if createErr != nil {
			return nil, createErr
		}
		res.TaskName = task.Name
		res.Status = task.Status
		res.Action = "created"
		return res, nil
	}

	// 6. 已存在 → 按运行时状态收敛
	res.TaskName = existing.Name
	res.Status = existing.Status
	res.CurrentStage = existing.CurrentStage
	res.ErrorMessage = existing.ErrorMessage

	if existing.Status != remotesensing.TaskStatusPending {
		// running / completed / failed：不改动运行时数据
		res.Action = "skipped"
		return res, nil
	}

	// pending：spec 输入参数收敛（不改动 status / stages / 执行相关字段）
	if remoteSensingTaskInputsEqual(existing, cr) {
		res.Action = "skipped"
		return res, nil
	}
	updates := map[string]interface{}{
		"input_directory":        cr.Spec.InputDirectory,
		"file_prefix":            cr.Spec.FilePrefix,
		"sensor":                 cr.Spec.Sensor,
		"enable_detection":       desiredEnableDetection(cr),
		"detection_classes":      cr.Spec.DetectionClasses,
		"detection_draw_labels":  desiredDrawLabels(cr),
		"updated_at":             time.Now().UTC(),
	}
	if err := db.Model(&model.RemoteSensingTask{}).Where("id = ?", existing.ID).Updates(updates).Error; err != nil {
		return nil, fmt.Errorf("update task %q: %w", cr.Metadata.Name, err)
	}
	res.Action = "updated"
	return res, nil
}

// resolveTaskSatellite 按 sat_id 或 stk_name 解析场景下的卫星。
func resolveTaskSatellite(db *gorm.DB, scenarioID uint, idOrStk string) (*model.Satellite, error) {
	var sat model.Satellite
	err := db.Where("scenario_id = ? AND (sat_id = ? OR stk_name = ?)", scenarioID, idOrStk, idOrStk).First(&sat).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, fmt.Errorf("satellite %q not found in scenario (id=%d): apply SatelliteConstellation first", idOrStk, scenarioID)
		}
		return nil, fmt.Errorf("query satellite %q: %w", idOrStk, err)
	}
	return &sat, nil
}

// createRemoteSensingTask 创建任务主记录 + 10 个流水线阶段（全部 pending）。
// 不直接入队执行：pending 任务由 rs-worker 启动时的 bootstrap 机制接管。
func createRemoteSensingTask(db *gorm.DB, sc model.Scenario, cr *RemoteSensingTask, satID string) (*model.RemoteSensingTask, error) {
	now := time.Now().UTC()
	task := model.RemoteSensingTask{
		Name:                 cr.Metadata.Name,
		Status:               remotesensing.TaskStatusPending,
		InputDirectory:       cr.Spec.InputDirectory,
		FilePrefix:           cr.Spec.FilePrefix,
		Sensor:               cr.Spec.Sensor,
		EnableDetection:      desiredEnableDetection(cr),
		DetectionClasses:     cr.Spec.DetectionClasses,
		DetectionDrawLabels:  desiredDrawLabels(cr),
		ScenarioID:           &sc.ID,
		CreatedAt:            now,
		UpdatedAt:            now,
	}
	if satID != "" {
		sat, err := resolveTaskSatellite(db, sc.ID, satID)
		if err != nil {
			return nil, err
		}
		satIDUint := sat.ID
		task.SatelliteID = &satIDUint
	}
	if err := db.Create(&task).Error; err != nil {
		return nil, fmt.Errorf("create task %q: %w", cr.Metadata.Name, err)
	}

	for _, def := range remotesensing.StageDefinitions() {
		stage := model.RemoteSensingTaskStage{
			TaskID:    task.ID,
			Name:      def.Name,
			Title:     def.Title,
			Order:     def.Order,
			Status:    remotesensing.StagePending,
			CreatedAt: now,
			UpdatedAt: now,
		}
		if err := db.Create(&stage).Error; err != nil {
			return nil, fmt.Errorf("create stage %q for task %q: %w", def.Name, cr.Metadata.Name, err)
		}
	}
	return &task, nil
}

// deleteRemoteSensingTask 按删除注解级联删除任务；running 状态拒绝删除。
func deleteRemoteSensingTask(db *gorm.DB, cr *RemoteSensingTask) (*RemoteSensingTaskReconcileResult, error) {
	res := &RemoteSensingTaskReconcileResult{
		CRName:       cr.Metadata.Name,
		ScenarioName: cr.Spec.ScenarioName,
	}

	var sc model.Scenario
	if err := db.Where("name = ?", cr.Spec.ScenarioName).First(&sc).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, fmt.Errorf("scenario %q not found: apply SatelliteConstellation first", cr.Spec.ScenarioName)
		}
		return nil, fmt.Errorf("query scenario %q: %w", cr.Spec.ScenarioName, err)
	}
	res.ScenarioID = sc.ID

	var task model.RemoteSensingTask
	if err := db.Where("name = ? AND scenario_id = ?", cr.Metadata.Name, sc.ID).First(&task).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			res.Action = "notfound" // 幂等：目标已不存在视为完成
			return res, nil
		}
		return nil, fmt.Errorf("query task %q: %w", cr.Metadata.Name, err)
	}
	res.TaskName = task.Name
	res.Status = task.Status
	res.CurrentStage = task.CurrentStage

	if task.Status == remotesensing.TaskStatusRunning {
		res.Action = "refused"
		res.Referenced = true
		return res, nil
	}

	// 级联清理子表
	if err := db.Where("task_id = ?", task.ID).Delete(&model.RemoteSensingTaskStage{}).Error; err != nil {
		return nil, fmt.Errorf("delete stages of task %q: %w", task.Name, err)
	}
	if err := db.Where("task_id = ?", task.ID).Delete(&model.RemoteSensingTaskArtifact{}).Error; err != nil {
		return nil, fmt.Errorf("delete artifacts of task %q: %w", task.Name, err)
	}
	if err := db.Where("task_id = ?", task.ID).Delete(&model.RemoteSensingTaskLog{}).Error; err != nil {
		return nil, fmt.Errorf("delete logs of task %q: %w", task.Name, err)
	}
	if err := db.Delete(&task).Error; err != nil {
		return nil, fmt.Errorf("delete task %q: %w", task.Name, err)
	}
	res.Action = "deleted"
	return res, nil
}

// remoteSensingTaskInputsEqual 判断 CR spec 输入参数与库中 pending 任务是否一致。
func remoteSensingTaskInputsEqual(t model.RemoteSensingTask, cr *RemoteSensingTask) bool {
	return t.FilePrefix == cr.Spec.FilePrefix &&
		t.InputDirectory == cr.Spec.InputDirectory &&
		t.Sensor == cr.Spec.Sensor &&
		t.EnableDetection == desiredEnableDetection(cr) &&
		t.DetectionClasses == cr.Spec.DetectionClasses &&
		t.DetectionDrawLabels == desiredDrawLabels(cr)
}

// desiredEnableDetection 返回目标识别开关（缺省 true，与 CreateTaskRequest 默认一致）。
func desiredEnableDetection(cr *RemoteSensingTask) bool {
	if cr.Spec.EnableDetection != nil {
		return *cr.Spec.EnableDetection
	}
	return true
}

// desiredDrawLabels 返回检测标注框开关（缺省 false）。
func desiredDrawLabels(cr *RemoteSensingTask) bool {
	if cr.Spec.DetectionDrawLabels != nil {
		return *cr.Spec.DetectionDrawLabels
	}
	return false
}
