cat <<EOF > kind-cluster.yaml
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
nodes:
- role: control-plane
- role: worker
- role: worker
- role: worker
EOF

kind create cluster \
  --config kind-cluster.yaml \
  --name vault
