pcl@k8s-master:~$ kubectl -n gitlab-runner describe pod satellite-backend-6dd5ccf4f8-g2t79 | sed -n '/State:/,/Events:/p'
    State:          Terminated
      Reason:       Completed
      Exit Code:    0
      Started:      Mon, 20 Apr 2026 14:32:11 +0800
      Finished:     Mon, 20 Apr 2026 14:32:11 +0800
    Ready:          True
    Restart Count:  0
    Environment:
      SATELLITE_REMOTE_SENSING_PAN_RPC_PARALLELISM:     3
      SATELLITE_REMOTE_SENSING_PANSHARPEN_PARALLELISM:  2
    Mounts:
      /mnt from remote-sensing-data (rw)
      /scratch/output_preprocessing from remote-sensing-scratch-output (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-shjc9 (ro)
Containers:
  satellite-backend:
    Container ID:   containerd://978c8faee5b80be1c81b03774ce496f2e44c45d64d04333e294d5b06eb65ff95
    Image:          192.168.10.238/satellite/backend:b2e40377
    Image ID:       192.168.10.238/satellite/backend@sha256:22aae0efc498a67a2082282b82e4e0cd94fc17f39cfe62738cc494b988c3ec84
    Port:           8080/TCP
    Host Port:      0/TCP
    State:          Terminated
      Reason:       Error
      Exit Code:    1
      Started:      Mon, 20 Apr 2026 14:32:40 +0800
      Finished:     Mon, 20 Apr 2026 15:02:39 +0800
    Ready:          False
    Restart Count:  0
    Limits:
      cpu:     2
      memory:  4Gi
    Requests:
      cpu:      300m
      memory:   1Gi
    Liveness:   http-get http://:8080/health delay=10s timeout=3s period=30s #success=1 #failure=3
    Readiness:  http-get http://:8080/ready delay=5s timeout=3s period=10s #success=1 #failure=3
    Environment:
      SATELLITE_SERVER_PORT:                             8080
      SATELLITE_SERVER_MODE:                             production
      SATELLITE_DATABASE_HOST:                           <set to the key 'host' in secret 'satellite-db-secret'>  Optional: false
      SATELLITE_DATABASE_PORT:                           5432
      SATELLITE_DATABASE_USER:                           <set to the key 'user' in secret 'satellite-db-secret'>      Optional: false
      SATELLITE_DATABASE_PASSWORD:                       <set to the key 'password' in secret 'satellite-db-secret'>  Optional: false
      SATELLITE_DATABASE_DBNAME:                         <set to the key 'dbname' in secret 'satellite-db-secret'>    Optional: false
      SATELLITE_LOG_LEVEL:                               info
      SATELLITE_TOPOLOGY_AUTO_IMPORT:                    <set to the key 'SATELLITE_TOPOLOGY_AUTO_IMPORT' in secret 'satellite-backend-env'>  Optional: false
      SATELLITE_TOPOLOGY_SCENARIO:                       <set to the key 'SATELLITE_TOPOLOGY_SCENARIO' in secret 'satellite-backend-env'>     Optional: false
      SATELLITE_DELAY_CSV:                               <set to the key 'SATELLITE_DELAY_CSV' in secret 'satellite-backend-env'>             Optional: false
      SATELLITE_REMOTE_SENSING_ROOT:                     /opt/remote-sensing
      SATELLITE_REMOTE_SENSING_PYTHON:                   /opt/remote-sensing/.venv/bin/python
      SATELLITE_REMOTE_SENSING_DEM_FILE:                 /opt/remote-sensing-data/dem/GMTED2010.jp2
      SATELLITE_REMOTE_SENSING_PERSIST_OUTPUT_DIR:       persist_output_preprocessing
      SATELLITE_REMOTE_SENSING_PAN_RPC_PARALLELISM:      2
      SATELLITE_REMOTE_SENSING_PAN_RPC_CPU_THREADS:      1
      SATELLITE_REMOTE_SENSING_PANSHARPEN_PARALLELISM:   3
      SATELLITE_REMOTE_SENSING_PANSHARPEN_GDAL_THREADS:  1
    Mounts:
      /opt/remote-sensing-data/dem from remote-sensing-data (rw,path="dem")
      /opt/remote-sensing/input from remote-sensing-data (rw,path="input")
      /opt/remote-sensing/output_preprocessing from remote-sensing-scratch-output (rw)
      /opt/remote-sensing/persist_output_preprocessing from remote-sensing-data (rw,path="output_preprocessing")
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-shjc9 (ro)
Conditions:
  Type               Status
  DisruptionTarget   True 
  Initialized        True 
  Ready              False 
  ContainersReady    False 
  PodScheduled       True 
Volumes:
  remote-sensing-data:
    Type:       PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
    ClaimName:  remote-sensing-data
    ReadOnly:   false
  remote-sensing-scratch-output:
    Type:       EmptyDir (a temporary directory that shares a pod's lifetime)
    Medium:     
    SizeLimit:  <unset>
  kube-api-access-shjc9:
    Type:                    Projected (a volume that contains injected data from multiple sources)
    TokenExpirationSeconds:  3607
    ConfigMapName:           kube-root-ca.crt
    ConfigMapOptional:       <nil>
    DownwardAPI:             true
QoS Class:                   Burstable
Node-Selectors:              <none>
Tolerations:                 node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                             node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
Events:                      <none>
pcl@k8s-master:~$ kubectl -n gitlab-runner logs satellite-backend-6dd5ccf4f8-g2t79 --previous --tail=200
Defaulted container "satellite-backend" out of: satellite-backend, init-remote-sensing-dirs (init)
Error from server (BadRequest): previous terminated container "satellite-backend" in pod "satellite-backend-6dd5ccf4f8-g2t79" not found
pcl@k8s-master:~$ kubectl -n gitlab-runner logs satellite-backend-6dd5ccf4f8-g2t79 --tail=200
Defaulted container "satellite-backend" out of: satellite-backend, init-remote-sensing-dirs (init)
unable to retrieve container logs for containerd://978c8faee5b80be1c81b03774ce496f2e44c45d64d04333e294d5b06eb65ff95