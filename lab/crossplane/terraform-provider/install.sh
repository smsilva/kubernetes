#!/bin/bash
# provider-terraform-examples
# https://github.com/negz/provider-terraform-examples.git

# 1. Create GCP Service Account
# 1.1. Set Permissions to a Bucket to Store Terraform State there
# 1.2. Get Service Account Key
# 1.3. Set Environment Variables:

# GOOGLE_CREDENTIALS_FILE.........: /home/silvios/trash/credentials.json
# GOOGLE_CREDENTIALS..............: 2319
# GOOGLE_PROJECT..................: sandbox-328317
# GOOGLE_REGION...................: us-central1
# GOOGLE_ZONE.....................: us-central1-a
# GOOGLE_TERRAFORM_BACKEND_BUCKET.: silvios
# GOOGLE_TERRAFORM_BACKEND_PREFIX.: terraform

# 2. Create a Kind Cluster and Install Crossplane (see ../install.sh file)

# 3. Create a Secret into crossplane-system Namespace
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
CONTAINER_REGISTRY="docker.io/silviosilva"
CROSSPLANE_PACKAGE_DIRECTORY="package"
CROSSPLANE_CONFIGURATION_PACKAGE="${CONTAINER_REGISTRY}/migrating-from-terraform-example:0.1.3"

cd $(find . -name terraform-provider)/${CROSSPLANE_PACKAGE_DIRECTORY?} || $(echo "Directory \"${CROSSPLANE_PACKAGE_DIRECTORY?}\" not found."; echo "exit 1")

kubectl crossplane build configuration

# 5. Push the OCI Image to a Container Registry
kubectl crossplane push configuration ${CROSSPLANE_CONFIGURATION_PACKAGE?}

# 6. Install Crossplane Configuration into the Kind Cluster
kubectl crossplane install configuration ${CROSSPLANE_CONFIGURATION_PACKAGE?} && \
cd .. && \
watch -n 3 'kubectl get configuration && echo "" && \
kubectl get provider.pkg && echo "" && \
kubectl get xrd && echo "" && \
kubectl get composition'

# 8. Create a ProviderConfig to use GCP Credentials Secret
kubectl apply -f providerconfig/providerconfig-terraform.yaml

# 9. Request a Bucket Instance Creation
kubectl apply -f bucket.yaml && \
watch -n 3 'kubectl get bucket && echo "" && \
kubectl describe workspace | tail -20'

# 10. Clear Config
kubectl delete -f providerconfig-terraform.yaml
kubectl delete configuration.pkg --all
kubectl delete providers.pkg --all
