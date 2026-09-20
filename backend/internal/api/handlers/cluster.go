package handlers

import (
	"context"
	"sort"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

	"go.uber.org/zap"

	"satellite-cloud/backend/internal/k8snode"
)

// ClusterNodeStatus 描述单个 k3s 节点的健康状态，
// 用于主页面「星座仿真系统 / 卫星网络拓扑」把卫星与集群节点一一对应并着色。
type ClusterNodeStatus struct {
	Name       string   `json:"name"`                  // 节点名，如 k3s-master07
	Ready      bool     `json:"ready"`                 // Ready 条件是否为 True
	Status     string   `json:"status"`                // Ready / NotReady / Unknown
	Reason     string   `json:"reason,omitempty"`      // 条件 Reason / Message
	Roles      []string `json:"roles,omitempty"`       // control-plane / worker
	InternalIP string   `json:"internal_ip,omitempty"` // 节点内部 IP
}

// ClusterHandler 暴露集群节点状态。
type ClusterHandler struct {
	logger *zap.Logger
}

func NewClusterHandler(logger *zap.Logger) *ClusterHandler {
	return &ClusterHandler{logger: logger}
}

// ListNodesHandler 返回集群所有节点及其 Ready 状态。
//
// GET /api/cluster/nodes
//
// 节点状态：Ready=true 表示节点正常（绿色/白色可用）；Ready=false 表示节点
// NotReady 或不可达（前端渲染为红色「错误/无法连通」）。后端使用 in-cluster
// ServiceAccount 访问 API Server，需要 nodes 的 get/list/watch 权限。
func (h *ClusterHandler) ListNodes(c *gin.Context) {
	client, err := k8snode.KubeClient()
	if err != nil {
		h.logger.Warn("k8s client unavailable, cannot list nodes", zap.Error(err))
		c.JSON(200, gin.H{
			"available": false,
			"nodes":     []ClusterNodeStatus{},
			"message":   "后端未运行于集群内或无法访问 API Server",
		})
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
	defer cancel()

	nodeList, err := client.CoreV1().Nodes().List(ctx, metav1.ListOptions{})
	if err != nil {
		h.logger.Error("failed to list nodes", zap.Error(err))
		c.JSON(500, gin.H{"error": "无法获取集群节点: " + err.Error()})
		return
	}

	nodes := make([]ClusterNodeStatus, 0, len(nodeList.Items))
	for _, n := range nodeList.Items {
		cn := ClusterNodeStatus{
			Name:   n.Name,
			Ready:  true,
			Status: "Ready",
		}
		for _, addr := range n.Status.Addresses {
			if addr.Type == "InternalIP" {
				cn.InternalIP = addr.Address
			}
		}
		for _, t := range n.Status.Conditions {
			if t.Type == "Ready" {
				if t.Status != "True" {
					cn.Ready = false
					cn.Status = "NotReady"
				}
				if t.Reason != "" {
					cn.Reason = t.Reason
				}
				if cn.Reason == "" && t.Message != "" {
					cn.Reason = t.Message
				}
				break
			}
		}

		roles := make([]string, 0)
		for k := range n.Labels {
			if strings.HasPrefix(k, "node-role.kubernetes.io/") {
				role := strings.TrimPrefix(k, "node-role.kubernetes.io/")
				if role == "" {
					role = "control-plane"
				}
				roles = append(roles, role)
			}
		}
		if len(roles) == 0 {
			roles = append(roles, "worker")
		}
		sort.Strings(roles)
		cn.Roles = roles

		nodes = append(nodes, cn)
	}

	sort.Slice(nodes, func(i, j int) bool {
		return nodes[i].Name < nodes[j].Name
	})

	c.JSON(200, gin.H{
		"available": true,
		"count":     len(nodes),
		"nodes":     nodes,
	})
}
