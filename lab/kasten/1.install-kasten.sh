# Install Kubernetes with kind
kind create cluster \
  --name k10-demo \
  --image kindest/node:v1.18.2 \
  --wait 600s

# Install a recent version of the CSI snapshotter
SNAPSHOTTER_VERSION=v2.1.1

SNAPSHOTTER_BASE_URL="raw.githubusercontent.com/kubernetes-csi/external-snapshotter/${SNAPSHOTTER_VERSION}"

# Apply VolumeSnapshot CRDs
kubectl apply -f https://${SNAPSHOTTER_BASE_URL}/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
kubectl apply -f https://${SNAPSHOTTER_BASE_URL}/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
kubectl apply -f https://${SNAPSHOTTER_BASE_URL}/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml

# Create Snapshot Controller
kubectl apply -f https://${SNAPSHOTTER_BASE_URL}/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml
kubectl apply -f https://${SNAPSHOTTER_BASE_URL}/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml

# Install the CSI Hostpath Driver
git clone https://github.com/kubernetes-csi/csi-driver-host-path.git
cd csi-driver-host-path
./deploy/kubernetes-1.18/deploy.sh

# After the install is complete, add the CSI Hostpath Driver StorageClass and make it the default
kubectl apply -f ./examples/csi-storageclass.yaml
kubectl patch storageclass standard \
    -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
kubectl patch storageclass csi-hostpath-sc \
    -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Installing K10
helm install k10 kasten/k10 --namespace=kasten-io

# Annotate the CSI Hostpath VolumeSnapshotClass for use with K10
kubectl annotate volumesnapshotclass csi-hostpath-snapclass \
    k10.kasten.io/is-snapshot-class=true

kubectl get pods --namespace kasten-io

# Validate Dashboard Access
kubectl --namespace kasten-io port-forward service/gateway 8080:8000

# Validate Dashboard Access
# The K10 dashboard will be available at http://127.0.0.1:8080/k10/#/.
