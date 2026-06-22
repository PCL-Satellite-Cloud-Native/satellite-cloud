package argo

import (
	"context"
	"fmt"
	"time"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime/schema"
	"k8s.io/client-go/dynamic"
	"k8s.io/client-go/rest"
)

var workflowGVR = schema.GroupVersionResource{
	Group:    "argoproj.io",
	Version:  "v1alpha1",
	Resource: "workflows",
}

// Client 提交并监视 Argo Workflow（集群内 InClusterConfig）
type Client struct {
	namespace string
	dyn       dynamic.Interface
}

// NewInCluster 创建集群内 Argo 客户端
func NewInCluster(namespace string) (*Client, error) {
	cfg, err := rest.InClusterConfig()
	if err != nil {
		return nil, fmt.Errorf("InClusterConfig: %w", err)
	}
	dyn, err := dynamic.NewForConfig(cfg)
	if err != nil {
		return nil, fmt.Errorf("dynamic client: %w", err)
	}
	if namespace == "" {
		namespace = "gitlab-runner"
	}
	return &Client{namespace: namespace, dyn: dyn}, nil
}

// PanRPCWorkflowParams 与 rs-worker PAN RPC 配置及 WorkflowTemplate 参数对齐
type PanRPCWorkflowParams struct {
	TemplateName string
	TaskID       uint
	FilePrefix   string
	RSImage      string
	CPUThreads   int
	WarpMemMB    int
	ResampleAlg  string
}

// SubmitPanRPCWorkflow 基于 WorkflowTemplate 提交 PAN RPC 并行任务
func (c *Client) SubmitPanRPCWorkflow(ctx context.Context, p PanRPCWorkflowParams) (string, error) {
	if p.ResampleAlg == "" {
		p.ResampleAlg = "near"
	}
	if p.WarpMemMB <= 0 {
		p.WarpMemMB = 512
	}
	if p.CPUThreads <= 0 {
		p.CPUThreads = 1
	}
	labels := map[string]interface{}{
		"satellite.io/task-id": fmt.Sprintf("%d", p.TaskID),
		"satellite.io/stage":   "pan_rpc_warp_quarters",
	}
	wf := &unstructured.Unstructured{
		Object: map[string]interface{}{
			"apiVersion": "argoproj.io/v1alpha1",
			"kind":       "Workflow",
			"metadata": map[string]interface{}{
				"generateName": fmt.Sprintf("rs-pan-rpc-%d-", p.TaskID),
				"namespace":    c.namespace,
				"labels":       labels,
			},
			"spec": map[string]interface{}{
				"serviceAccountName": "argo-workflow",
				"workflowTemplateRef": map[string]interface{}{
					"name": p.TemplateName,
				},
				"arguments": map[string]interface{}{
					"parameters": []interface{}{
						map[string]interface{}{"name": "task_id", "value": fmt.Sprintf("%d", p.TaskID)},
						map[string]interface{}{"name": "file_prefix", "value": p.FilePrefix},
						map[string]interface{}{"name": "rs_image", "value": p.RSImage},
						map[string]interface{}{"name": "cpu_threads", "value": fmt.Sprintf("%d", p.CPUThreads)},
						map[string]interface{}{"name": "warp_mem_mb", "value": fmt.Sprintf("%d", p.WarpMemMB)},
						map[string]interface{}{"name": "resample_alg", "value": p.ResampleAlg},
					},
				},
			},
		},
	}
	created, err := c.dyn.Resource(workflowGVR).Namespace(c.namespace).Create(ctx, wf, metav1.CreateOptions{})
	if err != nil {
		return "", fmt.Errorf("create workflow: %w", err)
	}
	name, _, _ := unstructured.NestedString(created.Object, "metadata", "name")
	if name == "" {
		return "", fmt.Errorf("workflow created without name")
	}
	return name, nil
}

// WaitWorkflowCompleted 轮询直到 Succeeded / Failed / 超时
func (c *Client) WaitWorkflowCompleted(ctx context.Context, name string, pollInterval time.Duration) error {
	if pollInterval <= 0 {
		pollInterval = 5 * time.Second
	}
	ticker := time.NewTicker(pollInterval)
	defer ticker.Stop()
	for {
		wf, err := c.dyn.Resource(workflowGVR).Namespace(c.namespace).Get(ctx, name, metav1.GetOptions{})
		if err != nil {
			return fmt.Errorf("get workflow %s: %w", name, err)
		}
		phase, _, _ := unstructured.NestedString(wf.Object, "status", "phase")
		switch phase {
		case "Succeeded":
			return nil
		case "Failed", "Error":
			msg, _, _ := unstructured.NestedString(wf.Object, "status", "message")
			return fmt.Errorf("workflow %s phase=%s message=%s", name, phase, msg)
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-ticker.C:
		}
	}
}
