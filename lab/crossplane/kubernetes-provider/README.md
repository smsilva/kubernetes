# Crossplane Kubernetes Provider Example

## TLDR

```bash
# Terminal [1]: Following Configuration Progress

watch -n 3 scripts/show-configuration-progress.sh

# Terminal [2]: Main Steps - Bootstrap

../install/create-kind-cluster.sh

../install/install-crossplane-helm-chart.sh

# Terminal [2]: Create Configurations

kubectl apply -f provider/controller-config-debug.yaml

kubectl apply -f provider/provider.yaml && \
kubectl wait Provider provider-kubernetes \
  --for=condition=Healthy \
  --timeout=120s

CROSSPLANE_KUBERNETES_PROVIDER_SERVICE_ACCOUNT=$(kubectl \
  --namespace crossplane-system \
  get serviceaccount \
  --output name | grep provider-kubernetes | sed -e 's|serviceaccount\/||g') && \
echo "${CROSSPLANE_KUBERNETES_PROVIDER_SERVICE_ACCOUNT?}" && \
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: provider-kubernetes-admin-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: ${CROSSPLANE_KUBERNETES_PROVIDER_SERVICE_ACCOUNT?}
  namespace: crossplane-system
EOF

kubectl apply -f provider/config/provider-config.yaml

# Terminal [2]: Following Crossplane Provider Logs 

CROSSPLANE_PRODIVER_POD_NAME="$(kubectl \
  --namespace crossplane-system \
  get pods \
   --output jsonpath="{range .items[*]}{.metadata.name}{'\n'}{end}" | grep provider-kubernetes)" && \
echo "${CROSSPLANE_PRODIVER_POD_NAME?}" && \
kubectl \
  --namespace crossplane-system \
  wait pod "${CROSSPLANE_PRODIVER_POD_NAME?}" \
  --for=condition=Ready \
  --timeout=120s && \
kubectl \
  --namespace crossplane-system \
  logs --follow "${CROSSPLANE_PRODIVER_POD_NAME?}"

# Terminal [1]: CTRL + C / Following Provision Progress

watch -n 3 scripts/show-provision-progress.sh

# Terminal [3]: Create Claims

helm template helm/clusters/ | kubectl apply -f -

# Job Test
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: pi
spec:
  template:
    spec:
      containers:
      - name: pi
        image: perl
        command: ["perl",  "-Mbignum=bpi", "-wle", "print bpi(2000)"]
      restartPolicy: Never
  backoffLimit: 4
EOF

kind delete cluster --name crossplane

```
