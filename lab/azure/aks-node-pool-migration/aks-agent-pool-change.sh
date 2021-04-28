AZ_SUBSCRIPTION="Azure Subscription"
AKS_CLUSTER_NAME="silvios-dev-eastus2"
AKS_CLUSTER_RESOURCE_GROUP_NAME="silvios-dev-eastus2"

# Define the Default Azure Subscription
az account set -s "${AZ_SUBSCRIPTION}"

AKS_TEMPORARY_SYSTEM_NODE_POOL_NAME="systempool"
AKS_CLUSTER_SYSTEM_NODE_POOL_MAX_PODS="100"
AKS_CLUSTER_INFORMATION_JSON_FILE="$(date '+%Y-%m-%d_%H-%M-%S')_${AKS_CLUSTER_NAME}.json"

# Retrieve AKS Cluster Information and Store it in a Json File and review it on VS Code
az aks show \
  --name "${AKS_CLUSTER_NAME}" \
  --resource-group "${AKS_CLUSTER_RESOURCE_GROUP_NAME}" -o json | tee "${AKS_CLUSTER_INFORMATION_JSON_FILE}"

# Set the Environment Variables with actual Sytem Node Pool named agentpool
COLUMN_LIST_MAPPING="{\
AKS_NODE_POOL_AVAILABILITY_ZONES: .availabilityZones,\
AKS_NODE_POOL_VNET_SUBNET_ID: .vnetSubnetId,\
AKS_NODE_POOL_VM_SIZE: .vmSize,\
AKS_NODE_POOL_OS_DISK_SIZE_GB: .osDiskSizeGb,\
AKS_NODE_POOL_COUNT: .count,\
AKS_NODE_POOL_MIN_COUNT: .minCount,\
AKS_NODE_POOL_MAX_COUNT: .maxCount,\
AKS_NODE_POOL_ENABLE_AUTOS_SCALING: .enableAutoScaling\
}"

# Mount jq command using Column List Mapping
JQ_COMMAND=$(printf '.[] | %s | to_entries|map("export \(.key)=\(.value|tostring)")|.[]' "${COLUMN_LIST_MAPPING}")

# Set the Environment Variables with actual System Node Pool (agentpool) parameters
eval $(
az aks show \
  --name "${AKS_CLUSTER_NAME}" \
  --resource-group "${AKS_CLUSTER_RESOURCE_GROUP_NAME}" \
  --query "agentPoolProfiles[?name == 'agentpool']" \
  --output json | jq -r "${JQ_COMMAND}"
)

export AKS_NODE_POOL_AVAILABILITY_ZONES=$(sed 's/\[//; s/\]//; s/,/ /;' <<< ${AKS_NODE_POOL_AVAILABILITY_ZONES})

# Show the Environment Variables to review
echo "" && \
echo "AKS_CLUSTER_NAME......................: ${AKS_CLUSTER_NAME}" && \
echo "AKS_CLUSTER_RESOURCE_GROUP_NAME.......: ${AKS_CLUSTER_RESOURCE_GROUP_NAME}" && \
echo "AKS_CLUSTER_SYSTEM_NODE_POOL_MAX_PODS.: ${AKS_CLUSTER_SYSTEM_NODE_POOL_MAX_PODS}" && \
echo "AKS_NODE_POOL_AVAILABILITY_ZONES......: ${AKS_NODE_POOL_AVAILABILITY_ZONES}" && \
echo "AKS_NODE_POOL_VNET_SUBNET_ID..........: ${AKS_NODE_POOL_VNET_SUBNET_ID}" && \
echo "AKS_NODE_POOL_VM_SIZE.................: ${AKS_NODE_POOL_VM_SIZE}" && \
echo "AKS_NODE_POOL_OS_DISK_SIZE_GB.........: ${AKS_NODE_POOL_OS_DISK_SIZE_GB}" && \
echo "AKS_NODE_POOL_COUNT...................: ${AKS_NODE_POOL_COUNT}" && \
echo "AKS_NODE_POOL_MIN_COUNT...............: ${AKS_NODE_POOL_MIN_COUNT}" && \
echo "AKS_NODE_POOL_MAX_COUNT...............: ${AKS_NODE_POOL_MAX_COUNT}" && \
echo "AKS_NODE_POOL_ENABLE_AUTOS_SCALING....: ${AKS_NODE_POOL_ENABLE_AUTOS_SCALING}" && \
echo ""

# Retrieve Node Pool List
az aks nodepool list \
  --cluster-name "${AKS_CLUSTER_NAME}" \
  --resource-group "${AKS_CLUSTER_RESOURCE_GROUP_NAME}" \
  --output table

# Create a New Temporary System Node Pool with the Same parameters from Actual System Default Node Pool but Max Pods increased to the value specified at AKS_CLUSTER_SYSTEM_NODE_POOL_MAX_PODS environment variable
az aks nodepool add \
  --zones ${AKS_NODE_POOL_AVAILABILITY_ZONES} \
  --mode "System" \
  --name "${AKS_TEMPORARY_SYSTEM_NODE_POOL_NAME}" \
  --cluster-name "${AKS_CLUSTER_NAME}" \
  --resource-group "${AKS_CLUSTER_RESOURCE_GROUP_NAME}" \
  --max-pods "${AKS_CLUSTER_SYSTEM_NODE_POOL_MAX_PODS}" \
  --node-vm-size "${AKS_NODE_POOL_VM_SIZE}" \
  --node-count "${AKS_NODE_POOL_COUNT}" \
  --min-count "${AKS_NODE_POOL_MIN_COUNT}" \
  --max-count "${AKS_NODE_POOL_MAX_COUNT}" \
  --enable-cluster-autoscaler \
  --node-osdisk-size "${AKS_NODE_POOL_OS_DISK_SIZE_GB}" \
  --node-osdisk-type Ephemeral \
  --vnet-subnet-id "${AKS_NODE_POOL_VNET_SUBNET_ID}"

