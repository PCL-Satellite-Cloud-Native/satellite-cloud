package declarative

import (
	"errors"
	"fmt"
	"time"

	"gorm.io/gorm"

	"satellite-cloud/backend/internal/model"
	"satellite-cloud/backend/internal/objectdetection"
)

// ObjectDetectionTaskReconcileResult 汇报目标检测任务声明式同步的结果。
type ObjectDetectionTaskReconcileResult struct {
	// CRName 清单 metadata.name。
	CRName string
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

// ReconcileObjectDetectionTask 把一份 ObjectDetectionTask CR 同步到 PostgreSQL（幂等）。
//
// 同步语义：
//  1. 带删除注解（cloud.satellite.io/delete=true）→ 级联删除任务
//     （stages / artifacts / logs）；任务处于 running 时拒绝删除（Action=refused）；
//  2. 按 metadata.name 幂等查找（目标检测任务不挂场景，name 全局唯一）；
//  3. 不存在同名任务 → 创建任务（pending）+ 检测阶段（detect, pending）。
//     任务创建后由后端 ObjectDetectionService 启动时的 bootstrap 机制接管执行，
//     本同步只负责"声明期望"，不直接入队（与 REST 创建的"创建即执行"互补）；
//  4. 已存在同名任务：
//     - pending（尚未开始）：spec 输入参数与库中不一致时收敛更新（Action=updated），
//     一致则跳过（Action=skipped）；
//     - running / completed / failed：不改动运行时数据，跳过（Action=skipped）。
func ReconcileObjectDetectionTask(db *gorm.DB, cr *ObjectDetectionTask, _ ReconcileOptions) (*ObjectDetectionTaskReconcileResult, error) {
	if cr == nil {
		return nil, errors.New("nil manifest")
	}
	res := &ObjectDetectionTaskReconcileResult{
		CRName: cr.Metadata.Name,
	}

	// 1. 删除注解分支
	if DeleteRequestedObjectDetectionTask(cr) {
		return deleteObjectDetectionTask(db, cr)
	}

	// 2. 幂等查找：name 全局唯一
	var existing model.ObjectDetectionTask
	err := db.Where("name = ?", cr.Metadata.Name).First(&existing).Error
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, fmt.Errorf("query task %q: %w", cr.Metadata.Name, err)
	}

	// 3. 不存在 → 创建
	if errors.Is(err, gorm.ErrRecordNotFound) {
		task, createErr := createObjectDetectionTask(db, cr)
		if createErr != nil {
			return nil, createErr
		}
		res.TaskName = task.Name
		res.Status = task.Status
		res.Action = "created"
		return res, nil
	}

	// 4. 已存在 → 按运行时状态收敛
	res.TaskName = existing.Name
	res.Status = existing.Status
	res.CurrentStage = existing.CurrentStage
	res.ErrorMessage = existing.ErrorMessage

	if existing.Status != objectdetection.TaskStatusPending {
		// running / completed / failed：不改动运行时数据
		res.Action = "skipped"
		return res, nil
	}

	// pending：spec 输入参数收敛（不改动 status / stages / 执行相关字段）
	if objectDetectionTaskInputsEqual(existing, cr) {
		res.Action = "skipped"
		return res, nil
	}
	updates := map[string]interface{}{
		"input_path":  cr.Spec.InputPath,
		"classes":     cr.Spec.Classes,
		"draw_labels": desiredObjectDetectionDrawLabels(cr),
		"updated_at":  time.Now().UTC(),
	}
	if err := db.Model(&model.ObjectDetectionTask{}).Where("id = ?", existing.ID).Updates(updates).Error; err != nil {
		return nil, fmt.Errorf("update task %q: %w", cr.Metadata.Name, err)
	}
	res.Action = "updated"
	return res, nil
}

