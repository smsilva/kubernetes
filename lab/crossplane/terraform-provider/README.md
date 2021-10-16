# Crossplane Terraform Example

This repo is based on Nic Cope's [example](https://github.com/negz/provider-terraform-examples.git).

There's a Youtube [video](https://www.youtube.com/watch?v=e3vkZtdwZJk&t=5s) where he and Victor Facic shows an example using **Crossplane Terraform Experimental Provider**.

## TLDR

```bash
# New Terminal [1]: Following Configuration Progress

watch -n 3 scripts/show-configuration-progress.sh

# New Terminal [2]: Main Steps - Bootstrap

../install/create-kind-cluster.sh && \

../install/install-crossplane-helm-chart.sh

# Terminal [2]: Create Secret with GCP Credentials
BASE64ENCODED_GCP_PROVIDER_CREDS=$(base64 "${GOOGLE_CREDENTIALS_FILE?}" | tr -d "\n") && \
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

kubectl -n crossplane-system get secret gcp-credentials -o jsonpath='{.data}' | jq .

# Terminal [2]: Create Configurations

kubectl apply -f package/bucket/composite-resource-definition.yaml

kubectl apply -f package/bucket/composition.yaml

kubectl apply -f provider/controller-config-debug.yaml

kubectl apply -f provider/terraform/provider.yaml && \
kubectl wait Provider crossplane-provider-terraform \
  --for=condition=Healthy \
  --timeout=120s

kubectl apply -f provider/terraform/config/providerconfig.yaml

# New Terminal [2]: Following Crossplane Provider Terraform Logs 

CROSSPLANE_TERRAFORM_PRODIVER_POD_NAME="$(kubectl get pods -n crossplane-system -o jsonpath="{range .items[*]}{.metadata.name}{'\n'}{end}" | grep crossplane-provider-terraform)" && \
kubectl -n crossplane-system wait pod "${CROSSPLANE_TERRAFORM_PRODIVER_POD_NAME?}" \
  --for=condition=Ready \
  --timeout=120s && \
kubectl -n crossplane-system logs -f "${CROSSPLANE_TERRAFORM_PRODIVER_POD_NAME?}"

# Back to Terminal [1]: CTRL + C / Following Bucket Provision Progress

watch -n 3 scripts/show-provision-progress.sh

# New Terminal [3]: Create Buckets

helm template helm/buckets | kubectl apply --dry-run=server -f - && \

echo "OK" && \

helm template helm/buckets | kubectl apply -f - && \

for BUCKET_NAME in $(kubectl get buckets -o jsonpath='{.items[*].metadata.name}' | xargs -n 1); do
  kubectl wait bucket ${BUCKET_NAME} \
    --for=condition=Ready \
    --timeout=120s && \
  echo "${BUCKET_NAME}: Ready"
done

gcloud alpha storage ls --project "${GOOGLE_PROJECT?}"

```

## Objective

The objective here is to be able to create a Kubernetes Resource as decribed below and it reflects on a GCP Account creating a Bucket for Storage.

```yaml
apiVersion: silvios.me/v1alpha1
kind: Bucket
metadata:
  name: bucket-1
  annotations:
    crossplane.io/external-name: bucket-1
spec:
  parameters:
    location: USA
  compositionSelector:
    matchLabels:
      provider: terraform
  writeConnectionSecretToRef:
    name: bucket-1
```

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

Feel free to follow official Crossplane Documentation Install or follow the next steps to accomplish that.

### 2.1. Create a Kind Cluster and Install Crossplane

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

```bash
kubectl -n crossplane-system get secret gcp-credentials
```

Expected output:

```bash
NAME              TYPE     DATA   AGE
gcp-credentials   Opaque   1      6s
```

# 4. Create a Crossplane Definition Package - Optional

Crossplane allow us to use an OCI Image as an artifact for install Crossplane Configurations on different Clusters.

Although, if you already using GitOps approach, you should only apply  `package/bucket/` directory contents into the target cluster.

```bash
kubectl apply -f package/bucket/composite-resource-definition.yaml

kubectl apply -f package/bucket/composition.yaml
```

If you ran the commands above, please jump to step **6. Create Configurations**.

## 4.1. Build

```bash
source env.conf

show-crossplane-build-environment-variables.sh
```