# Node Pool with Ephemeral Disks
# https://docs.microsoft.com/en-us/azure/aks/cluster-configuration#use-ephemeral-os-on-existing-clusters

# Retrieve Node Pool List
az aks nodepool list \
  --cluster-name "${AKS_CLUSTER_NAME}" \
  --resource-group "${AKS_CLUSTER_RESOURCE_GROUP_NAME}" \
  --output table

Name        OsType    KubernetesVersion    VmSize            Count    MaxPods    ProvisioningState    Mode
----------  --------  -------------------  ----------------  -------  ---------  -------------------  ------
agentpool   Linux     1.17.7               Standard_D16s_v3  1        60         Succeeded            System
systempool  Linux     1.17.7               Standard_D16s_v3  1        100        Succeeded            System

# Prevent PODs from being schedule on agentpool
kubectl taint node -l agentpool="agentpool" CriticalAddonsOnly=true:NoSchedule

# Get Node Names
kubectl get nodes --no-headers -o custom-columns='NAME:.metadata.name' | grep "agentpool" | tee >(clip)

# Evict Pods from Default System Node Pool (Suggest do it one by one)
kubectl drain node-name \
  --ignore-daemonsets \
  --delete-local-data \
  --force

# Check for PODs still running on the Node Pool
watch -n 3 'kubectl get pods -o wide | grep agentpool | awk "{ print \$1, \$3 }" | column -t'

# Remove Default System Node Pool (agentpool)
az aks nodepool delete \
  --cluster-name "${AKS_CLUSTER_NAME}" \
  --resource-group "${AKS_CLUSTER_RESOURCE_GROUP_NAME}" \
  --name "agentpool"

# Retrieve Node Pool List
az aks nodepool list \
  --cluster-name "${AKS_CLUSTER_NAME}" \
  --resource-group "${AKS_CLUSTER_RESOURCE_GROUP_NAME}" \
  --output table

Name        OsType    KubernetesVersion    VmSize            Count    MaxPods    ProvisioningState    Mode
----------  --------  -------------------  ----------------  -------  ---------  -------------------  ------
systempool  Linux     1.17.7               Standard_D16s_v3  1        100        Succeeded            System

# Create a New System Node Pool (agentpool) with the Same parameters from Actual System Default Node Pool but Max Pods increased to 100
az aks nodepool add \
  --zones ${AKS_NODE_POOL_AVAILABILITY_ZONES} \
  --name "agentpool" \
  --mode "System" \
  --cluster-name "${AKS_CLUSTER_NAME}" \
  --resource-group "${AKS_CLUSTER_RESOURCE_GROUP_NAME}" \
  --max-pods "${AKS_CLUSTER_SYSTEM_NODE_POOL_MAX_PODS}" \
  --node-vm-size "${AKS_NODE_POOL_VM_SIZE}" \
  --node-count "${AKS_NODE_POOL_COUNT}" \
  --min-count "${AKS_NODE_POOL_MIN_COUNT}" \
  --max-count "${AKS_NODE_POOL_MAX_COUNT}" \
  --enable-cluster-autoscaler \
  --node-osdisk-size "${AKS_NODE_POOL_OS_DISK_SIZE_GB}" \
  --node-osdisk-type Ephemeral \
  --vnet-subnet-id "${AKS_NODE_POOL_VNET_SUBNET_ID}"

# Retrieve Node Pool List
az aks nodepool list \
  --cluster-name "${AKS_CLUSTER_NAME}" \
  --resource-group "${AKS_CLUSTER_RESOURCE_GROUP_NAME}" \
  --output table

Name        OsType    KubernetesVersion    VmSize            Count    MaxPods    ProvisioningState    Mode
----------  --------  -------------------  ----------------  -------  ---------  -------------------  ------
agentpool   Linux     1.17.7               Standard_D16s_v3  1        100        Succeeded            System
systempool  Linux     1.17.7               Standard_D16s_v3  1        100        Succeeded            System

# Prevent PODs from being schedule on that Nodes
kubectl taint node --selector agentpool="${AKS_TEMPORARY_SYSTEM_NODE_POOL_NAME}" CriticalAddonsOnly=true:NoSchedule

# Get Node Names
kubectl get nodes --no-headers -o custom-columns='NAME:.metadata.name' | grep "${AKS_TEMPORARY_SYSTEM_NODE_POOL_NAME}" | tee >(clip)

# Evict Pods from Default System Node Pool
kubectl drain \
  "aks-systempool-00000000-vmss000000" \
  --ignore-daemonsets true \
  --delete-local-data \
  --force

# Remove Extra System Node Pool
az aks nodepool delete \
  --cluster-name "${AKS_CLUSTER_NAME}" \
  --resource-group "${AKS_CLUSTER_RESOURCE_GROUP_NAME}" \
  --name "${AKS_TEMPORARY_SYSTEM_NODE_POOL_NAME}"

# Retrieve Node Pool List
az aks nodepool list \
  --cluster-name "${AKS_CLUSTER_NAME}" \
  --resource-group "${AKS_CLUSTER_RESOURCE_GROUP_NAME}" \
  --output table

Name       OsType    KubernetesVersion    VmSize            Count    MaxPods    ProvisioningState    Mode
---------  --------  -------------------  ----------------  -------  ---------  -------------------  ------
agentpool  Linux     1.17.7               Standard_D16s_v3  1        100        Succeeded            System