// createObjectDetectionTask 创建任务主记录 + 检测阶段（detect, pending）。
// 不直接入队执行：pending 任务由后端 ObjectDetectionService 启动时的 bootstrap 机制接管。
func createObjectDetectionTask(db *gorm.DB, cr *ObjectDetectionTask) (*model.ObjectDetectionTask, error) {
	now := time.Now().UTC()
	task := model.ObjectDetectionTask{
		Name:       cr.Metadata.Name,
		Status:     objectdetection.TaskStatusPending,
		InputPath:  cr.Spec.InputPath,
		Classes:    cr.Spec.Classes,
		DrawLabels: desiredObjectDetectionDrawLabels(cr),
		CreatedAt:  now,
		UpdatedAt:  now,
	}
	if err := db.Create(&task).Error; err != nil {
		return nil, fmt.Errorf("create task %q: %w", cr.Metadata.Name, err)
	}

	for _, def := range objectdetection.StageDefinitions() {
		stage := model.ObjectDetectionTaskStage{
			TaskID:    task.ID,
			Name:      def.Name,
			Title:     def.Title,
			Order:     def.Order,
			Status:    objectdetection.StagePending,
			CreatedAt: now,
			UpdatedAt: now,
		}
		if err := db.Create(&stage).Error; err != nil {
			return nil, fmt.Errorf("create stage %q for task %q: %w", def.Name, cr.Metadata.Name, err)
		}
	}
	return &task, nil
}

// deleteObjectDetectionTask 按删除注解级联删除任务；running 状态拒绝删除。
func deleteObjectDetectionTask(db *gorm.DB, cr *ObjectDetectionTask) (*ObjectDetectionTaskReconcileResult, error) {
	res := &ObjectDetectionTaskReconcileResult{
		CRName: cr.Metadata.Name,
	}

	var task model.ObjectDetectionTask
	if err := db.Where("name = ?", cr.Metadata.Name).First(&task).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			res.Action = "notfound" // 幂等：目标已不存在视为完成
			return res, nil
		}
		return nil, fmt.Errorf("query task %q: %w", cr.Metadata.Name, err)
	}
	res.TaskName = task.Name
	res.Status = task.Status
	res.CurrentStage = task.CurrentStage

	if task.Status == objectdetection.TaskStatusRunning {
		res.Action = "refused"
		res.Referenced = true
		return res, nil
	}

	// 级联清理子表
	if err := db.Where("task_id = ?", task.ID).Delete(&model.ObjectDetectionTaskStage{}).Error; err != nil {
		return nil, fmt.Errorf("delete stages of task %q: %w", task.Name, err)
	}
	if err := db.Where("task_id = ?", task.ID).Delete(&model.ObjectDetectionTaskArtifact{}).Error; err != nil {
		return nil, fmt.Errorf("delete artifacts of task %q: %w", task.Name, err)
	}
	if err := db.Where("task_id = ?", task.ID).Delete(&model.ObjectDetectionTaskLog{}).Error; err != nil {
		return nil, fmt.Errorf("delete logs of task %q: %w", task.Name, err)
	}
	if err := db.Delete(&task).Error; err != nil {
		return nil, fmt.Errorf("delete task %q: %w", task.Name, err)
	}
	res.Action = "deleted"
	return res, nil
}

// objectDetectionTaskInputsEqual 判断 CR spec 输入参数与库中 pending 任务是否一致。
func objectDetectionTaskInputsEqual(t model.ObjectDetectionTask, cr *ObjectDetectionTask) bool {
	return t.InputPath == cr.Spec.InputPath &&
		t.Classes == cr.Spec.Classes &&
		t.DrawLabels == desiredObjectDetectionDrawLabels(cr)
}

// desiredObjectDetectionDrawLabels 返回检测标注框开关（缺省 false）。
func desiredObjectDetectionDrawLabels(cr *ObjectDetectionTask) bool {
	if cr.Spec.DrawLabels != nil {
		return *cr.Spec.DrawLabels
	}
	return false
}
