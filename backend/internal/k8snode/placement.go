package k8snode

import (
	"context"
	"os"
	"sync"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"

	"satellite-cloud/backend/internal/pilotcluster"
)

const SatelliteIDLabel = "satellite.io/id"

// Placement 当前 Pod 所在节点及节点上的卫星标识。
type Placement struct {
	NodeName      string
	ExecutedSatID string
}

var (
	clientOnce sync.Once
	k8sClient  kubernetes.Interface
	clientErr  error
)

func kubeClient() (kubernetes.Interface, error) {
	clientOnce.Do(func() {
		cfg, err := rest.InClusterConfig()
		if err != nil {
			clientErr = err
			return
		}
		k8sClient, clientErr = kubernetes.NewForConfig(cfg)
	})
	return k8sClient, clientErr
}

// CurrentPlacement 读取 NODE_NAME 环境变量并查询节点 satellite.io/id 标签。
func CurrentPlacement(ctx context.Context) Placement {
	nodeName := os.Getenv("NODE_NAME")
	if nodeName == "" {
		return Placement{}
	}
	p := Placement{NodeName: nodeName}
	client, err := kubeClient()
	if err != nil {
		return p
	}
	node, err := client.CoreV1().Nodes().Get(ctx, nodeName, metav1.GetOptions{})
	if err != nil {
		return p
	}
	if satID := node.Labels[SatelliteIDLabel]; satID != "" {
		p.ExecutedSatID = satID
	}
	if p.ExecutedSatID == "" {
		if satID := pilotcluster.Current().SatIDForNode(nodeName); satID != "" {
			p.ExecutedSatID = satID
		}
	}
	return p
}
