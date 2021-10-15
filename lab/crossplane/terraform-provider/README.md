# Crossplane Terraform Example

This repo is based on Nic Cope's [example](https://github.com/negz/provider-terraform-examples.git).

There's a Youtube [video](https://www.youtube.com/watch?v=e3vkZtdwZJk&t=5s) where he shows an example using **Crossplane Terraform Experimental Provider**.

## 1. Setup GCP

You will need a Google Cloud Account and you can create one [here](https://cloud.google.com/getting-started).

### 1.2. Create a GCP Bucket to Store Terraform State there

### 1.3. Create a new GCP Project

### 1.4. Create a GCP Service Account

### 1.5. Set Bucket Permissions to the New GCP Service Account

### 1.6. Get Service Account Key

### 1.7. Set Environment Variables like:

```bash
GOOGLE_CREDENTIALS_FILE.........: /home/silvios/trash/credentials.json
GOOGLE_CREDENTIALS..............: 2319
GOOGLE_PROJECT..................: sandbox-328317
GOOGLE_REGION...................: us-central1
GOOGLE_ZONE.....................: us-central1-a
GOOGLE_TERRAFORM_BACKEND_BUCKET.: silvios
GOOGLE_TERRAFORM_BACKEND_PREFIX.: terraform
```

## 2. Crossplane Install

Feel free to follow official Crossplane Documentation Install of follow the next steps to accomplish that.

# 2.1. Create a Kind Cluster and Install Crossplane

```bash
../install/run.sh
```

# 3. Create a Secret

Create a Secret `gcp-credentials` into `crossplane-system` Namespace.

```bash
BASE64ENCODED_GCP_PROVIDER_CREDS=$(base64 "${GOOGLE_CREDENTIALS_FILE?}" | tr -d "\n")
```

```yaml
kubectl apply -f - <<EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: gcp-credentials
  namespace: crossplane-system
type: Opaque
data:
  credentials: ${BASE64ENCODED_GCP_PROVIDER_CREDS?}
EOF
```

# 4. Create a Crossplane Definition Package (OCI Image)

## 4.1. Build

```bash
`scripts/set-path.sh`
```

```bash
export DOCKER_HUB_USER="silviosilva"
export CONTAINER_REGISTRY="docker.io/${DOCKER_HUB_USER?}"
export CROSSPLANE_CONFIGURATION_PACKAGE_VERSION="0.1.24"
export CROSSPLANE_CONFIGURATION_PACKAGE_NAME="terraform-example"
export CROSSPLANE_CONFIGURATION_PACKAGE_FULL_NAME="${DOCKER_HUB_USER}-${CROSSPLANE_CONFIGURATION_PACKAGE_NAME?}"
export CROSSPLANE_CONFIGURATION_PACKAGE="${CONTAINER_REGISTRY}/${CROSSPLANE_CONFIGURATION_PACKAGE_NAME?}:${CROSSPLANE_CONFIGURATION_PACKAGE_VERSION}"
export CROSSPLANE_PACKAGE_DIRECTORY="package"
clear && show-crossplane-build-environment-variables.sh
```

```bash
cd "${CROSSPLANE_PACKAGE_DIRECTORY}" || exit 1
```

```bash
kubectl crossplane build configuration && ls ./*.xpkg
```

### 4.2. Push the OCI Image to a Container Registry

```bash
kubectl crossplane push configuration ${CROSSPLANE_CONFIGURATION_PACKAGE?} --verbose && rm ./*.xpkg && cd ..
```

## 5. Install Crossplane Configuration into the Kind Cluster

### 5.1. Let a watch executing on another Terminal

```bash
`scripts/set-path.sh`
watch -n 3 show-configuration-progress.sh
```

## 5.2. Install Crossplane Configuration

```bash
kubectl crossplane install configuration ${CROSSPLANE_CONFIGURATION_PACKAGE?} && \
kubectl wait configuration.pkg ${CROSSPLANE_CONFIGURATION_PACKAGE_FULL_NAME?} \
  --for condition=Healthy \
  --timeout=320s
```

## 6. Create a ProviderConfig to use GCP Credentials Secret

### 6.1. Create a `ControllerConfig` for Debug

```bash
kubectl apply -f provider/controller-config-debug.yaml
```

### 6.2. Update Terraform `Provider` to enable `DEBUG` MODE

```bash
kubectl apply -f provider/terraform/provider.yaml
```

### 6.3. Create Terraform `ProviderConfig`

```bash
kubectl apply -f provider/terraform/config/
```

### 6.4. Follow Crossplane Terraform Provider Logs

```bash
CROSSPLANE_TERRAFORM_PRODIVER_POD_NAME="$(kubectl get pods -n crossplane-system -o jsonpath="{range .items[*]}{.metadata.name}{'\n'}{end}" | grep crossplane-provider-terraform)" && \
kubectl -n crossplane-system logs -f "${CROSSPLANE_TERRAFORM_PRODIVER_POD_NAME?}"
```

### 6.5. Follow Provisioning Progress
```bash
watch -n 3 show-provision-progress.sh
```

## 7. Request a Bucket Instance Creation

### 7.1. Create a Claim for a Bucket

```bash
kubectl apply -f bucket.yaml
```

## 8. Check Cloud Storage List

```bash
gcloud alpha storage ls --project "${GOOGLE_PROJECT?}"
```

## 9. Delete Resources and Configuration

```bash
kubectl delete Bucket --all
kubectl delete ProviderConfig default
kubectl delete Configuration.pkg --all
kubectl delete Provider.pkg --all
```

## Crossplane Composition Example using ArgoCD

https://github.com/crossplane-contrib/provider-kubernetes/blob/main/examples/in-composition/composition.yaml
