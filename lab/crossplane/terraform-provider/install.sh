#!/bin/bash
# provider-terraform-examples
# https://github.com/negz/provider-terraform-examples.git

# 1. Create a GCP Service Account
# 1.1. Set Permissions to a Bucket to Store Terraform State there
# 1.2. Get Service Account Key
# 1.3. Set Environment Variables like:

# GOOGLE_CREDENTIALS_FILE.........: /home/silvios/trash/credentials.json
# GOOGLE_CREDENTIALS..............: 2319
# GOOGLE_PROJECT..................: sandbox-328317
# GOOGLE_REGION...................: us-central1
# GOOGLE_ZONE.....................: us-central1-a
# GOOGLE_TERRAFORM_BACKEND_BUCKET.: silvios
# GOOGLE_TERRAFORM_BACKEND_PREFIX.: terraform

# 2. Create a Kind Cluster and Install Crossplane (see ../install.sh file)

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
export CONTAINER_REGISTRY="docker.io/silviosilva"
export CROSSPLANE_CONFIGURATION_PACKAGE_VERSION="0.1.12"
export CROSSPLANE_CONFIGURATION_PACKAGE="${CONTAINER_REGISTRY}/migrating-from-terraform-example:${CROSSPLANE_CONFIGURATION_PACKAGE_VERSION}"
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
kubectl crossplane install configuration ${CROSSPLANE_CONFIGURATION_PACKAGE?}

# 7. Create a ProviderConfig to use GCP Credentials Secret
kubectl apply -f providerconfig/providerconfig-terraform.yaml

# 8. Request a Bucket Instance Creation
kubectl apply -f bucket.yaml

# 9. Check Cloud Storage List
gcloud alpha storage ls --project "${GOOGLE_PROJECT?}"