```bash
cd "${CROSSPLANE_PACKAGE_DIRECTORY?}" || exit 1

kubectl crossplane build configuration && ls ./*.xpkg
```

### 4.2. Push the OCI Image to a Container Registry

```bash
kubectl crossplane push configuration ${CROSSPLANE_CONFIGURATION_PACKAGE?} --verbose && \

rm ./*.xpkg && cd ..
```

## 5. Install Crossplane Configuration into the Kind Cluster

### 5.1. Let a watch executing on another Terminal

```bash
source env.conf

watch -n 3 show-configuration-progress.sh
```

## 5.2. Install Crossplane Configuration

```bash
kubectl crossplane install configuration ${CROSSPLANE_CONFIGURATION_PACKAGE?} && \
kubectl wait configuration.pkg ${CROSSPLANE_CONFIGURATION_PACKAGE_FULL_NAME?} \
  --for condition=Healthy \
  --timeout=320s
```

## 6. Create Configurations

### 6.1. Create a `ControllerConfig` for Debug

```bash
kubectl apply -f provider/controller-config-debug.yaml
```

### 6.2. Update Terraform `Provider` to enable `DEBUG` MODE

```bash
kubectl apply -f provider/terraform/provider.yaml && \

kubectl wait Provider crossplane-provider-terraform --for=condition=Healthy
```

### 6.3. Create Terraform `ProviderConfig`

```bash
kubectl apply -f provider/terraform/config/
```

At this point we should see an output like this:

```bash
Crossplane PODs:

  NAME                                                         READY   STATUS    RESTARTS   AGE
  crossplane-6f974db97-9vlsj                                   1/1     Running   0          4m48s
  crossplane-provider-terraform-6ab31c3adccc-ff7dbd8df-w7txv   1/1     Running   0          16s
  crossplane-rbac-manager-dd8d65f77-6dqzt                      1/1     Running   0          4m48s

Configuration Package:

  NAME                            INSTALLED   HEALTHY   PACKAGE                                          AGE
  silviosilva-terraform-example   True        True      docker.io/silviosilva/terraform-example:0.1.24   63s

Provider:

  NAME                            INSTALLED   HEALTHY   PACKAGE                                AGE
  crossplane-provider-terraform   True        True      crossplane/provider-terraform:v0.1.2   59s

Custom Resources:

  NAME                              SHORTNAMES   APIVERSION                             NAMESPACED   KIND
  buckets                                        silvios.me/v1alpha1                    true         Bucket
  compositebuckets                               silvios.me/v1alpha1                    false        CompositeBucket

CompositeResourceDefinition:

  NAME                          ESTABLISHED   OFFERED   AGE
  compositebuckets.silvios.me   True          True      30s

Compositions:

  NAME                             AGE
  tf.compositebuckets.silvios.me   30s

ProviderConfig:

  NAME      AGE
  default   12s
```

### 6.4. Follow Crossplane Terraform Provider Logs

```bash
CROSSPLANE_TERRAFORM_PRODIVER_POD_NAME="$(kubectl get pods -n crossplane-system -o jsonpath="{range .items[*]}{.metadata.name}{'\n'}{end}" | grep crossplane-provider-terraform)" && \
kubectl -n crossplane-system logs -f "${CROSSPLANE_TERRAFORM_PRODIVER_POD_NAME?}"
```

### 6.5. Follow Provisioning Progress

Stop the first watch that is following Configuration Progress (show-configuration-progress.sh).

```bash
watch -n 3 scripts/show-provision-progress.sh
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

## 9. Cleanup

### 9.1 Delete GCP Buckets Created by Crossplane

Remember to remove Buckets created by Crossplane.

It shoud take some seconds until Crossplane execute the delete request.

```bash
kubectl delete Bucket --all
```

### 9.2 Delete Resources and Configuration

If you want to restart without destroy the Kind Cluster, make sure to destroy all the custom objects created.

```bash
delete-all-crossplane-objects.sh
```

### 9.3 Kind Cluster Delete

```bash
kind delete cluster --name crossplane
```

## Crossplane Composition Example using ArgoCD

https://github.com/crossplane-contrib/provider-kubernetes/blob/main/examples/in-composition/composition.yaml
