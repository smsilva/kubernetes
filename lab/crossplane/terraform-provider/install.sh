#!/bin/bash
# provider-terraform-examples
# https://github.com/negz/provider-terraform-examples.git

# 1. Create a GCP Service Account
# 1.1. Create a new Project
# 1.2. Create a Bucket to Store Terraform State there
# 1.3. Set Bucket Permissions to the New GCP Service Account
# 1.4. Get Service Account Key
# 1.5 Set Environment Variables like:

# GOOGLE_CREDENTIALS_FILE.........: /home/silvios/trash/credentials.json
# GOOGLE_CREDENTIALS..............: 2319
# GOOGLE_PROJECT..................: sandbox-328317
# GOOGLE_REGION...................: us-central1
# GOOGLE_ZONE.....................: us-central1-a
# GOOGLE_TERRAFORM_BACKEND_BUCKET.: silvios
# GOOGLE_TERRAFORM_BACKEND_PREFIX.: terraform

# 2. Create a Kind Cluster and Install Crossplane on it (see ../install-crossplane-on-kind.sh file)

# 3. Create a Secret into "crossplane-system" Namespace
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

# 4. Create a Crossplane Definition Package (OCI Image)

# 4.1. Make sure you are on "terraform-provider" directory

# 4.2. Build Crossplane Configuration
export DOCKER_HUB_USER="silviosilva"
export CONTAINER_REGISTRY="docker.io/${DOCKER_HUB_USER?}"
export CROSSPLANE_CONFIGURATION_PACKAGE_VERSION="0.1.15"
export CROSSPLANE_CONFIGURATION_PACKAGE_NAME="migrating-from-terraform-example"
export CROSSPLANE_CONFIGURATION_PACKAGE_FULL_NAME="${DOCKER_HUB_USER}-${CROSSPLANE_CONFIGURATION_PACKAGE_NAME?}"
export CROSSPLANE_CONFIGURATION_PACKAGE="${CONTAINER_REGISTRY}/${CROSSPLANE_CONFIGURATION_PACKAGE_NAME?}:${CROSSPLANE_CONFIGURATION_PACKAGE_VERSION}"
export CROSSPLANE_PACKAGE_DIRECTORY="package"

./show-environment-variables.sh

cd "${CROSSPLANE_PACKAGE_DIRECTORY}" || exit 1

kubectl crossplane build configuration && ls ./*.xpkg

# 5. Push the OCI Image to a Container Registry
kubectl crossplane push configuration ${CROSSPLANE_CONFIGURATION_PACKAGE?} --verbose && rm ./*.xpkg && cd ..

# 6. Install Crossplane Configuration into the Kind Cluster

# 6.1. Let a watch executing on another Terminal
watch -n 3 ./show-objects.sh

# 6.2. Install Crossplane Configuration
kubectl crossplane install configuration ${CROSSPLANE_CONFIGURATION_PACKAGE?} && \
kubectl wait configuration.pkg ${CROSSPLANE_CONFIGURATION_PACKAGE_FULL_NAME?} \
  --for condition=Healthy \
  --timeout=320s

# 7. Create a ProviderConfig to use GCP Credentials Secret

# 7.1. Enable Terraform Provider Debug Mode
kubectl apply -f providerconfig/provider-terraform-debug.yaml

# 7.2. Create Provider Config
kubectl apply -f providerconfig/providerconfig-terraform.yaml

# 8. Request a Bucket Instance Creation
kubectl apply -f bucket.yaml

# 9. Check Cloud Storage List
gcloud alpha storage ls --project "${GOOGLE_PROJECT?}"

# 10. Delete Resources and Configuration
kubectl delete Bucket --all
kubectl delete ProviderConfig default
kubectl delete Configuration.pkg --all
kubectl delete Provider.pkg --all
